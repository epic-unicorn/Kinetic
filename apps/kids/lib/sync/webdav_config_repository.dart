import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:kinetic_webdav/kinetic_webdav.dart';

// Secure storage keys — shared with parent app so kids device can use the
// same credentials written by the parent enrollment flow.
const _kServerUrl = 'kinetic_webdav_server_url';
const _kUsername = 'kinetic_webdav_username';
const _kPassword = 'kinetic_webdav_password';
const _kPersonalKey = 'kinetic_webdav_personal_key';
const _kFamilyKey = 'kinetic_webdav_family_key';
const _kKidId = 'kinetic_kid_id';

/// Loads [SyncConfig] from [SecureKeyValueStore].
///
/// Kids app reads credentials written by the kids enrollment QR flow.
/// The personal key is not used by kids (only shared tasks via family key),
/// so a dummy key is generated and stored once if absent.
class WebDavConfigRepository {
  final SecureKeyValueStore _store;

  WebDavConfigRepository(this._store);

  /// Returns the stored [SyncConfig], or null if not yet enrolled.
  Future<SyncConfig?> load() async {
    final serverUrl = await _store.read(key: _kServerUrl);
    final username = await _store.read(key: _kUsername);
    final password = await _store.read(key: _kPassword);
    final familyKeyBase64 = await _store.read(key: _kFamilyKey);

    if (serverUrl == null ||
        username == null ||
        password == null ||
        familyKeyBase64 == null) {
      return null;
    }

    // Personal key is unused by kids but required by SyncConfig. Generate a
    // random one-time dummy and persist it so subsequent loads are stable.
    final personalKeyBase64 =
        await _store.read(key: _kPersonalKey) ??
        await _generateAndStorePersonalKey();

    final personalKeyBytes = Uint8List.fromList(
      base64.decode(personalKeyBase64),
    );
    final familyKeyBytes = Uint8List.fromList(base64.decode(familyKeyBase64));

    return SyncConfig(
      serverUrl: serverUrl,
      username: username,
      password: password,
      parentId: '',
      personalKeyBytes: personalKeyBytes,
      familyKeyBytes: familyKeyBytes,
    );
  }

  /// Persists the kids enrollment credentials from a scanned QR payload.
  Future<void> saveEnrollment({
    required String serverUrl,
    required String username,
    required String password,
    required Uint8List familyKey,
    required String kidId,
  }) async {
    await _store.write(key: _kServerUrl, value: serverUrl);
    await _store.write(key: _kUsername, value: username);
    await _store.write(key: _kPassword, value: password);
    await _store.write(key: _kFamilyKey, value: base64.encode(familyKey));
    if (kidId.isNotEmpty) {
      await _store.write(key: _kKidId, value: kidId);
    }
  }

  /// Returns the kid's own ID as assigned by the parent during enrollment.
  Future<String?> loadKidId() => _store.read(key: _kKidId);

  /// Removes all enrollment credentials, returning the app to unenrolled state.
  Future<void> clearEnrollment() async {
    await _store.delete(key: _kServerUrl);
    await _store.delete(key: _kUsername);
    await _store.delete(key: _kPassword);
    await _store.delete(key: _kPersonalKey);
    await _store.delete(key: _kFamilyKey);
    await _store.delete(key: _kKidId);
  }

  Future<String> _generateAndStorePersonalKey() async {
    final rng = Random.secure();
    final bytes = Uint8List.fromList(
      List.generate(32, (_) => rng.nextInt(256)),
    );
    final encoded = base64.encode(bytes);
    await _store.write(key: _kPersonalKey, value: encoded);
    return encoded;
  }
}
