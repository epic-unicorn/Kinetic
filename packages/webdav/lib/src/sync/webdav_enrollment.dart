import 'dart:async';
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
  /// Times out after 10 seconds.
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
      final supported = await client.supportsWebDav().timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException(
              'WebDAV connection test timed out after 10 seconds',
            ),
          );
      if (!supported) return 'Server does not appear to support WebDAV.';
      return null;
    } on TimeoutException {
      return 'Connection timed out. Check your server URL and network connection.';
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
  ///     tasks/
  ///     proposals/
  ///     load/
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
      '/kinetic/shared/tasks',
      '/kinetic/shared/proposals',
      '/kinetic/shared/load',
      '/kinetic/shared/presence',
      '/kinetic/shared/disconnect',
    ];
    for (final dir in dirs) {
      await client.mkcol(dir);
    }
  }

  // ---------------------------------------------------------------------------
  // Key generation
  // ---------------------------------------------------------------------------

  /// Generates fresh personal and family keys for a new account.
  ///
  /// Both keys are randomly generated and independent of the WebDAV password.
  /// The family key must be explicitly shared with other parents via
  /// [KineticEncryption.exportFamilyKeyJson] / [KineticEncryption.importFamilyKeyJson].
  static ({Uint8List personalKey, Uint8List familyKey}) generateKeys() {
    final personalKey = KineticEncryption.generatePersonalKey();
    final familyKey = KineticEncryption.generateFamilyKey();
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

    final keys = generateKeys();
    return SyncConfig(
      serverUrl: serverUrl,
      username: username,
      password: password,
      parentId: '',
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
