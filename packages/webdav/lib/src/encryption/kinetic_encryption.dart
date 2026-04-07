import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// AES-256-GCM encryption and PBKDF2 key derivation for Kinetic Link.
///
/// Layout of an encrypted blob (all lengths in bytes):
///   [12 nonce][N ciphertext+mac]
///
/// The AES-GCM mac (16 bytes) is appended to the ciphertext by the
/// cryptography package and is included transparently.
class KineticEncryption {
  static final _aesGcm = AesGcm.with256bits();
  static const _familySalt = 'kinetic-family-key';
  static const _pbkdf2Iterations = 100000;

  // ---------------------------------------------------------------------------
  // Key generation
  // ---------------------------------------------------------------------------

  /// Generates a cryptographically random 32-byte personal key.
  static Uint8List generatePersonalKey() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
  }

  /// Generates a cryptographically random 32-byte family key.
  ///
  /// The returned key must be explicitly shared with every family member
  /// (e.g. via [exportFamilyKeyJson] / [importFamilyKeyJson]).  Each parent
  /// has their own WebDAV credentials; the family key is the *only* thing
  /// they need to share.
  static Uint8List generateFamilyKey() {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => rng.nextInt(256)));
  }

  // ---------------------------------------------------------------------------
  // Family key derivation (legacy / migration only)
  // ---------------------------------------------------------------------------

  /// Derives a 32-byte family key from a WebDAV [password] via PBKDF2-HMAC-SHA-256.
  ///
  /// Kept for backward-compatibility and migration only.
  /// New code should use [generateFamilyKey] instead.
  ///
  /// The salt is the constant string `kinetic-family-key` encoded as UTF-8.
  /// Iterations: 100 000.
  static Future<Uint8List> deriveFamilyKey(String password) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: utf8.encode(_familySalt),
    );
    final bytes = await secretKey.extractBytes();
    return Uint8List.fromList(bytes);
  }

  // ---------------------------------------------------------------------------
  // Encrypt / decrypt
  // ---------------------------------------------------------------------------

  /// Encrypts [plaintext] with [keyBytes] (32 bytes) using AES-256-GCM.
  ///
  /// Returns `[12-byte nonce][ciphertext+16-byte MAC]`.
  static Future<Uint8List> encrypt(
    Uint8List plaintext,
    Uint8List keyBytes,
  ) async {
    assert(keyBytes.length == 32, 'Key must be 32 bytes');
    final secretKey = SecretKey(keyBytes);
    final nonce = _aesGcm.newNonce();
    final box = await _aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );
    // Concatenate nonce + ciphertext (mac is part of ciphertext in this lib).
    final result =
        Uint8List(nonce.length + box.cipherText.length + box.mac.bytes.length);
    result.setAll(0, nonce);
    result.setAll(nonce.length, box.cipherText);
    result.setAll(nonce.length + box.cipherText.length, box.mac.bytes);
    return result;
  }

  /// Decrypts a blob produced by [encrypt].
  ///
  /// Throws [SecretBoxAuthenticationError] if the MAC is invalid.
  static Future<Uint8List> decrypt(
    Uint8List blob,
    Uint8List keyBytes,
  ) async {
    assert(keyBytes.length == 32, 'Key must be 32 bytes');
    if (blob.length < 12 + 16) throw ArgumentError('Blob too short');
    const nonceLen = 12;
    const macLen = 16;
    final nonce = blob.sublist(0, nonceLen);
    final mac = Mac(blob.sublist(blob.length - macLen));
    final cipherText = blob.sublist(nonceLen, blob.length - macLen);

    final secretKey = SecretKey(keyBytes);
    final box = SecretBox(cipherText, nonce: nonce, mac: mac);
    final plaintext = await _aesGcm.decrypt(box, secretKey: secretKey);
    return Uint8List.fromList(plaintext);
  }

  // ---------------------------------------------------------------------------
  // Personal key recovery export / import
  // ---------------------------------------------------------------------------

  /// Serialises [personalKey] to a JSON recovery file string.
  ///
  /// Format:
  /// ```json
  /// {
  ///   "version": 1,
  ///   "usernameHint": "<username>",
  ///   "personalKey": "<base64-encoded 32 bytes>"
  /// }
  /// ```
  static String exportRecoveryJson(Uint8List personalKey, String usernameHint) {
    return const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'usernameHint': usernameHint,
      'personalKey': base64.encode(personalKey),
    });
  }

  /// Parses a recovery JSON string produced by [exportRecoveryJson] and
  /// returns the 32-byte personal key.
  ///
  /// Throws [FormatException] if the JSON is malformed or the version is
  /// unsupported.
  static Uint8List importRecoveryJson(String json) {
    final Map<String, dynamic> map;
    try {
      map = jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Invalid recovery JSON: $e');
    }
    if (map['version'] != 1) {
      throw FormatException(
          'Unsupported recovery JSON version: ${map["version"]}');
    }
    final keyBase64 = map['personalKey'] as String?;
    if (keyBase64 == null)
      throw const FormatException('Missing personalKey field');
    final bytes = base64.decode(keyBase64);
    if (bytes.length != 32) {
      throw FormatException(
          'personalKey must be 32 bytes, got ${bytes.length}');
    }
    return Uint8List.fromList(bytes);
  }

  // ---------------------------------------------------------------------------
  // Family key export / import
  // ---------------------------------------------------------------------------

  /// Serialises [familyKey] to a JSON string suitable for sharing with a
  /// partner parent.
  ///
  /// Format:
  /// ```json
  /// {
  ///   "version": 1,
  ///   "usernameHint": "<username of the exporting parent>",
  ///   "familyKey": "<base64-encoded 32 bytes>"
  /// }
  /// ```
  static String exportFamilyKeyJson(Uint8List familyKey, String usernameHint) {
    return const JsonEncoder.withIndent('  ').convert({
      'version': 1,
      'usernameHint': usernameHint,
      'familyKey': base64.encode(familyKey),
    });
  }

  /// Parses a family key JSON string produced by [exportFamilyKeyJson] and
  /// returns the 32-byte family key.
  ///
  /// Throws [FormatException] if the JSON is malformed or the version is
  /// unsupported.
  static Uint8List importFamilyKeyJson(String json) {
    final Map<String, dynamic> map;
    try {
      map = jsonDecode(json) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Invalid family key JSON: $e');
    }
    if (map['version'] != 1) {
      throw FormatException(
          'Unsupported family key JSON version: ${map["version"]}');
    }
    final keyBase64 = map['familyKey'] as String?;
    if (keyBase64 == null) {
      throw const FormatException('Missing familyKey field');
    }
    final bytes = base64.decode(keyBase64);
    if (bytes.length != 32) {
      throw FormatException('familyKey must be 32 bytes, got ${bytes.length}');
    }
    return Uint8List.fromList(bytes);
  }

  // ---------------------------------------------------------------------------
  // Family key QR payload (for partner sharing)
  // ---------------------------------------------------------------------------

  /// Serialises [familyKey] to a compact JSON string suitable for encoding
  /// in a QR code.
  ///
  /// The payload includes [serverUrl] so the scanning device can verify
  /// the key belongs to the same WebDAV server.
  ///
  /// Format:
  /// ```json
  /// {"v":1,"url":"https://...","user":"alice","key":"<base64 32 bytes>"}
  /// ```
  static String exportFamilyKeyQrPayload(
    Uint8List familyKey,
    String serverUrl,
    String username,
  ) {
    return jsonEncode({
      'v': 1,
      'url': serverUrl,
      'user': username,
      'key': base64.encode(familyKey),
    });
  }

  // ---------------------------------------------------------------------------
  // Kids enrollment QR payload
  // ---------------------------------------------------------------------------

  /// Serialises the credentials needed for the kids app to connect to the
  /// family WebDAV workspace into a compact JSON string for a QR code.
  ///
  /// Format:
  /// ```json
  /// {"v":1,"type":"kids","url":"https://...","user":"alice","pw":"secret","key":"<base64 32 bytes>"}
  /// ```
  static String exportKidsEnrollmentQrPayload(
    Uint8List familyKey,
    String serverUrl,
    String username,
    String password,
  ) {
    return jsonEncode({
      'v': 1,
      'type': 'kids',
      'url': serverUrl,
      'user': username,
      'pw': password,
      'key': base64.encode(familyKey),
    });
  }

  /// Parses a QR payload produced by [exportKidsEnrollmentQrPayload].
  ///
  /// Returns a record with the decoded fields.
  ///
  /// Throws [FormatException] if the payload is malformed.
  static ({
    Uint8List familyKey,
    String serverUrl,
    String username,
    String password,
  }) importKidsEnrollmentQrPayload(String payload) {
    final Map<String, dynamic> map;
    try {
      map = jsonDecode(payload) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Invalid QR payload: $e');
    }
    if (map['type'] != 'kids') {
      throw const FormatException('Not a kids enrollment QR code');
    }
    final keyBase64 = map['key'] as String?;
    if (keyBase64 == null) throw const FormatException('Missing key field');
    final bytes = base64.decode(keyBase64);
    if (bytes.length != 32) {
      throw FormatException('key must be 32 bytes, got ${bytes.length}');
    }
    return (
      familyKey: Uint8List.fromList(bytes),
      serverUrl: (map['url'] as String?) ?? '',
      username: (map['user'] as String?) ?? '',
      password: (map['pw'] as String?) ?? '',
    );
  }

  /// Parses a QR payload produced by [exportFamilyKeyQrPayload].
  ///
  /// Returns a record with the decoded [familyKey], the [serverUrl] embedded
  /// in the payload, and the [username] hint.
  ///
  /// Throws [FormatException] if the payload is malformed.
  static ({Uint8List familyKey, String serverUrl, String username})
      importFamilyKeyQrPayload(String payload) {
    final Map<String, dynamic> map;
    try {
      map = jsonDecode(payload) as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Invalid QR payload: $e');
    }
    if (map['v'] != 1) {
      throw FormatException('Unsupported QR version: ${map["v"]}');
    }
    final keyBase64 = map['key'] as String?;
    if (keyBase64 == null) throw const FormatException('Missing key field');
    final bytes = base64.decode(keyBase64);
    if (bytes.length != 32) {
      throw FormatException('key must be 32 bytes, got ${bytes.length}');
    }
    return (
      familyKey: Uint8List.fromList(bytes),
      serverUrl: (map['url'] as String?) ?? '',
      username: (map['user'] as String?) ?? '',
    );
  }
}
