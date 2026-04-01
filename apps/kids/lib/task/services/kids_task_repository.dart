import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../models/kids_task.dart';

/// KidsTaskRepository — CRUD for assigned tasks with streaming
///
/// Provides watch streams for UI updates and mutation methods for completion tracking.
/// Tasks are read-only for most fields (assigned by parent); only completion status
/// can be modified locally.
class KidsTaskRepository {
  final AppDatabase _db;

  KidsTaskRepository({required AppDatabase db}) : _db = db;

  /// All assigned tasks, ordered by due date (earliest first)
  Stream<List<KidsTask>> watchAll() {
    return (_db.select(_db.kidsTasks)
          ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
        .watch()
        .map((rows) => rows.map(_taskFromRow).toList());
  }

  /// Only incomplete tasks, ordered by due date
  Stream<List<KidsTask>> watchPending() {
    return (_db.select(_db.kidsTasks)
          ..where((t) => t.isCompleted.equals(false))
          ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
        .watch()
        .map((rows) => rows.map(_taskFromRow).toList());
  }

  /// Single task by ID
  Stream<KidsTask?> watchOne(String id) {
    return (_db.select(_db.kidsTasks)..where((t) => t.id.equals(id)))
        .watchSingleOrNull()
        .map((row) => row != null ? _taskFromRow(row) : null);
  }

  /// Mark a task as complete (sets isCompleted=true, completedAt=now, syncState=dirty)
  Future<void> markComplete(String taskId) async {
    await (_db.update(_db.kidsTasks)..where((t) => t.id.equals(taskId))).write(
      KidsTasksCompanion(
        isCompleted: const Value(true),
        completedAt: Value(DateTime.now().toUtc()),
        syncState: const Value('dirty'),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Undo completion (sets isCompleted=false, completedAt=null, syncState=dirty)
  Future<void> markIncomplete(String taskId) async {
    await (_db.update(_db.kidsTasks)..where((t) => t.id.equals(taskId))).write(
      KidsTasksCompanion(
        isCompleted: const Value(false),
        completedAt: const Value(null),
        syncState: const Value('dirty'),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Soft-delete a task (marks syncState=deleted for sync to push tombstone)
  Future<void> delete(String taskId) async {
    await (_db.update(_db.kidsTasks)..where((t) => t.id.equals(taskId))).write(
      KidsTasksCompanion(
        syncState: const Value('deleted'),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Get all tasks (non-streaming, for sync)
  Future<List<KidsTaskRow>> getAllRows() {
    return _db.select(_db.kidsTasks).get();
  }

  /// Get dirty tasks (local changes to push)
  Future<List<KidsTaskRow>> getDirtyRows() {
    return (_db.select(
      _db.kidsTasks,
    )..where((t) => t.syncState.equals('dirty'))).get();
  }

  /// Get deleted tasks (tombstones to push)
  Future<List<KidsTaskRow>> getDeletedRows() {
    return (_db.select(
      _db.kidsTasks,
    )..where((t) => t.syncState.equals('deleted'))).get();
  }

  /// Insert or update a task (from sync)
  Future<void> upsertTask(KidsTask task) async {
    await _db
        .into(_db.kidsTasks)
        .insert(
          _taskToCompanion(task),
          onConflict: DoUpdate((_) => _taskToCompanion(task)),
        );
  }

  /// Mark a task as synced (sets syncState=clean and updates etag)
  Future<void> markSynced(String taskId, String? etag) async {
    await (_db.update(_db.kidsTasks)..where((t) => t.id.equals(taskId))).write(
      KidsTasksCompanion(
        syncState: const Value('clean'),
        webdavEtag: Value(etag),
      ),
    );
  }

  /// Hard-delete after successful sync (for tombstones)
  Future<void> hardDelete(String taskId) async {
    await (_db.delete(_db.kidsTasks)..where((t) => t.id.equals(taskId))).go();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Convert Drift row to domain model
  KidsTask _taskFromRow(KidsTaskRow row) {
    return KidsTask(
      id: row.id,
      parentId: row.parentId,
      title: row.title,
      notes: row.notes,
      category: TaskCategory.values.firstWhere(
        (e) => e.name == row.category,
        orElse: () => TaskCategory.other,
      ),
      priority: TaskPriority.values[row.priority],
      dueDate: row.dueDate,
      isCompleted: row.isCompleted,
      completedAt: row.completedAt,
      xpReward: row.xpReward,
      syncState: row.syncState,
      webdavEtag: row.webdavEtag,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  /// Convert domain model to Drift companion (for insert/update)
  KidsTasksCompanion _taskToCompanion(KidsTask task) {
    return KidsTasksCompanion(
      id: Value(task.id),
      parentId: Value(task.parentId),
      title: Value(task.title),
      notes: Value(task.notes),
      category: Value(task.category.name),
      priority: Value(task.priority.index),
      dueDate: Value(task.dueDate),
      isCompleted: Value(task.isCompleted),
      completedAt: Value(task.completedAt),
      xpReward: Value(task.xpReward),
      syncState: Value(task.syncState),
      webdavEtag: Value(task.webdavEtag),
      createdAt: Value(task.createdAt),
      updatedAt: Value(task.updatedAt),
    );
  }
}
