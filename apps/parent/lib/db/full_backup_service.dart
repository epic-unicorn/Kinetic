import 'dart:convert';
import 'dart:typed_data';

import 'package:kinetic_webdav/kinetic_webdav.dart';

import 'app_database.dart';
import 'database_backup_service.dart';
import '../settings/models/enrolled_kid.dart';
import '../settings/settings_repository.dart';
import '../sync/webdav_config_repository.dart';
import '../theme/app_themes.dart';

/// A combined backup / restore service that bundles the personal key, the
/// encrypted database, and app settings into a single `.kbak2` file.
///
/// File format (UTF-8 JSON, unencrypted outer wrapper):
/// ```json
/// {
///   "version": 3,
///   "exportedAt": "<ISO-8601 UTC>",
///   "usernameHint": "<string>",
///   "personalKey": "<base64 of 32-byte personal key>",
///   "database": "<base64 of .kbak blob (encrypted by [DatabaseBackupService])>",
///   "settings": {
///     "theme": "<light|dark>",
///     "webdav": {
///       "serverUrl": "<string>",
///       "username": "<string>",
///       "password": "<string>",
///       "parentId": "<uuid>",
///       "familyKey": "<base64 | null>",
///       "partnerPaired": true,
///       "enrolledKids": [{"id": "<uuid>", "name": "<string>", "enrolledAt": "<ISO-8601>"}]
///     }
///   }
/// }
/// ```
///
/// The outer file is NOT encrypted — it contains the personal key and WebDAV
/// credentials in plaintext.  Users must store the file in a safe location.
/// Version 2 files (no settings section) are still accepted on import.
class FullBackupService {
  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Creates a combined backup blob that includes [personalKey], an
  /// encrypted snapshot of [db], and optional app settings.
  ///
  /// Pass [webDavConfig] and [settingsRepo] to include WebDAV credentials,
  /// theme, and enrolled-kids in the backup (version 3).
  static Future<Uint8List> exportToBytes(
    AppDatabase db,
    Uint8List personalKey, {
    String usernameHint = '',
    SyncConfig? webDavConfig,
    Uint8List? familyKey,
    List<EnrolledKid>? enrolledKids,
    bool partnerPaired = false,
    String? currentThemeName,
  }) async {
    final kbakBlob = await DatabaseBackupService.exportToBytes(db, personalKey);

    final hasSettings = webDavConfig != null || currentThemeName != null;
    final Map<String, dynamic>? settingsMap = hasSettings
        ? {
            if (currentThemeName != null) 'theme': currentThemeName,
            if (webDavConfig != null)
              'webdav': {
                'serverUrl': webDavConfig.serverUrl,
                'username': webDavConfig.username,
                'password': webDavConfig.password,
                'parentId': webDavConfig.parentId,
                'familyKey': familyKey != null
                    ? base64.encode(familyKey)
                    : webDavConfig.familyKeyBytes != null
                    ? base64.encode(webDavConfig.familyKeyBytes!)
                    : null,
                'partnerPaired': partnerPaired,
                'enrolledKids': enrolledKids?.map((k) => k.toJson()).toList(),
              },
          }
        : null;

    final payload = <String, dynamic>{
      'version': hasSettings ? 3 : 2,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'usernameHint': usernameHint,
      'personalKey': base64.encode(personalKey),
      'database': base64.encode(kbakBlob),
      if (settingsMap != null) 'settings': settingsMap,
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(payload)));
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  /// Restores the personal key, database, and (for v3) app settings from a
  /// blob previously produced by [exportToBytes].
  ///
  /// * The personal key is saved via [WebDavConfigRepository.savePersonalKey].
  /// * The database is restored via [DatabaseBackupService.importFromBytes].
  /// * For v3 files: WebDAV config, family key, enrolled kids, and theme are
  ///   restored when [settingsRepo] and/or [configRepo] are provided.
  ///   The [onThemeRestored] callback is invoked with the restored [AppTheme]
  ///   so the caller can update any in-memory theme notifiers.
  ///
  /// Accepts both version 2 (key + DB) and version 3 (key + DB + settings).
  /// Throws [FormatException] when [data] is not a valid `.kbak2` file.
  static Future<void> importFromBytes(
    AppDatabase db,
    WebDavConfigRepository configRepo,
    Uint8List data, {
    SettingsRepository? settingsRepo,
    void Function(AppTheme)? onThemeRestored,
  }) async {
    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(utf8.decode(data)) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('Ongeldig back-upbestand: geen geldig JSON.');
    }

    final version = payload['version'] as int?;
    if (version != 2 && version != 3) {
      throw FormatException(
        'Onbekende back-up versie: $version. '
        'Verwacht versie 2 of 3 (.kbak2).',
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

    // 3. Restore settings (v3 only).
    if (version == 3) {
      final settings = payload['settings'] as Map<String, dynamic>?;
      if (settings != null) {
        // 3a. Theme.
        final themeName = settings['theme'] as String?;
        if (themeName != null && settingsRepo != null) {
          final theme = AppTheme.values.firstWhere(
            (t) => t.name == themeName,
            orElse: () => AppTheme.light,
          );
          await settingsRepo.saveTheme(theme);
          onThemeRestored?.call(theme);
        }

        // 3b. WebDAV config + family key + enrolled kids.
        final webdav = settings['webdav'] as Map<String, dynamic>?;
        if (webdav != null) {
          final serverUrl = webdav['serverUrl'] as String?;
          final username = webdav['username'] as String?;
          final password = webdav['password'] as String?;
          final parentId = webdav['parentId'] as String? ?? '';
          final familyKeyStr = webdav['familyKey'] as String?;
          final partnerPaired = webdav['partnerPaired'] as bool? ?? false;
          final enrolledKidsJson = webdav['enrolledKids'] as List<dynamic>?;

          if (serverUrl != null && username != null && password != null) {
            final familyKeyBytes =
                familyKeyStr != null && familyKeyStr.isNotEmpty
                ? Uint8List.fromList(base64.decode(familyKeyStr))
                : null;
            await configRepo.save(
              SyncConfig(
                serverUrl: serverUrl,
                username: username,
                password: password,
                parentId: parentId,
                personalKeyBytes: personalKey,
                familyKeyBytes: familyKeyBytes,
              ),
            );
            await configRepo.setPartnerPaired(partnerPaired);
            if (enrolledKidsJson != null) {
              final kids = enrolledKidsJson
                  .map((e) => EnrolledKid.fromJson(e as Map<String, dynamic>))
                  .toList();
              await configRepo.restoreEnrolledKids(kids);
            }
          }
        }
      }
    }
  }
}
