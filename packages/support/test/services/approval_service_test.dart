import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_core/kinetic_core.dart';
import 'package:kinetic_support/kinetic_support.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Task _pendingTask({
  String id = 'task:001',
  String assignedTo = 'child-001',
  int xp = 50,
}) {
  final now = DateTime.now().toUtc();
  return Task(
    id: id,
    familyPlanId: 'plan:main',
    createdById: 'parent-001',
    assignedToId: assignedTo,
    title: 'Clean room',
    category: TaskCategory.mission,
    status: TaskStatus.pendingApproval,
    xpReward: xp,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late InMemoryDocumentStore store;
  late ApprovalService sut;

  setUp(() {
    store = InMemoryDocumentStore();
    sut = ApprovalService(store: store);
  });

  // -------------------------------------------------------------------------
  // approveTask
  // -------------------------------------------------------------------------

  group('ApprovalService.approveTask', () {
    test('marks task as completed', () {
      final task = _pendingTask();
      store.upsert({'_id': task.id, ...task.toJson()});

      final result = sut.approveTask(task: task, approverId: 'parent-001');

      expect(result.completedTask.status, equals(TaskStatus.completed));
    });

    test('persists completed task to store', () {
      final task = _pendingTask();
      store.upsert({'_id': task.id, ...task.toJson()});

      sut.approveTask(task: task, approverId: 'parent-001');

      final stored = store.all.firstWhere((d) => d['_id'] == task.id);
      expect(stored['status'], equals('completed'));
    });

    test('creates XpLedger with correct balance when none exists', () {
      final task = _pendingTask(xp: 75);
      store.upsert({'_id': task.id, ...task.toJson()});

      final result = sut.approveTask(task: task, approverId: 'parent-001');

      expect(result.updatedLedger.balance, equals(75));
      expect(result.updatedLedger.memberId, equals('child-001'));
      expect(result.updatedLedger.events, hasLength(1));
    });

    test('adds to existing XpLedger balance', () {
      final task = _pendingTask(xp: 30);
      store.upsert({'_id': task.id, ...task.toJson()});

      // Pre-seed ledger with 100 XP.
      final existing = XpLedger.empty('child-001').applyEvent(
        XpEvent(taskId: 'task:prev', delta: 100, at: DateTime.now().toUtc()),
      );
      store.upsert(existing.toJson());

      final result = sut.approveTask(task: task, approverId: 'parent-001');

      expect(result.updatedLedger.balance, equals(130));
      expect(result.updatedLedger.events, hasLength(2));
    });

    test('throws ArgumentError when task status is not pendingApproval', () {
      final now = DateTime.now().toUtc();
      final notPending = Task(
        id: 'task:x',
        familyPlanId: 'plan:main',
        createdById: 'parent-001',
        assignedToId: 'child-001',
        title: 'Homework',
        category: TaskCategory.mission,
        status: TaskStatus.inProgress, // wrong status
        xpReward: 50,
        createdAt: now,
        updatedAt: now,
      );

      expect(
        () => sut.approveTask(task: notPending, approverId: 'parent-001'),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError when task has no assignedToId', () {
      final now = DateTime.now().toUtc();
      final unassigned = Task(
        id: 'task:y',
        familyPlanId: 'plan:main',
        createdById: 'parent-001',
        title: 'Unassigned task',
        category: TaskCategory.mission,
        status: TaskStatus.pendingApproval,
        xpReward: 50,
        createdAt: now,
        updatedAt: now,
      );

      expect(
        () => sut.approveTask(task: unassigned, approverId: 'parent-001'),
        throwsArgumentError,
      );
    });
  });

  // -------------------------------------------------------------------------
  // rejectTask
  // -------------------------------------------------------------------------

  group('ApprovalService.rejectTask', () {
    test('sets task status back to inProgress', () {
      final task = _pendingTask();
      final rejected = sut.rejectTask(task: task, approverId: 'parent-001');
      expect(rejected.status, equals(TaskStatus.inProgress));
    });

    test('stores rejection reason in description', () {
      final task = _pendingTask();
      final rejected = sut.rejectTask(
        task: task,
        approverId: 'parent-001',
        reason: 'Photo is blurry',
      );
      expect(rejected.description, equals('Photo is blurry'));
    });

    test('persists rejected task to store', () {
      final task = _pendingTask();
      store.upsert({'_id': task.id, ...task.toJson()});

      sut.rejectTask(task: task, approverId: 'parent-001');

      final stored = store.all.firstWhere((d) => d['_id'] == task.id);
      expect(stored['status'], equals('inProgress'));
    });

    test('throws ArgumentError when task status is not pendingApproval', () {
      final now = DateTime.now().toUtc();
      final pending = Task(
        id: 'task:z',
        familyPlanId: 'plan:main',
        createdById: 'parent-001',
        assignedToId: 'child-001',
        title: 'Task',
        category: TaskCategory.mission,
        status: TaskStatus.pending, // wrong status
        xpReward: 0,
        createdAt: now,
        updatedAt: now,
      );

      expect(
        () => sut.rejectTask(task: pending, approverId: 'parent-001'),
        throwsArgumentError,
      );
    });
  });

  // -------------------------------------------------------------------------
  // Queries
  // -------------------------------------------------------------------------

  group('ApprovalService queries', () {
    test('pendingTasks returns only pendingApproval tasks', () {
      final pending = _pendingTask(id: 'task:p1');
      final now = DateTime.now().toUtc();
      final completed = Task(
        id: 'task:c1',
        familyPlanId: 'plan:main',
        createdById: 'parent-001',
        title: 'Done',
        category: TaskCategory.mission,
        status: TaskStatus.completed,
        xpReward: 0,
        createdAt: now,
        updatedAt: now,
      );

      store.upsert({'_id': pending.id, ...pending.toJson()});
      store.upsert({'_id': completed.id, ...completed.toJson()});

      expect(sut.pendingTasks, hasLength(1));
      expect(sut.pendingTasks.first.id, equals('task:p1'));
    });

    test('ledgerFor returns empty ledger when none exists', () {
      final ledger = sut.ledgerFor('nobody');
      expect(ledger.balance, equals(0));
      expect(ledger.memberId, equals('nobody'));
    });
  });
}
