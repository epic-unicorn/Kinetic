import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';
import 'package:kids/db/app_database.dart';
import 'package:kids/sync/sync_orchestrator.dart';
import 'package:kids/task/models/kids_task.dart';
import 'package:kids/task/services/kids_task_repository.dart';

import '../helpers/test_database.dart';

void main() {
  group('KidsSyncOrchestrator', () {
    late AppDatabase db;
    late KidsTaskRepository repository;
    late KidsSyncOrchestrator orchestrator;

    setUp(() {
      db = createTestDatabase();
      repository = KidsTaskRepository(db: db);

      final syncConfig = SyncConfig(
        serverUrl: 'https://example.com/dav',
        username: 'testuser',
        password: 'testpass',
        parentId: '',
        personalKeyBytes: Uint8List(32),
      );

      orchestrator = KidsSyncOrchestrator(
        db: db,
        repo: repository,
        config: syncConfig,
      );
    });

    tearDown(() async {
      await db.close();
    });

    // ── iCal → KidsTask conversion ──────────────────────────────────────────

    group('iCal to KidsTask conversion', () {
      test('maps basic fields correctly', () {
        final now = DateTime.now().toUtc();
        final ical = ICalTask(
          uid: 'task-abc',
          summary: 'Kamer opruimen',
          description:
              'Speelgoed opruimen;xKineticParentId:parent-1;xKineticCategory:household;xKineticXpReward:15',
          status: ICalTaskStatus.needsAction,
          priority: 5,
          createdAt: now,
          updatedAt: now,
          dueAt: now.add(const Duration(days: 1)),
          remindAt: null,
          rrule: null,
        );

        final task = orchestrator.iCalToKidsTask(ical);

        expect(task.id, 'task-abc');
        expect(task.title, 'Kamer opruimen');
        expect(task.parentId, 'parent-1');
        expect(task.notes, 'Speelgoed opruimen');
        expect(task.category, TaskCategory.household);
        expect(task.xpReward, 15);
        expect(task.isCompleted, false);
      });

      test('maps completed status correctly', () {
        final now = DateTime.now().toUtc();
        final ical = ICalTask(
          uid: 'task-done',
          summary: 'Done Task',
          description:
              ';xKineticParentId:p1;xKineticCategory:other;xKineticXpReward:10',
          status: ICalTaskStatus.completed,
          priority: 5,
          createdAt: now,
          updatedAt: now,
          dueAt: null,
          remindAt: null,
          rrule: null,
        );

        final task = orchestrator.iCalToKidsTask(ical);
        expect(task.isCompleted, true);
        expect(task.completedAt, isNotNull);
      });

      test('falls back to TaskCategory.other for unknown category', () {
        final now = DateTime.now().toUtc();
        final ical = ICalTask(
          uid: 'task-1',
          summary: 'Task',
          description:
              ';xKineticParentId:p1;xKineticCategory:nonexistent;xKineticXpReward:10',
          status: ICalTaskStatus.needsAction,
          priority: 5,
          createdAt: now,
          updatedAt: now,
          dueAt: null,
          remindAt: null,
          rrule: null,
        );

        final task = orchestrator.iCalToKidsTask(ical);
        expect(task.category, TaskCategory.other);
      });

      test('falls back to xpReward=10 when missing', () {
        final now = DateTime.now().toUtc();
        final ical = ICalTask(
          uid: 'task-1',
          summary: 'Task',
          description: ';xKineticParentId:p1;xKineticCategory:other',
          status: ICalTaskStatus.needsAction,
          priority: 5,
          createdAt: now,
          updatedAt: now,
          dueAt: null,
          remindAt: null,
          rrule: null,
        );

        final task = orchestrator.iCalToKidsTask(ical);
        expect(task.xpReward, 10);
      });
    });

    // ── Priority mapping ─────────────────────────────────────────────────────

    group('iCal priority mapping', () {
      ICalTask makeIcal(int priority) {
        final now = DateTime.now().toUtc();
        return ICalTask(
          uid: 'p',
          summary: 'T',
          description:
              ';xKineticParentId:x;xKineticCategory:other;xKineticXpReward:10',
          status: ICalTaskStatus.needsAction,
          priority: priority,
          createdAt: now,
          updatedAt: now,
          dueAt: null,
          remindAt: null,
          rrule: null,
        );
      }

      test('iCal 1 -> urgent', () {
        expect(
          orchestrator.iCalToKidsTask(makeIcal(1)).priority,
          TaskPriority.urgent,
        );
      });

      test('iCal 5 -> normal', () {
        expect(
          orchestrator.iCalToKidsTask(makeIcal(5)).priority,
          TaskPriority.normal,
        );
      });

      test('iCal 9 -> low', () {
        expect(
          orchestrator.iCalToKidsTask(makeIcal(9)).priority,
          TaskPriority.low,
        );
      });

      test('unknown iCal priority -> normal', () {
        expect(
          orchestrator.iCalToKidsTask(makeIcal(3)).priority,
          TaskPriority.normal,
        );
      });
    });

    // ── KidsTaskRow → iCal conversion ────────────────────────────────────────

    group('KidsTaskRow to iCal conversion', () {
      test('maps id and title', () async {
        final now = DateTime.now().toUtc();
        await repository.upsertTask(
          KidsTask(
            id: 'row-1',
            parentId: 'parent-1',
            title: 'Test task',
            notes: 'Some notes',
            category: TaskCategory.school,
            priority: TaskPriority.high,
            dueDate: now,
            isCompleted: false,
            completedAt: null,
            xpReward: 20,
            syncState: 'dirty',
            webdavEtag: null,
            createdAt: now,
            updatedAt: now,
          ),
        );
        final rows = await repository.getAllRows();

        final ical = orchestrator.taskRowToICal(rows.first);
        expect(ical.uid, 'row-1');
        expect(ical.summary, 'Test task');
      });

      test('encodes parentId and category in description', () async {
        final now = DateTime.now().toUtc();
        await repository.upsertTask(
          KidsTask(
            id: 'row-2',
            parentId: 'parent-42',
            title: 'Task',
            notes: null,
            category: TaskCategory.health,
            priority: TaskPriority.normal,
            dueDate: null,
            isCompleted: false,
            completedAt: null,
            xpReward: 10,
            syncState: 'dirty',
            webdavEtag: null,
            createdAt: now,
            updatedAt: now,
          ),
        );
        final rows = await repository.getAllRows();

        final ical = orchestrator.taskRowToICal(rows.first);
        expect(ical.description, contains('xKineticParentId:parent-42'));
        expect(ical.description, contains('xKineticCategory:health'));
        expect(ical.description, contains('xKineticXpReward:10'));
      });

      test('completed task -> ICalTaskStatus.completed', () async {
        final now = DateTime.now().toUtc();
        await repository.upsertTask(
          KidsTask(
            id: 'row-3',
            parentId: 'p',
            title: 'Done',
            notes: null,
            category: TaskCategory.other,
            priority: TaskPriority.normal,
            dueDate: null,
            isCompleted: true,
            completedAt: now,
            xpReward: 10,
            syncState: 'dirty',
            webdavEtag: null,
            createdAt: now,
            updatedAt: now,
          ),
        );
        final rows = await repository.getAllRows();

        final ical = orchestrator.taskRowToICal(rows.first);
        expect(ical.status, ICalTaskStatus.completed);
      });
    });

    // ── LWW merge logic ──────────────────────────────────────────────────────

    group('Last-Write-Wins merge', () {
      test('remote newer: timestamp comparison is correct', () async {
        final older = DateTime(2024, 1, 1).toUtc();
        final newer = DateTime(2025, 1, 1).toUtc();

        await repository.upsertTask(
          KidsTask(
            id: 'task-lww',
            parentId: 'p1',
            title: 'Old Title',
            notes: null,
            category: TaskCategory.household,
            priority: TaskPriority.normal,
            dueDate: null,
            isCompleted: false,
            completedAt: null,
            xpReward: 10,
            syncState: 'clean',
            webdavEtag: 'etag1',
            createdAt: older,
            updatedAt: older,
          ),
        );

        final remoteNewer = KidsTask(
          id: 'task-lww',
          parentId: 'p1',
          title: 'New Title',
          notes: null,
          category: TaskCategory.school,
          priority: TaskPriority.high,
          dueDate: null,
          isCompleted: false,
          completedAt: null,
          xpReward: 20,
          syncState: 'clean',
          webdavEtag: 'etag2',
          createdAt: older,
          updatedAt: newer,
        );

        final local = await db.select(db.kidsTasks).getSingleOrNull();
        expect(remoteNewer.updatedAt.isAfter(local!.updatedAt), true);

        // Remote is newer → upsert wins
        await repository.upsertTask(remoteNewer);
        final after = await db.select(db.kidsTasks).getSingleOrNull();
        expect(after!.title, 'New Title');
        expect(after.xpReward, 20);
      });

      test('local newer: local is not overwritten', () async {
        final older = DateTime(2024, 1, 1).toUtc();
        final newer = DateTime(2025, 1, 1).toUtc();

        await repository.upsertTask(
          KidsTask(
            id: 'task-local-wins',
            parentId: 'p1',
            title: 'Local Title',
            notes: null,
            category: TaskCategory.household,
            priority: TaskPriority.normal,
            dueDate: null,
            isCompleted: true,
            completedAt: newer,
            xpReward: 10,
            syncState: 'dirty',
            webdavEtag: 'etag1',
            createdAt: older,
            updatedAt: newer,
          ),
        );

        final remoteOlder = KidsTask(
          id: 'task-local-wins',
          parentId: 'p1',
          title: 'Remote Title',
          notes: null,
          category: TaskCategory.household,
          priority: TaskPriority.normal,
          dueDate: null,
          isCompleted: false,
          completedAt: null,
          xpReward: 10,
          syncState: 'clean',
          webdavEtag: 'etag0',
          createdAt: older,
          updatedAt: older,
        );

        final local = await db.select(db.kidsTasks).getSingleOrNull();
        // Remote is not newer — LWW skips upsert
        expect(remoteOlder.updatedAt.isAfter(local!.updatedAt), false);

        // Simulate LWW: only upsert when remote is newer
        if (remoteOlder.updatedAt.isAfter(local.updatedAt)) {
          await repository.upsertTask(remoteOlder);
        }

        final after = await db.select(db.kidsTasks).getSingleOrNull();
        expect(after!.title, 'Local Title');
        expect(after.isCompleted, true);
      });
    });

    // ── Soft-delete tombstones ───────────────────────────────────────────────

    group('Soft-delete tombstones', () {
      test('delete() sets syncState=deleted, keeps row', () async {
        final now = DateTime.now().toUtc();
        await repository.upsertTask(
          KidsTask(
            id: 'task-del',
            parentId: 'p',
            title: 'To Delete',
            notes: null,
            category: TaskCategory.other,
            priority: TaskPriority.normal,
            dueDate: null,
            isCompleted: false,
            completedAt: null,
            xpReward: 10,
            syncState: 'clean',
            webdavEtag: null,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await repository.delete('task-del');

        final row = await db.select(db.kidsTasks).getSingleOrNull();
        expect(row, isNotNull);
        expect(row!.syncState, 'deleted');
        expect(row.id, 'task-del');
      });

      test('getDeletedRows() returns only tombstones', () async {
        final now = DateTime.now().toUtc();
        await repository.upsertTask(
          KidsTask(
            id: 'keep',
            parentId: 'p',
            title: 'Keep',
            notes: null,
            category: TaskCategory.other,
            priority: TaskPriority.normal,
            dueDate: null,
            isCompleted: false,
            completedAt: null,
            xpReward: 10,
            syncState: 'clean',
            webdavEtag: null,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await repository.upsertTask(
          KidsTask(
            id: 'delete-me',
            parentId: 'p',
            title: 'Delete',
            notes: null,
            category: TaskCategory.other,
            priority: TaskPriority.normal,
            dueDate: null,
            isCompleted: false,
            completedAt: null,
            xpReward: 10,
            syncState: 'clean',
            webdavEtag: null,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await repository.delete('delete-me');

        final deleted = await repository.getDeletedRows();
        expect(deleted.length, 1);
        expect(deleted.first.id, 'delete-me');
      });

      test('hardDelete() removes row from database entirely', () async {
        final now = DateTime.now().toUtc();
        await repository.upsertTask(
          KidsTask(
            id: 'hard-del',
            parentId: 'p',
            title: 'Hard Delete',
            notes: null,
            category: TaskCategory.other,
            priority: TaskPriority.normal,
            dueDate: null,
            isCompleted: false,
            completedAt: null,
            xpReward: 10,
            syncState: 'deleted',
            webdavEtag: null,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await repository.hardDelete('hard-del');

        final rows = await db.select(db.kidsTasks).get();
        expect(rows, isEmpty);
      });
    });

    // ── Dirty rows for push ──────────────────────────────────────────────────

    group('Dirty rows for sync push', () {
      test('markComplete() sets syncState=dirty', () async {
        final now = DateTime.now().toUtc();
        await repository.upsertTask(
          KidsTask(
            id: 'task-dirty',
            parentId: 'p',
            title: 'Task',
            notes: null,
            category: TaskCategory.other,
            priority: TaskPriority.normal,
            dueDate: null,
            isCompleted: false,
            completedAt: null,
            xpReward: 10,
            syncState: 'clean',
            webdavEtag: null,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await repository.markComplete('task-dirty');

        final dirty = await repository.getDirtyRows();
        expect(dirty.length, 1);
        expect(dirty.first.id, 'task-dirty');
        expect(dirty.first.isCompleted, true);
      });

      test('markSynced() clears dirty state and updates etag', () async {
        final now = DateTime.now().toUtc();
        await repository.upsertTask(
          KidsTask(
            id: 'task-sync',
            parentId: 'p',
            title: 'Task',
            notes: null,
            category: TaskCategory.other,
            priority: TaskPriority.normal,
            dueDate: null,
            isCompleted: true,
            completedAt: now,
            xpReward: 10,
            syncState: 'dirty',
            webdavEtag: null,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await repository.markSynced('task-sync', 'etag-new');

        final row = await db.select(db.kidsTasks).getSingleOrNull();
        expect(row!.syncState, 'clean');
        expect(row.webdavEtag, 'etag-new');
      });
    });
  });
}
