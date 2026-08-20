import 'dart:typed_data';

import 'package:kinetic_webdav/kinetic_webdav.dart';

import '../sync/webdav_config_repository.dart';

const kVaultReadyKey = 'kinetic_vault_ready';

/// Session for the personal vault: derived AES key in secure storage.
///
/// 16-byte BIP-39 entropy is stored so the words can be shown again on this
/// device. The phrase itself is never written as text.
class VaultRepository {
  VaultRepository(this._store, this._configRepo);

  final SecureKeyValueStore _store;
  final WebDavConfigRepository _configRepo;

  Future<bool> isReady() async {
    final flag = await _store.read(key: kVaultReadyKey);
    return flag == '1';
  }

  /// True when a 0.2.x (or `.kbak2`) personal key exists but no vault phrase.
  Future<bool> needsMigration() async {
    if (await isReady()) return false;
    return await loadKey() != null;
  }

  Future<void> markReady() async {
    await _store.write(key: kVaultReadyKey, value: '1');
  }

  Future<Uint8List> unlockWithKey(Uint8List key, {Uint8List? entropy}) async {
    await _configRepo.savePersonalKey(key);
    if (entropy != null) {
      await _configRepo.savePersonalEntropy(entropy);
    }
    await markReady();
    return key;
  }

  Future<Uint8List> unlockWithPhrase(String phrase) async {
    final words = KineticVault.parseMnemonic(phrase);
    final joined = words.join(' ');
    final key = await KineticVault.deriveAesKey(joined);
    final entropy = await KineticVault.entropyFromMnemonic(words);
    return unlockWithKey(key, entropy: entropy);
  }

  Future<Uint8List?> loadKey() => _configRepo.loadPersonalKeyBytes();

  Future<Uint8List> requireKey() async {
    final key = await loadKey();
    if (key == null) {
      throw StateError('Vault is not unlocked');
    }
    return key;
  }

  /// Reconstructs the 12 words from stored entropy, or null if this device
  /// only has a raw key (pre-0.3 or `.kbak2`).
  Future<List<String>?> loadPersonalMnemonic() async {
    final entropy = await _configRepo.loadPersonalEntropy();
    if (entropy == null) return null;
    return KineticVault.mnemonicFromEntropy(entropy);
  }

  /// Constant-time compare of [phrase] against the stored derived key.
  Future<bool> verifyPhrase(String phrase) async {
    final stored = await loadKey();
    if (stored == null) return false;
    try {
      final derived = await KineticVault.deriveAesKey(phrase);
      return KineticVault.equalKeys(stored, derived);
    } on FormatException {
      return false;
    }
  }
}
