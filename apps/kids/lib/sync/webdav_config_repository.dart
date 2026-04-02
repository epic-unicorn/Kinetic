import 'dart:convert';
import 'dart:typed_data';

import 'package:kinetic_webdav/kinetic_webdav.dart';

// Secure storage keys — shared with parent app so kids device can use the
// same credentials written by the parent enrollment flow.
const _kServerUrl = 'kinetic_webdav_server_url';
const _kUsername = 'kinetic_webdav_username';
const _kPassword = 'kinetic_webdav_password';
const _kPersonalKey = 'kinetic_webdav_personal_key';
const _kFamilyKey = 'kinetic_webdav_family_key';

/// Loads [SyncConfig] from [SecureKeyValueStore].
///
/// Kids app only reads — it never writes WebDAV credentials itself.
/// Credentials are written by the parent enrollment flow.
class WebDavConfigRepository {
  final SecureKeyValueStore _store;

  WebDavConfigRepository(this._store);

  /// Returns the stored [SyncConfig], or null if not yet configured.
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

    return SyncConfig(
      serverUrl: serverUrl,
      username: username,
      password: password,
      parentId: '',
      personalKeyBytes: personalKeyBytes,
      familyKeyBytes: familyKeyBytes,
    );
  }
}
