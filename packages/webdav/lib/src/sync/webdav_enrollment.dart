import 'dart:typed_data';

import '../encryption/kinetic_encryption.dart';
import '../sync_config.dart';
import '../webdav_client.dart';

/// First-time setup helpers for a WebDAV-backed Kinetic Link account.
class WebDavEnrollment {
  // ---------------------------------------------------------------------------
  // Connection test
  // ---------------------------------------------------------------------------

  /// Tests whether [serverUrl] is reachable and supports WebDAV with the
  /// given credentials.
  ///
  /// Returns `null` on success, or a human-readable error message on failure.
  static Future<String?> testConnection(
    String serverUrl,
    String username,
    String password,
  ) async {
    final client = WebDavClient(
      baseUrl: serverUrl,
      username: username,
      password: password,
    );
    try {
      final supported = await client.supportsWebDav();
      if (!supported) return 'Server does not appear to support WebDAV.';
      return null;
    } on Exception catch (e) {
      return 'Could not connect: $e';
    } finally {
      client.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // Directory provisioning
  // ---------------------------------------------------------------------------

  /// Creates the required WebDAV directory tree for [username]:
  ///
  /// ```
  /// /kinetic/
  ///   {username}/
  ///     tasks/
  ///     notes/
  ///   shared/
  ///     notes/
  /// ```
  static Future<void> setupDirectories(
    WebDavClient client,
    String username,
  ) async {
    final dirs = [
      '/kinetic',
      '/kinetic/$username',
      '/kinetic/$username/tasks',
      '/kinetic/$username/notes',
      '/kinetic/shared',
      '/kinetic/shared/notes',
    ];
    for (final dir in dirs) {
      await client.mkcol(dir);
    }
  }

  // ---------------------------------------------------------------------------
  // Key generation
  // ---------------------------------------------------------------------------

  /// Generates a fresh personal key and derives the family key from [password].
  ///
  /// Both keys are returned as a named record so the caller can persist them
  /// to secure storage.
  static Future<({Uint8List personalKey, Uint8List familyKey})> generateKeys(
    String password,
  ) async {
    final personalKey = KineticEncryption.generatePersonalKey();
    final familyKey = await KineticEncryption.deriveFamilyKey(password);
    return (personalKey: personalKey, familyKey: familyKey);
  }

  // ---------------------------------------------------------------------------
  // Full first-run workflow
  // ---------------------------------------------------------------------------

  /// Convenience method that runs the full first-time enrollment:
  ///
  /// 1. Tests the connection.
  /// 2. Creates the directory tree.
  /// 3. Generates personal + family keys.
  ///
  /// Returns a ready-to-use [SyncConfig] with both keys populated, or throws
  /// [EnrollmentException] on failure.
  static Future<SyncConfig> enroll({
    required String serverUrl,
    required String username,
    required String password,
  }) async {
    final error = await testConnection(serverUrl, username, password);
    if (error != null) throw EnrollmentException(error);

    final client = WebDavClient(
      baseUrl: serverUrl,
      username: username,
      password: password,
    );
    try {
      await setupDirectories(client, username);
    } finally {
      client.dispose();
    }

    final keys = await generateKeys(password);
    return SyncConfig(
      serverUrl: serverUrl,
      username: username,
      password: password,
      personalKeyBytes: keys.personalKey,
      familyKeyBytes: keys.familyKey,
    );
  }
}

/// Thrown when [WebDavEnrollment.enroll] fails.
class EnrollmentException implements Exception {
  final String message;
  const EnrollmentException(this.message);

  @override
  String toString() => 'EnrollmentException: $message';
}
