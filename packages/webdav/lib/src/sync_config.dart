import 'dart:typed_data';

/// Immutable configuration for a WebDAV sync connection.
class SyncConfig {
  /// WebDAV server root, e.g. `https://nextcloud.example.com/remote.php/dav`.
  final String serverUrl;

  /// WebDAV username.
  final String username;

  /// WebDAV password for HTTP Basic auth.
  final String password;

  /// Stable UUID identifying this parent device/account.
  /// Generated once on first setup and stored in secure storage.
  /// Used as [PartnerProposal.fromParentId] when proposing tasks.
  final String parentId;

  /// 32-byte AES-256-GCM key for personal (private) data.
  final Uint8List personalKeyBytes;

  /// 32-byte AES-256-GCM key for shared family data.  Generated randomly on
  /// first enrollment and explicitly shared between parents.  Absent until
  /// the key has been set at least once.
  final Uint8List? familyKeyBytes;

  const SyncConfig({
    required this.serverUrl,
    required this.username,
    required this.password,
    required this.parentId,
    required this.personalKeyBytes,
    this.familyKeyBytes,
  });

  /// Normalised server URL — trailing slash stripped.
  String get baseUrl => serverUrl.endsWith('/')
      ? serverUrl.substring(0, serverUrl.length - 1)
      : serverUrl;

  /// Returns a copy with [familyKeyBytes] set.
  SyncConfig withFamilyKey(Uint8List familyKey) => SyncConfig(
        serverUrl: serverUrl,
        username: username,
        password: password,
        parentId: parentId,
        personalKeyBytes: personalKeyBytes,
        familyKeyBytes: familyKey,
      );
}
