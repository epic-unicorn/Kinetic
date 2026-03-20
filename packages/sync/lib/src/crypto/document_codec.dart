import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// AES-256-GCM codec for CouchDB documents.
///
/// **What gets encrypted:** Everything except `_id`, `_rev`, and `_deleted`
/// (CouchDB metadata that must remain plaintext for replication to work).
///
/// **Wire format** (stored in CouchDB):
/// ```json
/// {
///   "_id": "<unchanged>",
///   "_rev": "<unchanged>",
///   "enc": 1,
///   "iv":  "<12-byte nonce, base64>",
///   "ct":  "<ciphertext || 16-byte GCM tag, base64>"
/// }
/// ```
///
/// The 16-byte GCM authentication tag is **appended to** the ciphertext so
/// the stored format is a single base64 blob. Decryption splits it off before
/// creating the [SecretBox].
class DocumentCodec {
  static final _aesGcm = AesGcm.with256bits();
  static const _macLength = 16; // GCM tag is always 128 bits

  /// Encrypts [plainDoc] using [meshKey] (must be exactly 32 bytes).
  ///
  /// Returns a new map with the plaintext payload replaced by encrypted blobs.
  /// Passes [_id], [_rev], and [_deleted] through unmodified.
  Future<Map<String, dynamic>> encrypt(
    Map<String, dynamic> plainDoc,
    List<int> meshKey,
  ) async {
    assert(meshKey.length == 32, 'meshKey must be 32 bytes (AES-256)');

    final id = plainDoc['_id'];
    final rev = plainDoc['_rev'];
    final deleted = plainDoc['_deleted'];

    // Extract only the user payload — CouchDB metadata stays plaintext.
    final payload = Map<String, dynamic>.from(plainDoc)
      ..remove('_id')
      ..remove('_rev')
      ..remove('_deleted');

    final plaintext = utf8.encode(jsonEncode(payload));
    final nonce = _secureNonce();
    final secretKey = SecretKey(meshKey);

    final box = await _aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
      nonce: nonce,
    );

    // Append the 16-byte GCM tag to the cipher-text for a single base64 blob.
    final ctWithTag = [...box.cipherText, ...box.mac.bytes];

    return {
      if (id != null) '_id': id,
      if (rev != null) '_rev': rev,
      if (deleted != null) '_deleted': deleted,
      'enc': 1,
      'iv': base64Encode(nonce),
      'ct': base64Encode(ctWithTag),
    };
  }

  /// Decrypts a document previously produced by [encrypt].
  ///
  /// If the document does not carry `enc: 1` it is returned as-is —
  /// this handles plaintext sentinel/tombstone documents from the hub.
  ///
  /// Throws [SecretBoxAuthenticationError] if the GCM tag verification fails
  /// (tampered ciphertext or wrong mesh key).
  Future<Map<String, dynamic>> decrypt(
    Map<String, dynamic> encryptedDoc,
    List<int> meshKey,
  ) async {
    assert(meshKey.length == 32, 'meshKey must be 32 bytes (AES-256)');

    if (encryptedDoc['enc'] != 1) {
      // Not an encrypted document — pass through unchanged.
      return Map<String, dynamic>.from(encryptedDoc);
    }

    final nonce = base64Decode(encryptedDoc['iv'] as String);
    final ctWithTag = base64Decode(encryptedDoc['ct'] as String);

    if (ctWithTag.length < _macLength) {
      throw const FormatException('Encrypted document ct field is too short.');
    }

    final cipherText = ctWithTag.sublist(0, ctWithTag.length - _macLength);
    final mac = Mac(ctWithTag.sublist(ctWithTag.length - _macLength));

    final secretKey = SecretKey(meshKey);
    final box = SecretBox(cipherText, nonce: nonce, mac: mac);
    final plaintext = await _aesGcm.decrypt(box, secretKey: secretKey);

    final payload = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;

    return {
      if (encryptedDoc['_id'] != null) '_id': encryptedDoc['_id'],
      if (encryptedDoc['_rev'] != null) '_rev': encryptedDoc['_rev'],
      if (encryptedDoc['_deleted'] != null)
        '_deleted': encryptedDoc['_deleted'],
      ...payload,
    };
  }

  List<int> _secureNonce() {
    final rng = Random.secure();
    return List<int>.generate(12, (_) => rng.nextInt(256));
  }
}
