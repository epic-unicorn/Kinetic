import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../webdav_client.dart';
import 'bip39_english.dart';
import 'kinetic_encryption.dart';

/// 12-word BIP-39 English mnemonic → 32-byte AES-256-GCM personal key.
///
/// After unlock the derived key is stored in secure storage. The 16-byte
/// entropy may also be stored on-device so the words can be shown again
/// behind the device lock. Paper is still the only off-device backup.
/// The same phrase decrypts a `.kvault` file and `/kinetic/{user}/vault.meta`.
class KineticVault {
  static const wordCount = 12;
  static const entropyByteCount = 16;
  static const aesKeyByteCount = 32;
  static const quizSize = 3;
  static const canaryKind = 'kinetic-vault';
  static const fileFormat = 'kvault';
  static const fileVersion = 1;

  static const _pbkdf2Iterations = 2048;

  KineticVault._();

  /// WebDAV path of the encrypted canary for [username].
  static String metaPath(String username) =>
      '/kinetic/${username.trim()}/vault.meta';

  /// Generates a new 12-word English mnemonic (128 bits of entropy).
  static Future<List<String>> generateMnemonic({Random? random}) async {
    final created = await createMnemonic(random: random);
    return created.words;
  }

  /// Entropy + mnemonic together so the 16-byte seed can go in a family QR.
  static Future<({Uint8List entropy, List<String> words})> createMnemonic({
    Random? random,
  }) async {
    final rng = random ?? Random.secure();
    final entropy = Uint8List.fromList(
      List<int>.generate(entropyByteCount, (_) => rng.nextInt(256)),
    );
    final words = await mnemonicFromEntropy(entropy);
    return (entropy: entropy, words: words);
  }

  /// Encodes 16 bytes of [entropy] as a BIP-39 mnemonic (checksum included).
  static Future<List<String>> mnemonicFromEntropy(Uint8List entropy) async {
    if (entropy.length != entropyByteCount) {
      throw ArgumentError.value(
        entropy.length,
        'entropy.length',
        'Expected $entropyByteCount bytes (128-bit BIP-39)',
      );
    }
    final hash = await Sha256().hash(entropy);
    final checksumNibble = hash.bytes[0] >> 4;

    final bits = <int>[];
    for (final byte in entropy) {
      for (var i = 7; i >= 0; i--) {
        bits.add((byte >> i) & 1);
      }
    }
    for (var i = 3; i >= 0; i--) {
      bits.add((checksumNibble >> i) & 1);
    }

    final words = <String>[];
    for (var i = 0; i < wordCount; i++) {
      var index = 0;
      for (var j = 0; j < 11; j++) {
        index = (index << 1) | bits[i * 11 + j];
      }
      words.add(kBip39English[index]);
    }
    return words;
  }

  /// Splits and normalises a pasted/typed phrase.
  ///
  /// Throws [FormatException] if the word count is wrong or a word is unknown.
  static List<String> parseMnemonic(String phrase) {
    final words = phrase
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length != wordCount) {
      throw FormatException(
        'Herstelzin moet $wordCount woorden zijn, kreeg ${words.length}.',
      );
    }
    for (final word in words) {
      if (!kBip39English.contains(word)) {
        throw FormatException('Onbekend woord in herstelzin: $word');
      }
    }
    return words;
  }

  /// True when [phrase] is 12 valid English BIP-39 words with a good checksum.
  static Future<bool> isValidMnemonic(String phrase) async {
    try {
      await deriveAesKey(phrase);
      return true;
    } on FormatException {
      return false;
    }
  }

  /// BIP-39 seed (first 32 bytes) used as the AES-256-GCM personal key.
  ///
  /// Throws [FormatException] on unknown words or a bad checksum.
  static Future<Uint8List> deriveAesKey(String phrase) async {
    final words = parseMnemonic(phrase);
    if (!await _checksumValid(words)) {
      throw const FormatException(
        'Ongeldige herstelzin (checksum). Controleer de woorden.',
      );
    }
    final normalised = words.join(' ');
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha512(),
      iterations: _pbkdf2Iterations,
      bits: 512,
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(normalised)),
      nonce: utf8.encode('mnemonic'),
    );
    final seed = await secretKey.extractBytes();
    return Uint8List.fromList(seed.sublist(0, aesKeyByteCount));
  }

  /// Constant-time equality for 32-byte keys.
  static bool equalKeys(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  /// Three distinct 0-based word indices, sorted, for the confirmation quiz.
  static List<int> pickQuizIndices({Random? random, int count = quizSize}) {
    if (count < 1 || count > wordCount) {
      throw ArgumentError.value(count, 'count');
    }
    final rng = random ?? Random.secure();
    final indices = List<int>.generate(wordCount, (i) => i)..shuffle(rng);
    final picked = indices.take(count).toList()..sort();
    return picked;
  }

  static bool quizMatches({
    required List<String> mnemonic,
    required List<int> indices,
    required List<String> answers,
  }) {
    if (mnemonic.length != wordCount ||
        indices.length != answers.length ||
        indices.isEmpty) {
      return false;
    }
    for (var i = 0; i < indices.length; i++) {
      final expected = mnemonic[indices[i]].toLowerCase().trim();
      final given = answers[i].toLowerCase().trim();
      if (expected != given) return false;
    }
    return true;
  }

  /// Small encrypted blob proving [key] can open this vault.
  static Future<Uint8List> sealCanary(Uint8List key) async {
    final payload = utf8.encode(
      jsonEncode({
        'v': 1,
        'kind': canaryKind,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    return KineticEncryption.encrypt(Uint8List.fromList(payload), key);
  }

  /// True when [blob] decrypts with [key] and looks like a Kinetic canary.
  static Future<bool> openCanary(Uint8List blob, Uint8List key) async {
    try {
      final plain = await KineticEncryption.decrypt(blob, key);
      final map = jsonDecode(utf8.decode(plain));
      return map is Map && map['kind'] == canaryKind;
    } catch (_) {
      return false;
    }
  }

  /// Encrypts backup [plaintext] (JSON bytes) into a `.kvault` UTF-8 file.
  ///
  /// The file never contains the mnemonic or the raw key.
  static Future<Uint8List> wrapBackup({
    required Uint8List plaintext,
    required Uint8List key,
    String usernameHint = '',
  }) async {
    final ciphertext = await KineticEncryption.encrypt(plaintext, key);
    final payload = <String, dynamic>{
      'version': fileVersion,
      'format': fileFormat,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'usernameHint': usernameHint,
      'ciphertext': base64.encode(ciphertext),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(payload)));
  }

  /// Decrypts a `.kvault` file produced by [wrapBackup].
  ///
  /// Throws [FormatException] when the wrapper is not a kvault file.
  /// Throws [SecretBoxAuthenticationError] when [key] is wrong.
  static Future<Uint8List> unwrapBackup(
    Uint8List fileBytes,
    Uint8List key,
  ) async {
    final Map<String, dynamic> map;
    try {
      map = jsonDecode(utf8.decode(fileBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('Ongeldig kluisbestand: geen JSON.');
    }
    if (map['format'] != fileFormat) {
      throw const FormatException(
        'Dit is geen Kinetic-kluisbestand (.kvault).',
      );
    }
    if (map['version'] != fileVersion) {
      throw FormatException(
        'Onbekende kluisversie: ${map['version']}.',
      );
    }
    final cipherB64 = map['ciphertext'] as String?;
    if (cipherB64 == null || cipherB64.isEmpty) {
      throw const FormatException('Kluisbestand bevat geen gegevens.');
    }
    final ciphertext = Uint8List.fromList(base64.decode(cipherB64));
    try {
      return await KineticEncryption.decrypt(ciphertext, key);
    } on SecretBoxAuthenticationError {
      throw const FormatException(
        'Verkeerde herstelzin voor dit kluisbestand.',
      );
    }
  }

  static Future<bool> _checksumValid(List<String> words) async {
    final bits = <int>[];
    for (final word in words) {
      final index = kBip39English.indexOf(word);
      if (index < 0) return false;
      for (var i = 10; i >= 0; i--) {
        bits.add((index >> i) & 1);
      }
    }
    final entropy = Uint8List(entropyByteCount);
    for (var i = 0; i < 128; i++) {
      if (bits[i] == 1) {
        entropy[i >> 3] |= 1 << (7 - (i & 7));
      }
    }
    final hash = await Sha256().hash(entropy);
    final expected = hash.bytes[0] >> 4;
    var actual = 0;
    for (var i = 0; i < 4; i++) {
      actual = (actual << 1) | bits[128 + i];
    }
    return actual == expected;
  }

  /// First 128 bits of a valid mnemonic (checksum already verified).
  static Future<Uint8List> entropyFromMnemonic(List<String> words) async {
    if (words.length != wordCount) {
      throw FormatException(
        'Herstelzin moet $wordCount woorden zijn, kreeg ${words.length}.',
      );
    }
    if (!await _checksumValid(words)) {
      throw const FormatException(
        'Ongeldige herstelzin (checksum). Controleer de woorden.',
      );
    }
    final bits = <int>[];
    for (final word in words) {
      final index = kBip39English.indexOf(word);
      for (var i = 10; i >= 0; i--) {
        bits.add((index >> i) & 1);
      }
    }
    final entropy = Uint8List(entropyByteCount);
    for (var i = 0; i < 128; i++) {
      if (bits[i] == 1) {
        entropy[i >> 3] |= 1 << (7 - (i & 7));
      }
    }
    return entropy;
  }

  /// First 4 hex chars of SHA-256([key]) for visual pairing confirmation.
  static Future<String> fingerprint(Uint8List key) async {
    final hash = await Sha256().hash(key);
    return hash.bytes
        .take(2)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  static String familyKeyEncPath(String username) =>
      '/kinetic/${username.trim()}/family.key.enc';

  /// Encrypts family key + entropy with the personal vault key.
  static Future<Uint8List> wrapFamilyRecovery({
    required Uint8List familyKey,
    required Uint8List entropy,
    required Uint8List personalKey,
  }) async {
    if (familyKey.length != aesKeyByteCount) {
      throw ArgumentError.value(familyKey.length, 'familyKey.length');
    }
    if (entropy.length != entropyByteCount) {
      throw ArgumentError.value(entropy.length, 'entropy.length');
    }
    final plain = utf8.encode(
      jsonEncode({
        'v': 1,
        'key': base64.encode(familyKey),
        'ent': base64.encode(entropy),
      }),
    );
    return KineticEncryption.encrypt(Uint8List.fromList(plain), personalKey);
  }

  /// Decrypts a blob from [wrapFamilyRecovery].
  static Future<({Uint8List familyKey, Uint8List entropy})> unwrapFamilyRecovery(
    Uint8List blob,
    Uint8List personalKey,
  ) async {
    try {
      final plain = await KineticEncryption.decrypt(blob, personalKey);
      final map = jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
      final key = Uint8List.fromList(base64.decode(map['key'] as String));
      final ent = Uint8List.fromList(base64.decode(map['ent'] as String));
      if (key.length != aesKeyByteCount || ent.length != entropyByteCount) {
        throw const FormatException('Beschadigde familiesleutel op de server.');
      }
      return (familyKey: key, entropy: ent);
    } on SecretBoxAuthenticationError {
      throw const FormatException(
        'Persoonlijke kluis past niet bij de familiesleutel op de server.',
      );
    }
  }

  /// Compact family-pairing QR: 16-byte entropy, never the WebDAV password.
  static String exportFamilyEntropyQrPayload({
    required Uint8List entropy,
    required String serverUrl,
    required String username,
  }) {
    if (entropy.length != entropyByteCount) {
      throw ArgumentError.value(entropy.length, 'entropy.length');
    }
    return jsonEncode({
      'v': 2,
      'type': 'family',
      'url': serverUrl,
      'user': username,
      'ent': base64.encode(entropy),
    });
  }

  /// Parses a family QR. v2 carries entropy; v1 (legacy) carries the raw key.
  static Future<
      ({
        Uint8List familyKey,
        Uint8List? entropy,
        String serverUrl,
        String username,
      })> importFamilyQrPayload(String payload) async {
    final Map<String, dynamic> map;
    try {
      map = jsonDecode(payload) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Ongeldige QR-code: $e');
    }
    final version = map['v'] as int? ?? 0;
    final serverUrl = (map['url'] as String?) ?? '';
    final username = (map['user'] as String?) ?? '';
    if (version == 2 || map['ent'] != null) {
      final entB64 = map['ent'] as String?;
      if (entB64 == null || entB64.isEmpty) {
        throw const FormatException('QR-code bevat geen familiesleutel.');
      }
      final entropy = Uint8List.fromList(base64.decode(entB64));
      if (entropy.length != entropyByteCount) {
        throw FormatException(
          'Ongeldige entropy-lengte: ${entropy.length}.',
        );
      }
      final words = await mnemonicFromEntropy(entropy);
      final key = await deriveAesKey(words.join(' '));
      return (
        familyKey: key,
        entropy: entropy,
        serverUrl: serverUrl,
        username: username,
      );
    }
    if (version == 1) {
      final imported = KineticEncryption.importFamilyKeyQrPayload(payload);
      return (
        familyKey: imported.familyKey,
        entropy: null,
        serverUrl: imported.serverUrl,
        username: imported.username,
      );
    }
    throw FormatException('Onbekende QR-versie: $version');
  }
}

/// Outcome of reading `/kinetic/{user}/vault.meta`.
enum VaultMetaStatus { unlocked, missing, wrongPhrase }

/// WebDAV canary for the personal vault.
class KineticVaultRemote {
  KineticVaultRemote._();

  /// GET + decrypt [KineticVault.metaPath].
  static Future<VaultMetaStatus> probe({
    required WebDavClient client,
    required String username,
    required Uint8List key,
  }) async {
    final Uint8List blob;
    try {
      blob = await client.get(KineticVault.metaPath(username));
    } on WebDavException catch (e) {
      if (e.isNotFound) return VaultMetaStatus.missing;
      rethrow;
    }
    final ok = await KineticVault.openCanary(blob, key);
    return ok ? VaultMetaStatus.unlocked : VaultMetaStatus.wrongPhrase;
  }

  /// Writes a new canary. Overwrites an existing file.
  static Future<void> writeMeta({
    required WebDavClient client,
    required String username,
    required Uint8List key,
  }) async {
    final blob = await KineticVault.sealCanary(key);
    await client.put(KineticVault.metaPath(username), blob);
  }

  /// Ensures a canary exists and matches [key].
  ///
  /// * Missing → write a new canary.
  /// * Unlocked → no-op.
  /// * Wrong phrase → returns [VaultMetaStatus.wrongPhrase] without writing.
  static Future<VaultMetaStatus> ensureMeta({
    required WebDavClient client,
    required String username,
    required Uint8List key,
  }) async {
    final status = await probe(
      client: client,
      username: username,
      key: key,
    );
    if (status == VaultMetaStatus.missing) {
      await writeMeta(client: client, username: username, key: key);
      return VaultMetaStatus.unlocked;
    }
    return status;
  }

  /// Writes `/kinetic/{user}/family.key.enc` (personal-key encrypted).
  static Future<void> pushFamilyRecovery({
    required WebDavClient client,
    required String username,
    required Uint8List personalKey,
    required Uint8List familyKey,
    required Uint8List entropy,
  }) async {
    final blob = await KineticVault.wrapFamilyRecovery(
      familyKey: familyKey,
      entropy: entropy,
      personalKey: personalKey,
    );
    await client.put(KineticVault.familyKeyEncPath(username), blob);
  }

  /// Reads family.key.enc. Null when the file is missing.
  static Future<({Uint8List familyKey, Uint8List entropy})?> pullFamilyRecovery({
    required WebDavClient client,
    required String username,
    required Uint8List personalKey,
  }) async {
    final Uint8List blob;
    try {
      blob = await client.get(KineticVault.familyKeyEncPath(username));
    } on WebDavException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
    return KineticVault.unwrapFamilyRecovery(blob, personalKey);
  }
}
