import 'package:flutter_test/flutter_test.dart';
import 'package:parent/notifications/notification_service.dart';
import 'package:parent/todo/models/personal_note.dart';
import 'package:parent/todo/services/note_repository.dart';
import '../../helpers/test_database.dart';

class _FakeNotifService implements NotificationService {
  final List<int> scheduled = [];
  final List<int> cancelled = [];
  bool shouldThrow = false;

  @override
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    if (shouldThrow) throw Exception('notification failed');
    scheduled.add(id);
  }

  @override
  Future<void> cancelReminder(int id) async => cancelled.add(id);

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
  }) async =>
      DateTime.now().add(const Duration(minutes: 5));
}

void main() {
  // --------------------------------------------------------------------------
  // PersonalNote.copyWith — clearRemindAt
  // --------------------------------------------------------------------------
  group('PersonalNote.copyWith', () {
    late PersonalNote note;
    final remindAt = DateTime(2030, 6, 1, 9, 0);

    setUp(() {
      note = PersonalNote.create(title: 'Test notitie', remindAt: remindAt);
    });

    test('preserves remindAt when not explicitly cleared', () {
      final updated = note.copyWith(title: 'Nieuwe naam');
      expect(updated.remindAt, equals(remindAt));
    });

    test('clearRemindAt=true removes the reminder', () {
      final updated = note.copyWith(clearRemindAt: true);
      expect(updated.remindAt, isNull);
    });

    test('passing remindAt=null without clearRemindAt preserves old value', () {
      final updated = note.copyWith(remindAt: null, clearRemindAt: false);
      expect(updated.remindAt, equals(remindAt));
    });
  });

  // --------------------------------------------------------------------------
  // NoteRepository — reminder scheduling
  // --------------------------------------------------------------------------
  group('NoteRepository reminder scheduling', () {
    late _FakeNotifService notif;
    late NoteRepository repo;

    setUp(() {
      notif = _FakeNotifService();
      final db = createTestDatabase();
      repo = NoteRepository(db: db, notifications: notif);
    });

    test('schedules reminder on insert when remindAt is in the future', () async {
      final future = DateTime.now().add(const Duration(hours: 2));
      await repo.insert(title: 'Herinnering', remindAt: future);
      expect(notif.scheduled, hasLength(1));
    });

    test('does NOT schedule when remindAt is in the past', () async {
      final past = DateTime.now().subtract(const Duration(hours: 1));
      await repo.insert(title: 'Verlopen herinnering', remindAt: past);
      expect(notif.scheduled, isEmpty);
    });

    test('cancels old reminder and schedules new one on update', () async {
      final future = DateTime.now().add(const Duration(hours: 2));
      final note = await repo.insert(title: 'Notitie', remindAt: future);
      expect(notif.scheduled, hasLength(1));

      final laterFuture = DateTime.now().add(const Duration(hours: 4));
      await repo.update(note.copyWith(remindAt: laterFuture));
      expect(notif.cancelled, hasLength(1));
      expect(notif.scheduled, hasLength(2));
    });

    test('clears reminder when update passes clearRemindAt=true', () async {
      final future = DateTime.now().add(const Duration(hours: 2));
      final note = await repo.insert(title: 'Notitie', remindAt: future);
      notif.scheduled.clear();

      await repo.update(note.copyWith(clearRemindAt: true));
      // Old reminder is cancelled; no new one is scheduled.
      expect(notif.cancelled, hasLength(1));
      expect(notif.scheduled, isEmpty);
    });

    test('notification errors do NOT prevent note from being saved', () async {
      notif.shouldThrow = true;
      final future = DateTime.now().add(const Duration(hours: 1));
      // Should not throw even though notification scheduling fails.
      final saved = await repo.insert(
        title: 'Foutieve notificatie',
        remindAt: future,
      );
      // Note should still exist in DB despite notification failure.
      final loaded = await repo.watchOne(saved.id).first;
      expect(loaded?.title, equals('Foutieve notificatie'));
    });
  });
}
