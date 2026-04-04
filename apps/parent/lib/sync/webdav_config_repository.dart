import 'dart:convert';
import 'dart:typed_data';

import 'package:kinetic_webdav/kinetic_webdav.dart';

/// Secure-storage keys for WebDAV configuration.
const _kServerUrl = 'kinetic_webdav_server_url';
const _kUsername = 'kinetic_webdav_username';
const _kPassword = 'kinetic_webdav_password';
const _kPersonalKey = 'kinetic_webdav_personal_key';
const _kFamilyKey = 'kinetic_webdav_family_key';
const _kParentId = 'kinetic_webdav_parent_id';

/// Persists and loads [SyncConfig] from [SecureKeyValueStore].
///
/// Keys are stored individually so the password can be updated independently
/// of the encryption keys (e.g. after a WebDAV password change + re-derive).
class WebDavConfigRepository {
  final SecureKeyValueStore _store;

  WebDavConfigRepository(this._store);

  // ---------------------------------------------------------------------------
  // Read
  // ---------------------------------------------------------------------------

  /// Returns the stored [SyncConfig], or null if the user has not yet
  /// configured WebDAV.
  Future<SyncConfig?> load() async {
    final serverUrl = await _store.read(key: _kServerUrl);
    final username = await _store.read(key: _kUsername);
    final password = await _store.read(key: _kPassword);
    final personalKeyBase64 = await _store.read(key: _kPersonalKey);

    if (serverUrl == null ||
        username == null ||
        password == null ||
        personalKeyBase64 == null) {
      return null;
    }

    final personalKeyBytes = Uint8List.fromList(
      base64.decode(personalKeyBase64),
    );

    final familyKeyBase64 = await _store.read(key: _kFamilyKey);
    final familyKeyBytes = familyKeyBase64 != null
        ? Uint8List.fromList(base64.decode(familyKeyBase64))
        : null;

    // parentId may be absent for existing installs — treated as null here;
    // the setup screen generates and persists one on the next save.
    final parentId = await _store.read(key: _kParentId) ?? '';

    return SyncConfig(
      serverUrl: serverUrl,
      username: username,
      password: password,
      parentId: parentId,
      personalKeyBytes: personalKeyBytes,
      familyKeyBytes: familyKeyBytes,
    );
  }

  // ---------------------------------------------------------------------------
  // Write
  // ---------------------------------------------------------------------------

  /// Persists a full [SyncConfig] to secure storage.
  Future<void> save(SyncConfig config) async {
    await _store.write(key: _kServerUrl, value: config.serverUrl);
    await _store.write(key: _kUsername, value: config.username);
    await _store.write(key: _kPassword, value: config.password);
    await _store.write(key: _kParentId, value: config.parentId);
    await _store.write(
      key: _kPersonalKey,
      value: base64.encode(config.personalKeyBytes),
    );
    if (config.familyKeyBytes != null) {
      await _store.write(
        key: _kFamilyKey,
        value: base64.encode(config.familyKeyBytes!),
      );
    }
  }

  /// Updates only the password in secure storage.
  ///
  /// The family key is intentionally left unchanged — it is independent of
  /// the WebDAV password and is shared explicitly between parents.
  Future<void> updatePassword(String newPassword) async {
    await _store.write(key: _kPassword, value: newPassword);
  }

  /// Stores a new family key without touching any other config fields.
  ///
  /// Use this after importing a family key from a partner parent.
  Future<void> saveFamilyKey(Uint8List familyKey) async {
    await _store.write(key: _kFamilyKey, value: base64.encode(familyKey));
  }

  /// Stores a new personal key without touching any other config fields.
  ///
  /// Use this when importing a personal key backup, independent of WebDAV.
  Future<void> savePersonalKey(Uint8List personalKey) async {
    await _store.write(key: _kPersonalKey, value: base64.encode(personalKey));
  }

  /// Removes the family key without touching any other config fields.
  ///
  /// Call this when leaving the family pairing.
  Future<void> clearFamilyKey() async {
    await _store.delete(key: _kFamilyKey);
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  /// Clears all WebDAV configuration from secure storage.
  Future<void> clear() async {
    await _store.delete(key: _kServerUrl);
    await _store.delete(key: _kUsername);
    await _store.delete(key: _kPassword);
    await _store.delete(key: _kParentId);
    await _store.delete(key: _kPersonalKey);
    await _store.delete(key: _kFamilyKey);
  }
}
