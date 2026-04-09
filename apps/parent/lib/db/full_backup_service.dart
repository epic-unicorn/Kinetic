import 'dart:convert';
import 'dart:typed_data';

import 'app_database.dart';
import 'database_backup_service.dart';
import '../sync/webdav_config_repository.dart';

/// A combined backup / restore service that bundles the personal key and the
/// encrypted database into a single `.kbak2` file.
///
/// File format (UTF-8 JSON, unencrypted outer wrapper):
/// ```json
/// {
///   "version": 2,
///   "exportedAt": "<ISO-8601 UTC>",
///   "usernameHint": "<string>",
///   "personalKey": "<base64 of 32-byte personal key>",
///   "database": "<base64 of .kbak blob (encrypted by [DatabaseBackupService])>"
/// }
/// ```
///
/// The outer file is NOT encrypted — the personal key is in plaintext inside
/// it.  Users must store the file in a safe location.
class FullBackupService {
  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Creates a combined backup blob that includes [personalKey] and an
  /// encrypted snapshot of [db].
  static Future<Uint8List> exportToBytes(
    AppDatabase db,
    Uint8List personalKey, {
    String usernameHint = '',
  }) async {
    final kbakBlob = await DatabaseBackupService.exportToBytes(db, personalKey);
    final payload = {
      'version': 2,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'usernameHint': usernameHint,
      'personalKey': base64.encode(personalKey),
      'database': base64.encode(kbakBlob),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(payload)));
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  /// Restores both the personal key and the database from a blob previously
  /// produced by [exportToBytes].
  ///
  /// * The personal key is saved to [configRepo] via [WebDavConfigRepository.savePersonalKey].
  /// * The database is restored via [DatabaseBackupService.importFromBytes].
  ///
  /// Throws [FormatException] when [data] is not a valid `.kbak2` file.
  static Future<void> importFromBytes(
    AppDatabase db,
    WebDavConfigRepository configRepo,
    Uint8List data,
  ) async {
    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('Ongeldig back-upbestand: geen geldig JSON.');
    }

    final version = payload['version'] as int?;
    if (version != 2) {
      throw FormatException(
        'Onbekende back-up versie: $version. '
        'Verwacht versie 2 (.kbak2).',
      );
    }

    final keyStr = payload['personalKey'] as String?;
    if (keyStr == null || keyStr.isEmpty) {
      throw const FormatException(
        'Back-upbestand bevat geen persoonlijke sleutel.',
      );
    }

    final Uint8List personalKey;
    try {
      personalKey = Uint8List.fromList(base64.decode(keyStr));
    } catch (_) {
      throw const FormatException(
        'Persoonlijke sleutel in back-upbestand is beschadigd.',
      );
    }

    final dbStr = payload['database'] as String?;
    if (dbStr == null || dbStr.isEmpty) {
      throw const FormatException(
        'Back-upbestand bevat geen databasegegevens.',
      );
    }

    final Uint8List kbakBlob;
    try {
      kbakBlob = Uint8List.fromList(base64.decode(dbStr));
    } catch (_) {
      throw const FormatException(
        'Databasegegevens in back-upbestand zijn beschadigd.',
      );
    }

    // 1. Restore personal key in secure storage.
    await configRepo.savePersonalKey(personalKey);

    // 2. Restore the database.
    await DatabaseBackupService.importFromBytes(db, personalKey, kbakBlob);
  }
}
