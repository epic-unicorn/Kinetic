import 'package:flutter/foundation.dart' show visibleForTesting, VoidCallback;
import 'package:kinetic_webdav/kinetic_webdav.dart';

import '../db/app_database.dart';
import '../task/models/kids_task.dart';
import '../task/services/kids_task_repository.dart';

/// KidsSyncOrchestrator — WebDAV sync for assigned tasks
///
/// Pulls tasks assigned by parents and pushes local completion status updates.
///
/// Sync Flow:
/// 1. Pull: from /kinetic/shared/tasks/ (parent-assigned tasks)
/// 2. Merge: with local DB (Last-Write-Wins on updatedAt)
/// 3. Push: dirty rows (completion status changes) back to same location
/// 4. Clean: mark synced rows as clean, hard-delete tombstones
class KidsSyncOrchestrator {
  final AppDatabase _db;
  final KidsTaskRepository _repo;
  final SyncConfig _config;

  /// The kid's own ID as assigned by the parent during enrollment.
  /// If empty, all shared tasks are accepted (backwards-compatible).
  final String _myKidId;

  KidsSyncOrchestrator({
    required AppDatabase db,
    required KidsTaskRepository repo,
    required SyncConfig config,
    String myKidId = '',
    this.onDisconnected,
  }) : _db = db,
       _repo = repo,
       _config = config,
       _myKidId = myKidId;

  /// Optional callback invoked when the parent sends a disconnect tombstone
  /// for this kid device.  The caller should clear the enrollment.
  final VoidCallback? onDisconnected;

  /// Main sync cycle: pull remote tasks, push local changes
  Future<void> sync() async {
    final client = WebDavClient(
      baseUrl: _config.baseUrl,
      username: _config.username,
      password: _config.password,
    );
    final service = WebDavSyncService(client: client, config: _config);

    try {
      // Pull parent-assigned tasks
      await _pullRemoteTasks(service);
      // Push local changes (completion status)
      await _pushLocalChanges(service);
      // Heartbeat: write presence so the parent can see this kid is active
      await _pushPresence(service);
      // Check if the parent has disconnected this kid
      await _checkDisconnect(service);
    } finally {
      client.dispose();
    }
  }

  // ---------------------------------------------------------------------------
  // Presence
  // ---------------------------------------------------------------------------

  Future<void> _pushPresence(WebDavSyncService service) async {
    if (_myKidId.isEmpty || _config.familyKeyBytes == null) return;
    try {
      await service.pushPresence(
        PresenceInfo(
          deviceId: _myKidId,
          deviceType: 'kid',
          displayName: _myKidId,
          lastSeen: DateTime.now().toUtc(),
        ),
      );
    } catch (_) {
      // Non-critical.
    }
  }

  Future<void> _checkDisconnect(WebDavSyncService service) async {
    if (_myKidId.isEmpty || _config.familyKeyBytes == null) return;
    try {
      final tombstones = await service.pullDisconnects();
      final mine = tombstones.where((t) => t.deviceId == _myKidId);
      if (mine.isNotEmpty) {
        onDisconnected?.call();
      }
    } catch (_) {
      // Non-critical.
    }
  }

  /// Pull tasks from parent (from /kinetic/shared/tasks/)
  Future<void> _pullRemoteTasks(WebDavSyncService service) async {
    final iCalTasks = await service.pullSharedTasks();

    final localList = await _db.select(_db.kidsTasks).get();
    final remoteIds = iCalTasks.map((t) => t.uid).toSet();

    // Detect and remove tasks that were deleted on the parent's device.
    // If a task exists locally but not on the server, and it's clean (not dirty),
    // then it was deleted by the parent and should be removed locally too.
    for (final local in localList) {
      if (local.syncState == 'clean' && !remoteIds.contains(local.id)) {
        await _repo.hardDelete(local.id);
      }
    }

    if (iCalTasks.isEmpty) return;

    for (final ical in iCalTasks) {
      // If the task targets a specific kid, skip it unless it's meant for this device.
      final targetKidId = _extractCustomProperty(
        ical.description,
        'xKineticTargetKidId',
      );
      if (targetKidId != null &&
          targetKidId.isNotEmpty &&
          _myKidId.isNotEmpty &&
          targetKidId != _myKidId) {
        continue;
      }

      final remoteTask = _iCalToKidsTask(ical);
      final existing = localList
          .where((r) => r.id == remoteTask.id)
          .cast<KidsTaskRow?>()
          .firstOrNull;

      if (existing == null) {
        // New from parent → insert
        await _repo.upsertTask(remoteTask);
      } else if (remoteTask.updatedAt.isAfter(existing.updatedAt)) {
        // Remote newer → update (LWW merge)
        await _repo.upsertTask(remoteTask);
      }
      // else: local newer or equal → keep local (will push next cycle)
    }
  }

  /// Push completion status updates back to WebDAV
  Future<void> _pushLocalChanges(WebDavSyncService service) async {
    // Push dirty tasks (completion updates)
    final dirtyRows = await (_db.select(
      _db.kidsTasks,
    )..where((t) => t.syncState.equals('dirty'))).get();

    for (final row in dirtyRows) {
      final ical = _taskRowToICal(row);
      try {
        await service.pushSharedTask(ical);
        await _repo.markSynced(row.id, row.id);
      } catch (_) {
        // Leave dirty for retry
      }
    }

    // Hard-delete tombstones (once server confirms)
    final deletedRows = await (_db.select(
      _db.kidsTasks,
    )..where((t) => t.syncState.equals('deleted'))).get();

    for (final row in deletedRows) {
      try {
        await service.deleteSharedTask(row.id);
        await _repo.hardDelete(row.id);
      } catch (_) {}
    }
  }

  // ── Converters ─────────────────────────────────────────────────────────────

  /// Convert iCal task to domain model
  @visibleForTesting
  KidsTask iCalToKidsTask(ICalTask ical) => _iCalToKidsTask(ical);

  /// Convert Drift row to iCal task
  @visibleForTesting
  ICalTask taskRowToICal(KidsTaskRow row) => _taskRowToICal(row);

  KidsTask _iCalToKidsTask(ICalTask ical) {
    return KidsTask(
      id: ical.uid,
      parentId:
          _extractCustomProperty(ical.description, 'xKineticParentId') ?? '',
      title: ical.summary,
      notes: _extractBasicDescription(ical.description),
      category: _parseCategory(
        _extractCustomProperty(ical.description, 'xKineticCategory'),
      ),
      priority: _parsePriority(ical.priority),
      dueDate: ical.dueAt,
      isCompleted: ical.status == ICalTaskStatus.completed,
      completedAt: ical.status == ICalTaskStatus.completed
          ? ical.updatedAt
          : null,
      xpReward:
          int.tryParse(
            _extractCustomProperty(ical.description, 'xKineticXpReward') ?? '',
          ) ??
          10,
      syncState: 'clean',
      webdavEtag: ical.uid,
      createdAt: ical.createdAt,
      updatedAt: ical.updatedAt,
    );
  }

  /// Convert Drift row to iCal task
  ICalTask _taskRowToICal(KidsTaskRow row) {
    return ICalTask(
      uid: row.id,
      summary: row.title,
      description: _buildDescription(
        row.notes,
        parentId: row.parentId,
        category: row.category,
        xpReward: row.xpReward,
      ),
      status: row.isCompleted
          ? ICalTaskStatus.completed
          : ICalTaskStatus.needsAction,
      priority: _priorityToInt(row.priority),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      dueAt: row.dueDate,
      remindAt: null,
      rrule: null,
    );
  }

  /// Extract custom X-property from description
  String? _extractCustomProperty(String? desc, String key) {
    if (desc == null || desc.isEmpty) return null;
    final regex = RegExp('$key:([^;]+)');
    final match = regex.firstMatch(desc);
    return match?.group(1);
  }

  /// Extract base description (before custom properties)
  String _extractBasicDescription(String? desc) {
    if (desc == null || desc.isEmpty) return '';
    final parts = desc.split(';');
    return parts.first.trim();
  }

  /// Build description with custom X-properties
  String _buildDescription(
    String? notes, {
    required String parentId,
    required String category,
    required int xpReward,
  }) {
    final baseNotes = notes ?? '';
    return '$baseNotes;xKineticParentId:$parentId;xKineticCategory:$category;xKineticXpReward:$xpReward';
  }

  /// Parse category from string
  TaskCategory _parseCategory(String? raw) {
    if (raw == null || raw.isEmpty) return TaskCategory.other;
    try {
      return TaskCategory.values.firstWhere(
        (e) => e.name == raw.toLowerCase().trim(),
        orElse: () => TaskCategory.other,
      );
    } catch (_) {
      return TaskCategory.other;
    }
  }

  /// Parse priority from iCal int
  TaskPriority _parsePriority(int ical) {
    return switch (ical) {
      1 => TaskPriority.urgent,
      5 => TaskPriority.normal,
      9 => TaskPriority.low,
      _ => TaskPriority.normal,
    };
  }

  /// Convert priority int to iCal int
  int _priorityToInt(int driftPriority) {
    // Drift stores as enum index (0=low, 1=normal, 2=urgent)
    return switch (driftPriority) {
      2 => 1, // urgent → iCal 1
      1 => 5, // normal → iCal 5
      0 => 9, // low → iCal 9
      _ => 5,
    };
  }
}
