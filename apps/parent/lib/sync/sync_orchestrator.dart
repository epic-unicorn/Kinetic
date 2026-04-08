import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

import '../db/app_database.dart';
import '../partner/models/partner_proposal.dart';
import '../partner/services/load_analyzer.dart';
import '../partner/services/load_sync_service.dart';
import '../todo/models/enums.dart';

/// Drives a full sync cycle against the WebDAV server.
///
/// Call [sync] in the background (e.g. on app resume or a timer).
class SyncOrchestrator {
  final AppDatabase _db;
  final SyncConfig _config;

  SyncOrchestrator({required AppDatabase db, required SyncConfig config})
    : _db = db,
      _config = config;

  /// The WebDAV username (used as the local parent ID).
  String get username => _config.username;

  /// The stable parent UUID (used to identify this parent in proposals).
  String get parentId => _config.parentId;

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
      await _syncLoad(service);
    } finally {
      client.dispose();
    }
  }

  /// Runs the full sync pipeline against a pre-built [service].
  ///
  /// Exposed for integration testing — production code always uses [sync].
  @visibleForTesting
  Future<void> syncWithService(WebDavSyncService service) async {
    await _syncTasks(service);
    await _syncNotes(service);
    await _syncProposals(service);
    await _syncLoad(service);
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

    // 6. Push/sync tasks delegated to kids (shared tasks folder).
    if (_config.familyKeyBytes != null) {
      await _syncKidsTasks(service);
    }
  }

  /// Pushes tasks with a kidsTaskId to the shared tasks folder and detects
  /// completion from the kids side (auto-completes the parent's task).
  Future<void> _syncKidsTasks(WebDavSyncService service) async {
    // Push any dirty tasks that have a kidsTaskId.
    final rows =
        await (_db.select(_db.personalTasks)..where(
              (t) => t.kidsTaskId.isNotNull() & t.syncState.equals('dirty'),
            ))
            .get();
    for (final row in rows) {
      final kidsTask = ICalTask(
        uid: row.kidsTaskId!,
        summary: row.title,
        description: row.notes,
        status: row.isCompleted
            ? ICalTaskStatus.completed
            : ICalTaskStatus.needsAction,
        priority: _driftPriorityToICal(row.priority),
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        dueAt: row.dueDate,
      );
      try {
        await service.pushSharedTask(kidsTask);
      } catch (_) {}
    }

    // Pull shared tasks to detect kids completing an assigned task.
    final sharedTasks = await service.pullSharedTasks();
    for (final sharedTask in sharedTasks) {
      if (sharedTask.status != ICalTaskStatus.completed) continue;
      // Find a parent task linked to this kids task that is still incomplete.
      final linked =
          await (_db.select(_db.personalTasks)..where(
                (t) =>
                    t.kidsTaskId.equals(sharedTask.uid) &
                    t.isCompleted.equals(false),
              ))
              .getSingleOrNull();
      if (linked != null) {
        await (_db.update(
          _db.personalTasks,
        )..where((t) => t.id.equals(linked.id))).write(
          PersonalTasksCompanion(
            isCompleted: const Value(true),
            completedAt: Value(sharedTask.updatedAt),
            updatedAt: Value(sharedTask.updatedAt),
            syncState: const Value('dirty'),
          ),
        );
      }
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
        // Push to the correct folder based on current isShared value
        await service.pushNote(icalNote);

        // If this note was previously synced, ensure there's no orphaned file
        // in the "other" folder (could happen if isShared was toggled).
        // Try to delete from the opposite location (silently ignore 404s).
        try {
          final oppositeIsShared = !icalNote.isShared;
          await service.deleteNote(row.id, isShared: oppositeIsShared);
        } catch (_) {
          // File may not exist — that's fine.
        }

        await (_db.update(
          _db.personalNotes,
        )..where((t) => t.id.equals(row.id))).write(
          // Only clear the dirty flag — do NOT change updatedAt so that the
          // iCal timestamp and the local timestamp remain in sync.
          const PersonalNotesCompanion(syncState: Value('clean')),
        );
      } catch (e) {
        // Log the error instead of silently failing
        print('Error pushing note ${row.id}: $e');
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
    print('Pulled ${remoteList.length} notes from server (personal + shared)');

    final localList = await _db.select(_db.personalNotes).get();
    final remoteIds = remoteList.map((n) => n.uid).toSet();

    // 3a. Detect and remove shared notes that were deleted on the partner's device.
    // If a shared note exists locally but not on the server, and it's clean (not dirty),
    // then it was deleted remotely and should be removed locally too.
    for (final local in localList) {
      if (local.isShared &&
          local.syncState == 'clean' &&
          !remoteIds.contains(local.id)) {
        print(
          'Shared note deleted on partner device, removing locally: ${local.id}',
        );
        await (_db.delete(
          _db.personalNotes,
        )..where((t) => t.id.equals(local.id))).go();
      }
    }

    if (remoteList.isEmpty) return;

    // 4. Apply Last-Write-Wins merge: remote wins only when it is strictly
    //    newer than the local copy AND the local copy is clean (unmodified).
    //    If the local copy is dirty the user has unsaved changes — we keep
    //    them and they will be pushed on the next sync cycle.
    for (final note in remoteList) {
      final existing = localList.where((r) => r.id == note.uid).firstOrNull;
      if (existing == null) {
        // New from server — insert.
        print(
          'Inserting new note from server: ${note.uid} (isShared=${note.isShared})',
        );
        await _db
            .into(_db.personalNotes)
            .insertOnConflictUpdate(_icalNoteToCompanion(note, etag: null));
      } else if (existing.syncState != 'dirty' &&
          note.updatedAt.isAfter(existing.updatedAt)) {
        // Remote is newer and local has no pending changes — adopt remote.
        print(
          'Updating existing note from server: ${note.uid} (isShared=${note.isShared})',
        );
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
    // 1. Push dirty local proposals (accepted/rejected/snoozed feedback +
    //    new auto-generated outbound proposals).
    final dirtyRows = await (_db.select(
      _db.partnerProposals,
    )..where((p) => p.syncState.equals('dirty'))).get();
    for (final row in dirtyRows) {
      try {
        final proposal = _proposalRowToProposal(row);
        final json = _proposalToJson(proposal);
        await service.pushProposal(json);
        await (_db.update(_db.partnerProposals)
              ..where((p) => p.id.equals(row.id)))
            .write(const PartnerProposalsCompanion(syncState: Value('clean')));
      } catch (_) {
        // Leave dirty for next cycle.
      }
    }

    // 2. Pull remote proposals.
    final remotes = await service.pullProposals();
    final remoteProposals = _jsonListToProposals(remotes);

    // 3. Get local proposals and merge (LWW).
    final localRows = await _db.select(_db.partnerProposals).get();
    final locals = localRows.map(_proposalRowToProposal).toList();
    final merged = _mergeProposals(locals, remoteProposals);

    // 4. Write merged proposals to local DB.
    for (final proposal in merged) {
      await _db
          .into(_db.partnerProposals)
          .insertOnConflictUpdate(_proposalToCompanion(proposal));
    }

    // 4a. Clean up tasks for accepted outgoing proposals.
    // If a proposal sent by this device (fromParentId == myParentId) changed
    // from pending to accepted, the task should be deleted from this device.
    final myParentId = _config.parentId;
    for (final proposal in merged) {
      if (proposal.fromParentId != myParentId) continue; // Not ours
      if (proposal.status != ProposalStatus.accepted) continue; // Not accepted

      // Find the local proposal's previous status
      final localProposal = locals
          .where((p) => p.id == proposal.id)
          .firstOrNull;
      if (localProposal != null &&
          localProposal.status == ProposalStatus.pending) {
        // This proposal was just accepted — delete the corresponding task
        // Search by title (since proposals don't have an explicit taskId link)
        final task =
            await (_db.select(_db.personalTasks)..where(
                  (t) =>
                      t.title.equals(proposal.taskTitle) &
                      t.syncState.equals('clean') &
                      t.isCompleted.equals(false),
                ))
                .getSingleOrNull();

        if (task != null) {
          // Soft-delete the task (mark as deleted, keep for tombstone sync)
          await (_db.update(_db.personalTasks)
                ..where((t) => t.id.equals(task.id)))
              .write(const PersonalTasksCompanion(syncState: Value('deleted')));
        }
      }
    }
  }

  PartnerProposal _proposalRowToProposal(PartnerProposalRow row) {
    return PartnerProposal(
      id: row.id,
      fromParentId: row.fromParentId,
      taskTitle: row.taskTitle,
      taskNotes: row.taskNotes,
      taskPriority: TaskPriority.values[row.taskPriority],
      taskDueDate: row.taskDueDate,
      status: ProposalStatus.values.firstWhere((e) => e.name == row.status),
      receivedAt: row.receivedAt,
      updatedAt: row.updatedAt,
      autoGenerated: row.autoGenerated,
    );
  }

  Map<String, dynamic> _proposalToJson(PartnerProposal p) => {
    'id': p.id,
    'fromParentId': p.fromParentId,
    'taskTitle': p.taskTitle,
    'taskNotes': p.taskNotes,
    'taskPriority': p.taskPriority.index,
    'taskDueDate': p.taskDueDate?.toIso8601String(),
    'status': p.status.name,
    'receivedAt': p.receivedAt.toIso8601String(),
    'updatedAt': p.updatedAt.toIso8601String(),
    'autoGenerated': p.autoGenerated,
  };

  PartnerProposal _jsonToProposal(Map<String, dynamic> json) {
    return PartnerProposal(
      id: json['id'] as String,
      fromParentId: json['fromParentId'] as String,
      taskTitle: json['taskTitle'] as String,
      taskNotes: json['taskNotes'] as String?,
      taskPriority: TaskPriority.values[json['taskPriority'] as int],
      taskDueDate: json['taskDueDate'] != null
          ? DateTime.parse(json['taskDueDate'] as String)
          : null,
      status: ProposalStatus.values.firstWhere((e) => e.name == json['status']),
      receivedAt: DateTime.parse(json['receivedAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      autoGenerated: json['autoGenerated'] as bool? ?? false,
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
      taskCategory: const Value('other'),
      taskPriority: Value(p.taskPriority.index),
      taskDueDate: Value(p.taskDueDate),
      status: Value(p.status.name),
      receivedAt: Value(p.receivedAt),
      updatedAt: Value(p.updatedAt),
      autoGenerated: Value(p.autoGenerated),
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

  // ---------------------------------------------------------------------------
  // Load Metrics
  // ---------------------------------------------------------------------------

  Future<void> _syncLoad(WebDavSyncService service) async {
    final analyzer = LoadAnalyzer(db: _db);
    final syncService = LoadSyncService(service: service, analyzer: analyzer);

    // Push this device's user's current load metrics, then pull family load.
    // Use parentId to consistently identify this parent (not the WebDAV username).
    await syncService.syncLoad(_config.parentId, _config.username);
  }
}
