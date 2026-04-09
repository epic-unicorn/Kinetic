import 'package:flutter_test/flutter_test.dart';
import 'package:parent/todo/models/personal_task.dart';
import 'package:parent/todo/services/todo_repository.dart';
import 'package:parent/notifications/notification_service.dart';
import '../../helpers/test_database.dart';

// ---------------------------------------------------------------------------
// Fake notification service for testing — records scheduled/cancelled ids
// and optionally throws to test error handling.
// ---------------------------------------------------------------------------

class _FakeNotificationService implements NotificationService {
  final List<int> scheduled = [];
  final List<int> cancelled = [];
  bool shouldThrow = false;

  @override
  Future<void> init() async {}

  @override
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    if (shouldThrow) throw Exception('notification permission denied');
    scheduled.add(id);
  }

  @override
  Future<void> cancelReminder(int id) async {
    cancelled.add(id);
  }

  @override
  Future<void> sendLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {}

  @override
  Future<DateTime> rescheduleReminder({
    required int id,
    required String actionId,
    required String title,
    required String body,
  }) async => DateTime.now().add(const Duration(minutes: 5));
}

void main() {
  // --------------------------------------------------------------------------
  // PersonalTask.copyWith — clearNotes fix
  // --------------------------------------------------------------------------
  group('PersonalTask.copyWith', () {
    late PersonalTask task;
    setUp(() {
      task = PersonalTask.create(
        title: 'Test taak',
        notes: 'Bestaande notitie',
      );
    });

    test('preserves existing notes when notes param is null', () {
      final updated = task.copyWith(title: 'Nieuwe naam');
      expect(updated.notes, equals('Bestaande notitie'));
    });

    test('updates notes when new value is provided', () {
      final updated = task.copyWith(notes: 'Nieuwe notitie');
      expect(updated.notes, equals('Nieuwe notitie'));
    });

    test('clearNotes=true removes existing notes', () {
      final updated = task.copyWith(clearNotes: true);
      expect(updated.notes, isNull);
    });

    test('clearNotes=true takes precedence over notes value', () {
      // Should clear even if a non-null notes value was accidentally passed.
      final updated = task.copyWith(notes: 'ignored', clearNotes: true);
      expect(updated.notes, isNull);
    });

    test('notes=null without clearNotes preserves old notes', () {
      // This verifies the pre-fix bug is gone.
      final updated = task.copyWith(notes: null, clearNotes: false);
      expect(updated.notes, equals('Bestaande notitie'));
    });
  });

  // --------------------------------------------------------------------------
  // TodoRepository — reminder scheduling
  // --------------------------------------------------------------------------
  group('TodoRepository reminder scheduling', () {
    late _FakeNotificationService notif;
    late TodoRepository repo;

    setUp(() async {
      notif = _FakeNotificationService();
      final db = createTestDatabase();
      repo = TodoRepository(db: db, notifications: notif);
    });

    test('schedules reminder for timed (non-all-day) task', () async {
      final future = DateTime.now().add(const Duration(hours: 2));
      await repo.createTask(
        title: 'Doktersafspraak',
        dueDate: future.toUtc(),
        isAllDay: false,
      );
      expect(notif.scheduled, hasLength(1));
    });

    test('does NOT schedule reminder for all-day task', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      await repo.createTask(
        title: 'Boodschappen doen',
        dueDate: DateTime(tomorrow.year, tomorrow.month, tomorrow.day).toUtc(),
        isAllDay: true,
      );
      expect(notif.scheduled, isEmpty);
    });

    test('does NOT schedule reminder when due date is in the past', () async {
      final past = DateTime.now().subtract(const Duration(hours: 1));
      await repo.createTask(
        title: 'Gemiste taak',
        dueDate: past.toUtc(),
        isAllDay: false,
      );
      expect(notif.scheduled, isEmpty);
    });

    test('does NOT schedule reminder for completed task', () async {
      final future = DateTime.now().add(const Duration(hours: 2));
      final task = await repo.createTask(
        title: 'Al klaar',
        dueDate: future.toUtc(),
        isAllDay: false,
      );
      notif.scheduled.clear();

      // Complete the task and then edit it via updateTask.
      final completed = task.copyWith(
        isCompleted: true,
        completedAt: DateTime.now().toUtc(),
      );
      await repo.updateTask(completed);
      // Should not re-schedule a reminder for a completed task.
      expect(notif.scheduled, isEmpty);
    });

    test('cancels reminder when task is completed', () async {
      final future = DateTime.now().add(const Duration(hours: 2));
      final task = await repo.createTask(
        title: 'Klaar maken',
        dueDate: future.toUtc(),
        isAllDay: false,
      );
      expect(notif.scheduled, hasLength(1));
      notif.scheduled.clear();

      await repo.completeTask(task.id);
      expect(notif.cancelled, hasLength(1));
    });

    test('notification errors do NOT prevent task from being saved', () async {
      notif.shouldThrow = true;
      final future = DateTime.now().add(const Duration(hours: 2));
      // Should not throw even though notification scheduling fails.
      final task = await repo.createTask(
        title: 'Taak met slechte notificatie',
        dueDate: future.toUtc(),
        isAllDay: false,
      );
      // Task should exist in DB.
      final raw = await repo.debugGetRawTask(task.id);
      expect(raw?.title, equals('Taak met slechte notificatie'));
    });
  });

  // --------------------------------------------------------------------------
  // TodoRepository — updateTask marks syncState = dirty
  // --------------------------------------------------------------------------
  group('TodoRepository syncState', () {
    late TodoRepository repo;

    setUp(() {
      final db = createTestDatabase();
      repo = TodoRepository(db: db);
    });

    test('new task starts with syncState = dirty', () async {
      final task = await repo.createTask(title: 'Nieuwe taak');
      final rows = await repo.debugGetRawTask(task.id);
      expect(rows?.syncState, equals('dirty'));
    });

    test(
      'updateTask marks task as dirty again after sync would have cleaned it',
      () async {
        final task = await repo.createTask(title: 'Te bewerken taak');
        // Simulate task being synced by manually setting clean.
        await repo.debugMarkClean(task.id);
        final afterSync = await repo.debugGetRawTask(task.id);
        expect(afterSync?.syncState, equals('clean'));

        // Now edit the task — it should go back to dirty.
        await repo.updateTask(task.copyWith(title: 'Bijgewerkte naam'));
        final afterEdit = await repo.debugGetRawTask(task.id);
        expect(afterEdit?.syncState, equals('dirty'));
      },
    );
  });
}
