import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

import 'app_database.dart';

// Magic sentinel at the start of every backup file.
// 4 ASCII bytes 'KBAK' + 4-byte little-endian version = 1.
final _kMagic = Uint8List.fromList([
  0x4B,
  0x42,
  0x41,
  0x4B,
  0x01,
  0x00,
  0x00,
  0x00,
]);

/// Provides encrypted export and import of the local Drift database.
///
/// Backup format:
///   [8 magic bytes][encrypted JSON payload]
///
/// The JSON payload is encrypted with the user's 32-byte personal key using
/// AES-256-GCM (same algorithm as [KineticEncryption]).  Attempting to
/// decrypt with a wrong key causes a [SecretBoxAuthenticationError] which is
/// surfaced to the user as a key-mismatch error.
class DatabaseBackupService {
  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Serialises [db] to an encrypted backup blob.
  ///
  /// The blob starts with an 8-byte magic header so consumers can detect the
  /// format early, followed by the AES-256-GCM ciphertext.
  static Future<Uint8List> exportToBytes(
    AppDatabase db,
    Uint8List personalKey,
  ) async {
    final payload = await _buildPayload(db);
    final plaintext = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
    final ciphertext = await KineticEncryption.encrypt(plaintext, personalKey);

    final result = Uint8List(_kMagic.length + ciphertext.length);
    result.setAll(0, _kMagic);
    result.setAll(_kMagic.length, ciphertext);
    return result;
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  /// Decrypts and restores a backup produced by [exportToBytes].
  ///
  /// Throws [BackupKeyMismatchException] when [personalKey] does not match
  /// the key used during export.
  ///
  /// Throws [FormatException] if the file is not a valid Kinetic backup.
  static Future<void> importFromBytes(
    AppDatabase db,
    Uint8List personalKey,
    Uint8List data,
  ) async {
    _validateMagic(data);

    final ciphertext = data.sublist(_kMagic.length);
    final Uint8List plaintext;
    try {
      plaintext = await KineticEncryption.decrypt(ciphertext, personalKey);
    } on SecretBoxAuthenticationError {
      throw BackupKeyMismatchException();
    }

    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
    } catch (e) {
      throw const FormatException('Backup contents are corrupt or unreadable.');
    }

    await _restorePayload(db, payload);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static void _validateMagic(Uint8List data) {
    if (data.length < _kMagic.length) {
      throw const FormatException('File is too short to be a Kinetic backup.');
    }
    for (var i = 0; i < _kMagic.length; i++) {
      if (data[i] != _kMagic[i]) {
        throw const FormatException(
          'This file is not a valid Kinetic backup file.',
        );
      }
    }
  }

  /// Reads all tables and returns a serialisable map.
  static Future<Map<String, dynamic>> _buildPayload(AppDatabase db) async {
    final lists = await db.select(db.personalLists).get();
    final tasks = await db.select(db.personalTasks).get();
    final notes = await db.select(db.personalNotes).get();
    final subtasks = await db.select(db.personalSubtasks).get();
    final settings = await db.select(db.appSettings).get();

    return {
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'lists': lists.map(_listToJson).toList(),
      'tasks': tasks.map(_taskToJson).toList(),
      'notes': notes.map(_noteToJson).toList(),
      'subtasks': subtasks.map(_subtaskToJson).toList(),
      'settings': settings.map(_settingToJson).toList(),
    };
  }

  /// Clears existing user data and restores from payload inside a transaction.
  /// AppSettings are merged (not wiped) to avoid overwriting theme etc.
  static Future<void> _restorePayload(
    AppDatabase db,
    Map<String, dynamic> payload,
  ) async {
    await db.transaction(() async {
      // Wipe user data tables in dependency order.
      await db.delete(db.personalSubtasks).go();
      await db.delete(db.personalTasks).go();
      await db.delete(db.personalNotes).go();
      await db.delete(db.personalLists).go();

      // Restore lists
      for (final raw in (payload['lists'] as List<dynamic>? ?? [])) {
        final m = raw as Map<String, dynamic>;
        await db
            .into(db.personalLists)
            .insertOnConflictUpdate(
              PersonalListsCompanion.insert(
                id: m['id'] as String,
                name: m['name'] as String,
                colorValue: Value(m['colorValue'] as int),
                iconCodePoint: Value(m['iconCodePoint'] as int),
                isPrivateDefault: Value(m['isPrivateDefault'] as bool),
                position: Value(m['position'] as int),
                createdAt: DateTime.parse(m['createdAt'] as String),
                updatedAt: DateTime.parse(m['updatedAt'] as String),
              ),
            );
      }

      // Restore tasks
      for (final raw in (payload['tasks'] as List<dynamic>? ?? [])) {
        final m = raw as Map<String, dynamic>;
        await db
            .into(db.personalTasks)
            .insertOnConflictUpdate(
              PersonalTasksCompanion.insert(
                id: m['id'] as String,
                title: m['title'] as String,
                listId: Value(m['listId'] as String?),
                notes: Value(m['notes'] as String?),
                priority: Value(m['priority'] as int),
                dueDate: Value(_parseDateTime(m['dueDate'])),
                isAllDay: Value(m['isAllDay'] as bool),
                recurrenceRule: Value(m['recurrenceRule'] as String?),
                isCompleted: Value(m['isCompleted'] as bool),
                completedAt: Value(_parseDateTime(m['completedAt'])),
                isFlagged: Value(m['isFlagged'] as bool),
                isPrivate: Value(m['isPrivate'] as bool),
                kidsTaskId: Value(m['kidsTaskId'] as String?),
                category: Value(m['category'] as String),
                customCategory: Value(m['customCategory'] as String?),
                remindAt: Value(_parseDateTime(m['remindAt'])),
                sortOrder: Value(m['sortOrder'] as int),
                webdavEtag: Value(m['webdavEtag'] as String?),
                syncState: Value(m['syncState'] as String? ?? 'dirty'),
                createdAt: DateTime.parse(m['createdAt'] as String),
                updatedAt: DateTime.parse(m['updatedAt'] as String),
              ),
            );
      }

      // Restore notes
      for (final raw in (payload['notes'] as List<dynamic>? ?? [])) {
        final m = raw as Map<String, dynamic>;
        await db
            .into(db.personalNotes)
            .insertOnConflictUpdate(
              PersonalNotesCompanion.insert(
                id: m['id'] as String,
                title: m['title'] as String,
                body: Value(m['body'] as String),
                isShared: Value(m['isShared'] as bool),
                remindAt: Value(_parseDateTime(m['remindAt'])),
                category: Value(m['category'] as String?),
                sortOrder: Value(m['sortOrder'] as int),
                webdavEtag: Value(m['webdavEtag'] as String?),
                syncState: Value(m['syncState'] as String? ?? 'dirty'),
                createdAt: DateTime.parse(m['createdAt'] as String),
                updatedAt: DateTime.parse(m['updatedAt'] as String),
              ),
            );
      }

      // Restore subtasks
      for (final raw in (payload['subtasks'] as List<dynamic>? ?? [])) {
        final m = raw as Map<String, dynamic>;
        await db
            .into(db.personalSubtasks)
            .insertOnConflictUpdate(
              PersonalSubtasksCompanion.insert(
                id: m['id'] as String,
                taskId: m['taskId'] as String,
                title: m['title'] as String,
                isCompleted: Value(m['isCompleted'] as bool),
                sortOrder: Value(m['sortOrder'] as int),
              ),
            );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Row → JSON converters
  // ---------------------------------------------------------------------------

  static Map<String, dynamic> _listToJson(PersonalListRow r) => {
    'id': r.id,
    'name': r.name,
    'colorValue': r.colorValue,
    'iconCodePoint': r.iconCodePoint,
    'isPrivateDefault': r.isPrivateDefault,
    'position': r.position,
    'createdAt': r.createdAt.toUtc().toIso8601String(),
    'updatedAt': r.updatedAt.toUtc().toIso8601String(),
  };

  static Map<String, dynamic> _taskToJson(PersonalTaskRow r) => {
    'id': r.id,
    'listId': r.listId,
    'title': r.title,
    'notes': r.notes,
    'priority': r.priority,
    'dueDate': r.dueDate?.toUtc().toIso8601String(),
    'isAllDay': r.isAllDay,
    'recurrenceRule': r.recurrenceRule,
    'isCompleted': r.isCompleted,
    'completedAt': r.completedAt?.toUtc().toIso8601String(),
    'isFlagged': r.isFlagged,
    'isPrivate': r.isPrivate,
    'kidsTaskId': r.kidsTaskId,
    'category': r.category,
    'customCategory': r.customCategory,
    'remindAt': r.remindAt?.toUtc().toIso8601String(),
    'sortOrder': r.sortOrder,
    'webdavEtag': r.webdavEtag,
    'syncState': r.syncState,
    'createdAt': r.createdAt.toUtc().toIso8601String(),
    'updatedAt': r.updatedAt.toUtc().toIso8601String(),
  };

  static Map<String, dynamic> _noteToJson(PersonalNoteRow r) => {
    'id': r.id,
    'title': r.title,
    'body': r.body,
    'isShared': r.isShared,
    'remindAt': r.remindAt?.toUtc().toIso8601String(),
    'category': r.category,
    'sortOrder': r.sortOrder,
    'webdavEtag': r.webdavEtag,
    'syncState': r.syncState,
    'createdAt': r.createdAt.toUtc().toIso8601String(),
    'updatedAt': r.updatedAt.toUtc().toIso8601String(),
  };

  static Map<String, dynamic> _subtaskToJson(PersonalSubtaskRow r) => {
    'id': r.id,
    'taskId': r.taskId,
    'title': r.title,
    'isCompleted': r.isCompleted,
    'sortOrder': r.sortOrder,
  };

  static Map<String, dynamic> _settingToJson(AppSettingsRow r) => {
    'key': r.key,
    'theme': r.theme,
    'updatedAt': r.updatedAt.toUtc().toIso8601String(),
  };

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.parse(value as String);
  }
}

// ---------------------------------------------------------------------------
// Exception
// ---------------------------------------------------------------------------

/// Thrown when the personal key does not match the one used to encrypt the backup.
class BackupKeyMismatchException implements Exception {
  const BackupKeyMismatchException();

  @override
  String toString() =>
      'BackupKeyMismatchException: The recovery key does not match this backup file.';
}
