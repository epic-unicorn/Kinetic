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

  /// All notes, grouped by category (nulls first) then creation date (newest first).
  /// Excludes soft-deleted notes (syncState='deleted').
  Stream<List<PersonalNote>> watchAll() {
    return (_db.select(_db.personalNotes)
          ..where((t) => t.syncState.equals('deleted').not())
          ..orderBy([
            (t) => OrderingTerm(
              expression: t.category.isNull(),
              mode: OrderingMode.desc,
            ),
            (t) => OrderingTerm.asc(t.category),
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
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
    String? category,
    int sortOrder = 0,
  }) async {
    try {
      final note = PersonalNote.create(
        title: title,
        body: body,
        isShared: isShared,
        remindAt: remindAt,
        category: category,
        sortOrder: sortOrder,
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
  Future<void> updateNoteCategory(String noteId, String? category) async {
    await (_db.update(
      _db.personalNotes,
    )..where((t) => t.id.equals(noteId))).write(
      PersonalNotesCompanion(
        category: Value(category),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    onWrite?.call();
  }

  /// Batch-update category and sortOrder for notes after drag-and-drop reordering.
  Future<void> batchUpdateCategoryAndOrder(
    List<({String id, String? category, int sortOrder})> updates,
  ) async {
    await _db.transaction(() async {
      for (final u in updates) {
        await (_db.update(
          _db.personalNotes,
        )..where((t) => t.id.equals(u.id))).write(
          PersonalNotesCompanion(
            category: Value(u.category),
            sortOrder: Value(u.sortOrder),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
      }
    });
    onWrite?.call();
  }

  /// Stream of distinct, sorted category names from all notes.
  Stream<List<String>> watchNoteCategories() {
    return watchAll().map(
      (notes) =>
          notes.map((n) => n.category).whereType<String>().toSet().toList()
            ..sort(),
    );
  }

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
      category: Value(note.category),
      sortOrder: Value(note.sortOrder),
      createdAt: Value(note.createdAt),
      updatedAt: Value(note.updatedAt),
      syncState: const Value('dirty'),
      webdavEtag: const Value(null),
    );
  }

  Future<void> _scheduleReminderFor(PersonalNote note) async {
    if (note.remindAt == null) return;
    if (note.remindAt!.isBefore(DateTime.now())) return;
    try {
      final body = note.body.length > 100
          ? '${note.body.substring(0, 100)}…'
          : note.body;
      await _notifications?.scheduleReminder(
        id: _notifId(note.id),
        title: note.title,
        body: body,
        at: note.remindAt!,
      );
    } catch (_) {
      // Best-effort: notification scheduling errors should not fail note operations.
    }
  }

  int _notifId(String noteId) => noteId.hashCode.abs();
}
