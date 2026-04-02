import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../notifications/notification_service.dart';
import '../models/personal_note.dart';

/// NoteRepository — CRUD for personal notes with reminder scheduling.
class NoteRepository {
  final AppDatabase _db;
  final NotificationService? _notifications;
  final void Function()? onWrite;

  NoteRepository({
    required AppDatabase db,
    NotificationService? notifications,
    this.onWrite,
  }) : _db = db,
       _notifications = notifications;

  /// All notes, ordered by creation date (newest first).
  /// Excludes soft-deleted notes (syncState='deleted').
  Stream<List<PersonalNote>> watchAll() {
    return (_db.select(_db.personalNotes)
          ..where((t) => t.syncState.equals('deleted').not())
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(_noteFromRow).toList());
  }

  /// Stream a single note by id.
  Stream<PersonalNote?> watchOne(String id) {
    return (_db.select(_db.personalNotes)..where((t) => t.id.equals(id)))
        .watchSingleOrNull()
        .map((row) => row != null ? _noteFromRow(row) : null);
  }

  /// Create a new note.
  Future<PersonalNote> insert({
    required String title,
    String body = '',
    bool isShared = false,
    DateTime? remindAt,
  }) async {
    try {
      final note = PersonalNote.create(
        title: title,
        body: body,
        isShared: isShared,
        remindAt: remindAt,
      );
      await _db.into(_db.personalNotes).insert(_noteToCompanion(note));
      await _scheduleReminderFor(note);
      onWrite?.call();
      return note;
    } catch (e) {
      rethrow;
    }
  }

  /// Update an existing note.
  Future<void> update(PersonalNote note) async {
    try {
      await (_db.update(
        _db.personalNotes,
      )..where((t) => t.id.equals(note.id))).write(_noteToCompanion(note));
      // Cancel old reminder, schedule new one.
      await _notifications?.cancelReminder(_notifId(note.id));
      await _scheduleReminderFor(note);
      onWrite?.call();
    } catch (e) {
      rethrow;
    }
  }

  /// Soft-delete a note by marking syncState='deleted'.
  Future<void> delete(String id) async {
    try {
      await _notifications?.cancelReminder(_notifId(id));
      await (_db.update(
        _db.personalNotes,
      )..where((t) => t.id.equals(id))).write(
        PersonalNotesCompanion(
          syncState: const Value('deleted'),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
      onWrite?.call();
    } catch (e) {
      rethrow;
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  PersonalNote _noteFromRow(PersonalNoteRow row) {
    return PersonalNote.fromRow(row);
  }

  PersonalNotesCompanion _noteToCompanion(PersonalNote note) {
    return PersonalNotesCompanion(
      id: Value(note.id),
      title: Value(note.title),
      body: Value(note.body),
      isShared: Value(note.isShared),
      remindAt: Value(note.remindAt),
      createdAt: Value(note.createdAt),
      updatedAt: Value(note.updatedAt),
      syncState: const Value('dirty'),
      webdavEtag: const Value(null),
    );
  }

  Future<void> _scheduleReminderFor(PersonalNote note) async {
    if (note.remindAt == null) return;
    await _notifications?.scheduleReminder(
      id: _notifId(note.id),
      title: note.title,
      body: note.body,
      at: note.remindAt!,
    );
  }

  int _notifId(String noteId) => noteId.hashCode.abs();
}
