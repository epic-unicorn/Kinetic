import 'package:drift/drift.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

import '../db/app_database.dart';
import '../todo/models/enums.dart';
import '../todo/models/personal_task.dart';

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
      await _syncNotes(service);
      await _syncProposals(service);
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
  // Notes
  // ---------------------------------------------------------------------------

  Future<void> _syncNotes(WebDavSyncService service) async {
    // 1. Push dirty local notes.
    final dirtyRows = await (_db.select(
      _db.personalNotes,
    )..where((t) => t.syncState.equals('dirty'))).get();

    for (final row in dirtyRows) {
      final icalNote = _rowToICalNote(row);
      try {
        await service.pushNote(icalNote);
        await (_db.update(
          _db.personalNotes,
        )..where((t) => t.id.equals(row.id))).write(
          PersonalNotesCompanion(
            syncState: const Value('clean'),
            updatedAt: Value(DateTime.now()),
          ),
        );
      } catch (_) {
        // Leave dirty for next cycle.
      }
    }

    // 2. Push locally-deleted notes (tombstones stored with syncState='deleted').
    final deletedRows = await (_db.select(
      _db.personalNotes,
    )..where((t) => t.syncState.equals('deleted'))).get();

    for (final row in deletedRows) {
      try {
        await service.deleteNote(row.id, isShared: row.isShared);
        await (_db.delete(
          _db.personalNotes,
        )..where((t) => t.id.equals(row.id))).go();
      } catch (_) {}
    }

    // 3. Pull from server.
    final remoteList = await service.pullNotes();
    if (remoteList.isEmpty) return;

    final localList = await _db.select(_db.personalNotes).get();

    // 4. Apply merged result using Last-Write-Wins.
    for (final note in remoteList) {
      final existing = localList.where((r) => r.id == note.uid).firstOrNull;
      if (existing == null) {
        // New from server — insert.
        await _db
            .into(_db.personalNotes)
            .insertOnConflictUpdate(_icalNoteToCompanion(note, etag: null));
      } else if (!existing.updatedAt.isAtSameMomentAs(note.updatedAt)) {
        // Remote is different — update.
        await (_db.update(_db.personalNotes)
              ..where((t) => t.id.equals(note.uid)))
            .write(_icalNoteToCompanion(note, etag: existing.webdavEtag));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Conversion helpers
  // ---------------------------------------------------------------------------

  static ICalNote _rowToICalNote(PersonalNoteRow row) {
    return ICalNote(
      uid: row.id,
      summary: row.title,
      description: row.body,
      isShared: row.isShared,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      remindAt: row.remindAt,
    );
  }

  static PersonalNotesCompanion _icalNoteToCompanion(
    ICalNote note, {
    required String? etag,
  }) {
    return PersonalNotesCompanion(
      id: Value(note.uid),
      title: Value(note.summary),
      body: Value(note.description ?? ''),
      isShared: Value(note.isShared),
      createdAt: Value(note.createdAt),
      updatedAt: Value(note.updatedAt),
      remindAt: Value(note.remindAt),
      syncState: const Value('clean'),
      webdavEtag: Value(etag),
    );
  }

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

  // ---------------------------------------------------------------------------
  // Proposals
  // ---------------------------------------------------------------------------

  Future<void> _syncProposals(WebDavSyncService service) async {
    // 1. Pull remote proposals.
    final remotes = await service.pullProposals();
    final remoteProposals = _jsonListToProposals(remotes);

    // 2. Get local proposals and merge.
    final localRows = await _db.select(_db.partnerProposals).get();
    final locals = localRows.map(_proposalRowToProposal).toList();

    // 3. LWW merge on updatedAt.
    final merged = _mergeProposals(locals, remoteProposals);

    // 4. Write merged proposals to local DB.
    for (final proposal in merged) {
      await _db
          .into(_db.partnerProposals)
          .insertOnConflictUpdate(_proposalToCompanion(proposal));
    }
  }

  PartnerProposal _proposalRowToProposal(PartnerProposalRow row) {
    return PartnerProposal(
      id: row.id,
      fromParentId: row.fromParentId,
      taskTitle: row.taskTitle,
      taskNotes: row.taskNotes,
      taskCategory: TaskCategory.values.firstWhere(
        (e) => e.name == row.taskCategory,
      ),
      taskPriority: TaskPriority.values[row.taskPriority],
      taskDueDate: row.taskDueDate,
      status: ProposalStatus.values.firstWhere((e) => e.name == row.status),
      receivedAt: row.receivedAt,
      updatedAt: row.updatedAt,
    );
  }

  PartnerProposal _jsonToProposal(Map<String, dynamic> json) {
    return PartnerProposal(
      id: json['id'] as String,
      fromParentId: json['fromParentId'] as String,
      taskTitle: json['taskTitle'] as String,
      taskNotes: json['taskNotes'] as String?,
      taskCategory: TaskCategory.values.firstWhere(
        (e) => e.name == json['taskCategory'],
      ),
      taskPriority: TaskPriority.values[json['taskPriority'] as int],
      taskDueDate: json['taskDueDate'] != null
          ? DateTime.parse(json['taskDueDate'] as String)
          : null,
      status: ProposalStatus.values.firstWhere((e) => e.name == json['status']),
      receivedAt: DateTime.parse(json['receivedAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  List<PartnerProposal> _jsonListToProposals(List<Map<String, dynamic>> jsons) {
    return jsons.map(_jsonToProposal).toList();
  }

  PartnerProposalsCompanion _proposalToCompanion(PartnerProposal p) {
    return PartnerProposalsCompanion(
      id: Value(p.id),
      fromParentId: Value(p.fromParentId),
      taskTitle: Value(p.taskTitle),
      taskNotes: Value(p.taskNotes),
      taskCategory: Value(p.taskCategory.name),
      taskPriority: Value(p.taskPriority.index),
      taskDueDate: Value(p.taskDueDate),
      status: Value(p.status.name),
      receivedAt: Value(p.receivedAt),
      updatedAt: Value(p.updatedAt),
      syncState: const Value('clean'),
    );
  }

  /// LWW merge: remote wins if newer, local wins if older.
  List<PartnerProposal> _mergeProposals(
    List<PartnerProposal> local,
    List<PartnerProposal> remote,
  ) {
    final remoteById = {for (final p in remote) p.id: p};
    final localById = {for (final p in local) p.id: p};

    final merged = <PartnerProposal>[];

    for (final id in {...remoteById.keys, ...localById.keys}) {
      final r = remoteById[id];
      final l = localById[id];

      if (r == null) {
        merged.add(l!);
      } else if (l == null) {
        merged.add(r);
      } else if (!r.updatedAt.isBefore(l.updatedAt)) {
        merged.add(r);
      } else {
        merged.add(l);
      }
    }
    return merged;
  }
}
