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

  KidsSyncOrchestrator({
    required AppDatabase db,
    required KidsTaskRepository repo,
    required SyncConfig config,
  })  : _db = db,
        _repo = repo,
        _config = config;

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
    } finally {
      client.dispose();
    }
  }

  /// Pull tasks from parent (from /kinetic/shared/tasks/)
  Future<void> _pullRemoteTasks(WebDavSyncService service) async {
    // WebDavSyncService.pullTasks() pulls from family shared folder by default
    final iCalTasks = await service.pullTasks();
    if (iCalTasks.isEmpty) return;

    final localList = await _db.select(_db.kidsTasks).get();

    for (final ical in iCalTasks) {
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
        await service.pushTask(ical);
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
        await service.deleteTask(row.id);
        await _repo.hardDelete(row.id);
      } catch (_) {}
    }
  }

  // ── Converters ─────────────────────────────────────────────────────────────

  /// Convert iCal task to domain model
  KidsTask _iCalToKidsTask(ICalTask ical) {
    return KidsTask(
      id: ical.uid,
      parentId: _extractCustomProperty(ical.description, 'xKineticParentId') ?? '',
      title: ical.summary,
      notes: _extractBasicDescription(ical.description),
      category: _parseCategory(
        _extractCustomProperty(ical.description, 'xKineticCategory'),
      ),
      priority: _parsePriority(ical.priority),
      dueDate: ical.dueAt,
      isCompleted: ical.status == ICalTaskStatus.completed,
      completedAt:
          ical.status == ICalTaskStatus.completed ? ical.updatedAt : null,
      xpReward: int.tryParse(
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
