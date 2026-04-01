import 'package:drift/drift.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

import '../db/app_database.dart';

/// Drives a full sync cycle against the WebDAV server.
///
/// Call [sync] in the background (e.g. on app resume or a timer).
class SyncOrchestrator {
  final AppDatabase _db;
  final SyncConfig _config;

  SyncOrchestrator({required AppDatabase db, required SyncConfig config})
    : _db = db,
      _config = config;

  Future<void> sync() async {
    final client = WebDavClient(
      baseUrl: _config.baseUrl,
      username: _config.username,
      password: _config.password,
    );
    final service = WebDavSyncService(client: client, config: _config);
    try {
      await _syncTasks(service);
    } finally {
      client.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // Tasks
  // ---------------------------------------------------------------------------

  Future<void> _syncTasks(WebDavSyncService service) async {
    // 1. Push dirty local tasks.
    final dirtyRows = await (_db.select(
      _db.personalTasks,
    )..where((t) => t.syncState.equals('dirty'))).get();

    for (final row in dirtyRows) {
      final icalTask = _rowToICalTask(row);
      try {
        await service.pushTask(icalTask);
        await (_db.update(
          _db.personalTasks,
        )..where((t) => t.id.equals(row.id))).write(
          PersonalTasksCompanion(
            syncState: const Value('clean'),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } catch (_) {
        // Leave dirty for next cycle.
      }
    }

    // 2. Push locally-deleted tasks (tombstones stored with syncState='deleted').
    final deletedRows = await (_db.select(
      _db.personalTasks,
    )..where((t) => t.syncState.equals('deleted'))).get();

    for (final row in deletedRows) {
      try {
        await service.deleteTask(row.id);
        await (_db.delete(
          _db.personalTasks,
        )..where((t) => t.id.equals(row.id))).go();
      } catch (_) {}
    }

    // 3. Pull from server.
    final remoteList = await service.pullTasks();
    if (remoteList.isEmpty) return;

    final localList = await _db.select(_db.personalTasks).get();
    final merge = WebDavSyncService.mergeTasks(
      localList.map(_rowToICalTask).toList(),
      remoteList,
    );

    // 4. Apply merged result.
    for (final task in merge.merged) {
      final existing = localList.where((r) => r.id == task.uid).firstOrNull;
      if (existing == null) {
        // New from server — insert.
        await _db
            .into(_db.personalTasks)
            .insertOnConflictUpdate(_icalTaskToCompanion(task, etag: null));
      } else if (!existing.updatedAt.isAtSameMomentAs(task.updatedAt)) {
        // Remote is different — update.
        await (_db.update(_db.personalTasks)
              ..where((t) => t.id.equals(task.uid)))
            .write(_icalTaskToCompanion(task, etag: existing.webdavEtag));
      }
    }

    // 5. Push tasks that were newer locally.
    for (final task in merge.toPush) {
      try {
        await service.pushTask(task);
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // Conversion helpers
  // ---------------------------------------------------------------------------

  static ICalTask _rowToICalTask(PersonalTaskRow row) {
    return ICalTask(
      uid: row.id,
      summary: row.title,
      description: row.notes,
      status: row.isCompleted
          ? ICalTaskStatus.completed
          : ICalTaskStatus.needsAction,
      priority: _driftPriorityToICal(row.priority),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      dueAt: row.dueDate,
      remindAt: row.remindAt,
      rrule: row.recurrenceRule,
    );
  }

  static PersonalTasksCompanion _icalTaskToCompanion(
    ICalTask task, {
    required String? etag,
  }) {
    return PersonalTasksCompanion(
      id: Value(task.uid),
      title: Value(task.summary),
      notes: Value(task.description),
      isCompleted: Value(task.status == ICalTaskStatus.completed),
      completedAt: task.status == ICalTaskStatus.completed
          ? Value(task.updatedAt)
          : const Value(null),
      priority: Value(_icalPriorityToDrift(task.priority)),
      dueDate: Value(task.dueAt),
      remindAt: Value(task.remindAt),
      recurrenceRule: Value(task.rrule),
      createdAt: Value(task.createdAt),
      updatedAt: Value(task.updatedAt),
      syncState: const Value('clean'),
      webdavEtag: Value(etag),
      // Keep existing list / category / flags — don't overwrite from server.
      isAllDay: const Value(true),
      isFlagged: const Value(false),
      isPrivate: const Value(false),
      category: const Value('other'),
      sortOrder: const Value(0),
    );
  }

  static int _driftPriorityToICal(int drift) => switch (drift) {
    3 => 1, // high → iCal 1
    2 => 5, // medium → iCal 5
    1 => 9, // low → iCal 9
    _ => 0,
  };

  static int _icalPriorityToDrift(int ical) => switch (ical) {
    1 => 3,
    5 => 2,
    9 => 1,
    _ => 0,
  };
}
