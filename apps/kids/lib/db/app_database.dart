import 'package:drift/drift.dart';

import 'encrypted_open.dart';
import 'tables.dart';

part 'app_database.drift.dart';

/// AppDatabase — Drift database for kids app
///
/// Stores assigned tasks synced from parent app via WebDAV.
/// Uses same encryption and sync strategy as parent app.
@DriftDatabase(tables: [KidsTasks])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Internal constructor for testing with custom executor
  AppDatabase.withExecutor(super.executor);

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return openEncryptedDatabase(name: 'kids_app');
  }

  /// Get all tasks
  Future<List<KidsTaskRow>> getAllTasks() {
    return select(kidsTasks).get();
  }

  /// Get a single task by ID
  Future<KidsTaskRow?> getTask(String id) {
    return (select(kidsTasks)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Insert or replace a task
  Future<void> upsertTask(Insertable<KidsTaskRow> task) {
    return into(kidsTasks).insert(task, onConflict: DoUpdate((old) => task));
  }

  /// Soft-delete a task
  Future<void> deleteTask(String id) {
    return (update(kidsTasks)..where((t) => t.id.equals(id))).write(
      KidsTasksCompanion(
        syncState: const Value('deleted'),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }
}
