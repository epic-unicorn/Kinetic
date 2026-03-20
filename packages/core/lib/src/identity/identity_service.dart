import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import '../models/device_identity.dart';
import 'secure_key_value_store.dart';

/// Manages the cryptographic identity for this device.
///
/// On first use it generates an Ed25519 key pair, persists the 32-byte seed
/// in [SecureKeyValueStore] (backed by Android Keystore / iOS Keychain in
/// production), and returns the identity.  Subsequent calls reload from storage.
///
/// Inject a different [SecureKeyValueStore] for testing — see [InMemoryKeyStore].
class IdentityService {
  static const _deviceIdKey = 'kinetic_device_id';
  static const _privateKeySeedKey = 'kinetic_ed25519_seed';

  final SecureKeyValueStore _store;
  final Ed25519 _ed25519;

  IdentityService({required SecureKeyValueStore store})
      : _store = store,
        _ed25519 = Ed25519();

  /// Returns the persisted [DeviceIdentity], generating one on first call.
  Future<DeviceIdentity> getOrCreateIdentity() async {
    final storedSeed = await _store.read(key: _privateKeySeedKey);
    final storedDeviceId = await _store.read(key: _deviceIdKey);

    if (storedSeed != null && storedDeviceId != null) {
      final keyPair =
          await _ed25519.newKeyPairFromSeed(base64Decode(storedSeed));
      final publicKey = await keyPair.extractPublicKey();
      return DeviceIdentity(
        deviceId: storedDeviceId,
        publicKeyBytes: publicKey.bytes,
        keyPair: keyPair,
      );
    }

    return _generateAndPersist();
  }

  /// Signs [data] with this device's private key.
  /// Returns the 64-byte raw signature bytes.
  Future<List<int>> sign(List<int> data) async {
    final identity = await getOrCreateIdentity();
    final sig = await _ed25519.sign(data, keyPair: identity.keyPair);
    return sig.bytes;
  }

  /// Verifies [signatureBytes] over [data] against [publicKeyBytes].
  Future<bool> verify({
    required List<int> data,
    required List<int> signatureBytes,
    required List<int> publicKeyBytes,
  }) async {
    final publicKey =
        SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519);
    final signature = Signature(signatureBytes, publicKey: publicKey);
    return _ed25519.verify(data, signature: signature);
  }

  /// Wipes stored identity. Use only for factory reset or testing.
  Future<void> clearIdentity() async {
    await _store.delete(key: _deviceIdKey);
    await _store.delete(key: _privateKeySeedKey);
  }

  Future<DeviceIdentity> _generateAndPersist() async {
    final keyPair = await _ed25519.newKeyPair();
    final seed = await keyPair.extractPrivateKeyBytes();
    final publicKey = await keyPair.extractPublicKey();
    final deviceId = const Uuid().v4();

    await _store.write(key: _deviceIdKey, value: deviceId);
    await _store.write(key: _privateKeySeedKey, value: base64Encode(seed));

    return DeviceIdentity(
      deviceId: deviceId,
      publicKeyBytes: publicKey.bytes,
      keyPair: keyPair,
    );
  }
}
