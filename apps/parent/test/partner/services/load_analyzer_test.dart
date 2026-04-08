import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parent/db/app_database.dart';
import 'package:parent/partner/services/load_analyzer.dart';
import '../../helpers/test_database.dart';

// ---------------------------------------------------------------------------
// Helper — inserts a minimal PersonalTaskRow directly into the DB.
// ---------------------------------------------------------------------------
Future<void> _insertTask(
  AppDatabase db, {
  required String id,
  required String title,
  bool isCompleted = false,
  DateTime? dueDate,
  String category = 'other',
}) async {
  final now = DateTime.now().toUtc();
  await db
      .into(db.personalTasks)
      .insert(
        PersonalTasksCompanion.insert(
          id: id,
          title: title,
          isCompleted: Value(isCompleted),
          dueDate: Value(dueDate),
          category: Value(category),
          createdAt: now,
          updatedAt: now,
        ),
      );
}

void main() {
  late AppDatabase db;
  late LoadAnalyzer analyzer;

  setUp(() {
    db = createTestDatabase();
    analyzer = LoadAnalyzer(db: db);
  });

  tearDown(() => db.close());

  // --------------------------------------------------------------------------
  // getMyLoad
  // --------------------------------------------------------------------------
  group('LoadAnalyzer.getMyLoad', () {
    test('returns zero counts for empty database', () async {
      final metrics = await analyzer.getMyLoad('parent-1', 'Mama');
      expect(metrics.parentId, equals('parent-1'));
      expect(metrics.parentName, equals('Mama'));
      expect(metrics.taskCount, equals(0));
      expect(metrics.urgentCount, equals(0));
      expect(metrics.openTasksCount, equals(0));
      expect(metrics.pastDueTasksCount, equals(0));
      expect(metrics.totalCategoriesCount, equals(0));
      expect(metrics.notesCount, equals(0));
      expect(metrics.childrenTasksSent, equals(0));
      expect(metrics.childrenTasksCompleted, equals(0));
    });

    test('counts only non-completed tasks', () async {
      await _insertTask(db, id: 't1', title: 'Open taak');
      await _insertTask(db, id: 't2', title: 'Klaar', isCompleted: true);

      final metrics = await analyzer.getMyLoad('p', 'P');
      expect(metrics.taskCount, equals(1));
    });

    test('counts all non-completed tasks across categories', () async {
      await _insertTask(
        db,
        id: 't1',
        title: 'Dish washing',
        category: 'household',
      );
      await _insertTask(
        db,
        id: 't2',
        title: 'Doctor visit',
        category: 'health',
      );
      await _insertTask(db, id: 't3', title: 'Belasting', category: 'finance');
      await _insertTask(db, id: 't4', title: 'Done', isCompleted: true);

      final metrics = await analyzer.getMyLoad('p', 'P');
      expect(metrics.taskCount, equals(3));
    });

    test('counts urgent tasks (due within 7 days inclusive)', () async {
      final now = DateTime.now().toUtc();
      // Due in 3 days → urgent
      await _insertTask(
        db,
        id: 't1',
        title: 'Urgent',
        dueDate: now.add(const Duration(days: 3)),
      );
      // Due in 7 days exactly → urgent
      await _insertTask(
        db,
        id: 't2',
        title: 'Boundary',
        dueDate: now.add(const Duration(days: 7)),
      );

      final metrics = await analyzer.getMyLoad('p', 'P');
      expect(metrics.urgentCount, equals(2));
    });

    test('does NOT count tasks due in 8+ days as urgent', () async {
      final now = DateTime.now().toUtc();
      // Use 9 days to avoid inDays truncation from slight time delta between
      // test setup and getMyLoad's internal DateTime.now().
      await _insertTask(
        db,
        id: 't1',
        title: 'Later taak',
        dueDate: now.add(const Duration(days: 9)),
      );

      final metrics = await analyzer.getMyLoad('p', 'P');
      expect(metrics.urgentCount, equals(0));
    });

    test('does NOT count overdue tasks as urgent (diff < 0)', () async {
      final past = DateTime.now().toUtc().subtract(const Duration(days: 1));
      await _insertTask(db, id: 't1', title: 'Verouderd', dueDate: past);

      final metrics = await analyzer.getMyLoad('p', 'P');
      // taskCount = 1, but urgentCount = 0 (diff < 0)
      expect(metrics.taskCount, equals(1));
      expect(metrics.urgentCount, equals(0));
    });

    test('does NOT count tasks without due date as urgent', () async {
      await _insertTask(db, id: 't1', title: 'Geen datum');

      final metrics = await analyzer.getMyLoad('p', 'P');
      expect(metrics.urgentCount, equals(0));
    });

    test('groups tasks by category', () async {
      await _insertTask(
        db,
        id: 't1',
        title: 'Huishouden 1',
        category: 'household',
      );
      await _insertTask(
        db,
        id: 't2',
        title: 'Huishouden 2',
        category: 'household',
      );
      await _insertTask(db, id: 't3', title: 'Gezondheid', category: 'health');

      final metrics = await analyzer.getMyLoad('p', 'P');
      expect(metrics.totalCategoriesCount, equals(2));
    });

    test('excludes completed tasks from category counts', () async {
      await _insertTask(db, id: 't1', title: 'Open', category: 'household');
      await _insertTask(
        db,
        id: 't2',
        title: 'Klaar',
        category: 'household',
        isCompleted: true,
      );

      final metrics = await analyzer.getMyLoad('p', 'P');
      expect(metrics.totalCategoriesCount, equals(1));
    });
  });

  // --------------------------------------------------------------------------
  // hasCapacityForMoreProposals
  // --------------------------------------------------------------------------
  group('LoadAnalyzer.hasCapacityForMoreProposals', () {
    test('returns true when task count is below 50% of max', () async {
      // 2 tasks, max=10 → 2 < 5 → true
      await _insertTask(db, id: 't1', title: 'T1');
      await _insertTask(db, id: 't2', title: 'T2');

      expect(await analyzer.hasCapacityForMoreProposals(10), isTrue);
    });

    test('returns false when task count equals 50% of max', () async {
      // 5 tasks, max=10 → 5 < 5 is false
      for (var i = 0; i < 5; i++) {
        await _insertTask(db, id: 't$i', title: 'Taak $i');
      }
      expect(await analyzer.hasCapacityForMoreProposals(10), isFalse);
    });

    test('returns false when task count exceeds 50% of max', () async {
      for (var i = 0; i < 8; i++) {
        await _insertTask(db, id: 't$i', title: 'Taak $i');
      }
      expect(await analyzer.hasCapacityForMoreProposals(10), isFalse);
    });

    test('ignores completed tasks when checking capacity', () async {
      for (var i = 0; i < 4; i++) {
        await _insertTask(db, id: 'open$i', title: 'Open $i');
      }
      for (var i = 0; i < 10; i++) {
        await _insertTask(
          db,
          id: 'done$i',
          title: 'Done $i',
          isCompleted: true,
        );
      }
      // 4 open tasks, max=10 → 4 < 5 → true
      expect(await analyzer.hasCapacityForMoreProposals(10), isTrue);
    });
  });
}
