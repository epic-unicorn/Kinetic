import 'package:flutter_test/flutter_test.dart';
import 'package:kids/db/app_database.dart';
import 'package:kids/task/models/kids_task.dart';
import 'package:kids/task/services/kids_task_repository.dart';

import '../helpers/test_database.dart';

void main() {
  group('KidsTaskRepository', () {
    late AppDatabase db;
    late KidsTaskRepository repository;

    setUp(() {
      db = createTestDatabase();
      repository = KidsTaskRepository(db: db);
    });

    tearDown(() async {
      await db.close();
    });

    test('watchAll returns empty stream initially', () async {
      final tasks = await repository.watchAll().first;
      expect(tasks, isEmpty);
    });

    test('watchAll returns tasks ordered by due date', () async {
      final now = DateTime.now().toUtc();
      final task1 = KidsTask(
        id: '1',
        parentId: 'parent1',
        title: 'Task 1',
        notes: 'Notes 1',
        category: TaskCategory.household,
        priority: TaskPriority.normal,
        dueDate: now.add(const Duration(days: 2)),
        isCompleted: false,
        completedAt: null,
        xpReward: 10,
        syncState: 'clean',
        webdavEtag: 'etag1',
        createdAt: now,
        updatedAt: now,
      );

      final task2 = KidsTask(
        id: '2',
        parentId: 'parent1',
        title: 'Task 2',
        notes: 'Notes 2',
        category: TaskCategory.school,
        priority: TaskPriority.high,
        dueDate: now.add(const Duration(days: 1)),
        isCompleted: false,
        completedAt: null,
        xpReward: 20,
        syncState: 'clean',
        webdavEtag: 'etag2',
        createdAt: now,
        updatedAt: now,
      );

      // Insert tasks
      await repository.upsertTask(task1);
      await repository.upsertTask(task2);

      // Verify they come back in due date order
      final tasks = await repository.watchAll().first;
      expect(tasks.length, 2);
      expect(tasks[0].id, '2'); // task2 due earlier
      expect(tasks[1].id, '1'); // task1 due later
    });

    test('watchPending returns only incomplete tasks', () async {
      final now = DateTime.now().toUtc();
      final completedTask = KidsTask(
        id: '1',
        parentId: 'parent1',
        title: 'Completed',
        notes: '',
        category: TaskCategory.household,
        priority: TaskPriority.normal,
        dueDate: now,
        isCompleted: true,
        completedAt: now,
        xpReward: 10,
        syncState: 'clean',
        webdavEtag: 'etag1',
        createdAt: now,
        updatedAt: now,
      );

      final pendingTask = KidsTask(
        id: '2',
        parentId: 'parent1',
        title: 'Pending',
        notes: '',
        category: TaskCategory.school,
        priority: TaskPriority.normal,
        dueDate: now,
        isCompleted: false,
        completedAt: null,
        xpReward: 10,
        syncState: 'clean',
        webdavEtag: 'etag2',
        createdAt: now,
        updatedAt: now,
      );

      await repository.upsertTask(completedTask);
      await repository.upsertTask(pendingTask);

      final pending = await repository.watchPending().first;
      expect(pending.length, 1);
      expect(pending[0].id, '2');
    });

    test('watchOne returns single task by ID', () async {
      final now = DateTime.now().toUtc();
      final task = KidsTask(
        id: 'task123',
        parentId: 'parent1',
        title: 'Test Task',
        notes: 'Test notes',
        category: TaskCategory.household,
        priority: TaskPriority.normal,
        dueDate: now,
        isCompleted: false,
        completedAt: null,
        xpReward: 10,
        syncState: 'clean',
        webdavEtag: 'etag1',
        createdAt: now,
        updatedAt: now,
      );

      await repository.upsertTask(task);

      final fetched = await repository.watchOne('task123').first;
      expect(fetched, isNotNull);
      expect(fetched!.title, 'Test Task');
    });

    test('markComplete sets isCompleted=true and syncState=dirty', () async {
      final now = DateTime.now().toUtc();
      final task = KidsTask(
        id: 'task1',
        parentId: 'parent1',
        title: 'Task',
        notes: '',
        category: TaskCategory.household,
        priority: TaskPriority.normal,
        dueDate: now,
        isCompleted: false,
        completedAt: null,
        xpReward: 10,
        syncState: 'clean',
        webdavEtag: 'etag',
        createdAt: now,
        updatedAt: now,
      );

      await repository.upsertTask(task);
      await repository.markComplete('task1');

      final updated = await repository.watchOne('task1').first;
      expect(updated!.isCompleted, true);
      expect(updated.completedAt, isNotNull);
      expect(updated.syncState, 'dirty');
    });

    test('markIncomplete reverses completion', () async {
      final now = DateTime.now().toUtc();
      final task = KidsTask(
        id: 'task1',
        parentId: 'parent1',
        title: 'Task',
        notes: '',
        category: TaskCategory.household,
        priority: TaskPriority.normal,
        dueDate: now,
        isCompleted: true,
        completedAt: now,
        xpReward: 10,
        syncState: 'clean',
        webdavEtag: 'etag',
        createdAt: now,
        updatedAt: now,
      );

      await repository.upsertTask(task);
      await repository.markIncomplete('task1');

      final updated = await repository.watchOne('task1').first;
      expect(updated!.isCompleted, false);
      expect(updated.completedAt, isNull);
      expect(updated.syncState, 'dirty');
    });

    test('delete soft-deletes task (syncState=deleted)', () async {
      final now = DateTime.now().toUtc();
      final task = KidsTask(
        id: 'task1',
        parentId: 'parent1',
        title: 'Task',
        notes: '',
        category: TaskCategory.household,
        priority: TaskPriority.normal,
        dueDate: now,
        isCompleted: false,
        completedAt: null,
        xpReward: 10,
        syncState: 'clean',
        webdavEtag: 'etag',
        createdAt: now,
        updatedAt: now,
      );

      await repository.upsertTask(task);
      await repository.delete('task1');

      final deleted = await repository.watchOne('task1').first;
      expect(deleted!.syncState, 'deleted');
    });

    test('hardDelete removes task from database', () async {
      final now = DateTime.now().toUtc();
      final task = KidsTask(
        id: 'task1',
        parentId: 'parent1',
        title: 'Task',
        notes: '',
        category: TaskCategory.household,
        priority: TaskPriority.normal,
        dueDate: now,
        isCompleted: false,
        completedAt: null,
        xpReward: 10,
        syncState: 'deleted',
        webdavEtag: 'etag',
        createdAt: now,
        updatedAt: now,
      );

      await repository.upsertTask(task);
      await repository.hardDelete('task1');

      final removed = await repository.watchOne('task1').first;
      expect(removed, isNull);
    });

    test('getDirtyRows returns only dirty tasks', () async {
      final now = DateTime.now().toUtc();
      final dirtyTask = KidsTask(
        id: '1',
        parentId: 'parent1',
        title: 'Dirty',
        notes: '',
        category: TaskCategory.household,
        priority: TaskPriority.normal,
        dueDate: now,
        isCompleted: false,
        completedAt: null,
        xpReward: 10,
        syncState: 'dirty',
        webdavEtag: 'etag1',
        createdAt: now,
        updatedAt: now,
      );

      final cleanTask = KidsTask(
        id: '2',
        parentId: 'parent1',
        title: 'Clean',
        notes: '',
        category: TaskCategory.school,
        priority: TaskPriority.normal,
        dueDate: now,
        isCompleted: false,
        completedAt: null,
        xpReward: 10,
        syncState: 'clean',
        webdavEtag: 'etag2',
        createdAt: now,
        updatedAt: now,
      );

      await repository.upsertTask(dirtyTask);
      await repository.upsertTask(cleanTask);

      final dirty = await repository.getDirtyRows();
      expect(dirty.length, 1);
      expect(dirty[0].id, '1');
    });

    test('getDeletedRows returns only deleted tasks', () async {
      final now = DateTime.now().toUtc();
      final deletedTask = KidsTask(
        id: '1',
        parentId: 'parent1',
        title: 'Deleted',
        notes: '',
        category: TaskCategory.household,
        priority: TaskPriority.normal,
        dueDate: now,
        isCompleted: false,
        completedAt: null,
        xpReward: 10,
        syncState: 'deleted',
        webdavEtag: 'etag1',
        createdAt: now,
        updatedAt: now,
      );

      final cleanTask = KidsTask(
        id: '2',
        parentId: 'parent1',
        title: 'Clean',
        notes: '',
        category: TaskCategory.school,
        priority: TaskPriority.normal,
        dueDate: now,
        isCompleted: false,
        completedAt: null,
        xpReward: 10,
        syncState: 'clean',
        webdavEtag: 'etag2',
        createdAt: now,
        updatedAt: now,
      );

      await repository.upsertTask(deletedTask);
      await repository.upsertTask(cleanTask);

      final deleted = await repository.getDeletedRows();
      expect(deleted.length, 1);
      expect(deleted[0].id, '1');
    });
  });
}
