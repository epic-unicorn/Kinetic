import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

void main() {
  group('ICalSerializer — tasks (VTODO)', () {
    ICalTask _sampleTask() => ICalTask(
          uid: 'task-001',
          summary: 'Buy groceries',
          description: 'Milk, eggs, bread',
          status: ICalTaskStatus.needsAction,
          priority: 1,
          createdAt: DateTime.utc(2026, 1, 15, 10, 0, 0),
          updatedAt: DateTime.utc(2026, 1, 16, 9, 30, 0),
          dueAt: DateTime.utc(2026, 1, 20, 18, 0, 0),
          remindAt: DateTime.utc(2026, 1, 20, 8, 0, 0),
          rrule: 'FREQ=WEEKLY',
        );

    test('taskToVtodo produces a valid VCALENDAR', () {
      final ical = ICalSerializer.taskToVtodo(_sampleTask());
      expect(ical, contains('BEGIN:VCALENDAR'));
      expect(ical, contains('BEGIN:VTODO'));
      expect(ical, contains('END:VTODO'));
      expect(ical, contains('END:VCALENDAR'));
    });

    test('UID is serialised correctly', () {
      final ical = ICalSerializer.taskToVtodo(_sampleTask());
      expect(ical, contains('UID:task-001'));
    });

    test('SUMMARY is serialised correctly', () {
      final ical = ICalSerializer.taskToVtodo(_sampleTask());
      expect(ical, contains('SUMMARY:Buy groceries'));
    });

    test('STATUS is NEEDS-ACTION', () {
      final ical = ICalSerializer.taskToVtodo(_sampleTask());
      expect(ical, contains('STATUS:NEEDS-ACTION'));
    });

    test('DUE is in UTC format', () {
      final ical = ICalSerializer.taskToVtodo(_sampleTask());
      expect(ical, contains('DUE:20260120T180000Z'));
    });

    test('RRULE is preserved', () {
      final ical = ICalSerializer.taskToVtodo(_sampleTask());
      expect(ical, contains('RRULE:FREQ=WEEKLY'));
    });

    test('VALARM block is emitted when remindAt is set', () {
      final ical = ICalSerializer.taskToVtodo(_sampleTask());
      expect(ical, contains('BEGIN:VALARM'));
      expect(ical, contains('20260120T080000Z'));
    });

    test('vtodoToTask round-trips all fields', () {
      final original = _sampleTask();
      final ical = ICalSerializer.taskToVtodo(original);
      final parsed = ICalSerializer.vtodoToTask(ical);

      expect(parsed.uid, equals(original.uid));
      expect(parsed.summary, equals(original.summary));
      expect(parsed.description, equals(original.description));
      expect(parsed.status, equals(original.status));
      expect(parsed.priority, equals(original.priority));
      expect(parsed.createdAt, equals(original.createdAt));
      expect(parsed.updatedAt, equals(original.updatedAt));
      expect(parsed.dueAt, equals(original.dueAt));
      expect(parsed.rrule, equals(original.rrule));
      // remindAt via VALARM
      expect(parsed.remindAt, equals(original.remindAt));
    });

    test('task with no optional fields round-trips', () {
      final minimal = ICalTask(
        uid: 'min-001',
        summary: 'Minimal',
        createdAt: DateTime.utc(2026, 2, 1),
        updatedAt: DateTime.utc(2026, 2, 1),
      );
      final ical = ICalSerializer.taskToVtodo(minimal);
      final parsed = ICalSerializer.vtodoToTask(ical);
      expect(parsed.uid, equals('min-001'));
      expect(parsed.description, isNull);
      expect(parsed.dueAt, isNull);
      expect(parsed.rrule, isNull);
      expect(parsed.remindAt, isNull);
    });

    test('special characters in summary are escaped and unescaped', () {
      final task = ICalTask(
        uid: 'esc-001',
        summary: 'A, B; C\\D\nE',
        createdAt: DateTime.utc(2026, 3, 1),
        updatedAt: DateTime.utc(2026, 3, 1),
      );
      final ical = ICalSerializer.taskToVtodo(task);
      final parsed = ICalSerializer.vtodoToTask(ical);
      expect(parsed.summary, equals(task.summary));
    });

    test('COMPLETED status round-trips', () {
      final task = ICalTask(
        uid: 'done-001',
        summary: 'Done task',
        status: ICalTaskStatus.completed,
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 1, 2),
      );
      final ical = ICalSerializer.taskToVtodo(task);
      final parsed = ICalSerializer.vtodoToTask(ical);
      expect(parsed.status, equals(ICalTaskStatus.completed));
    });
  });

  group('ICalSerializer — notes (VJOURNAL)', () {
    ICalNote _sampleNote() => ICalNote(
          uid: 'note-001',
          summary: 'Meeting notes',
          description: '## Agenda\n- Item 1\n- Item 2',
          isShared: true,
          createdAt: DateTime.utc(2026, 3, 10, 14, 0, 0),
          updatedAt: DateTime.utc(2026, 3, 10, 15, 0, 0),
          remindAt: DateTime.utc(2026, 3, 11, 9, 0, 0),
        );

    test('noteToVjournal produces a valid VCALENDAR', () {
      final ical = ICalSerializer.noteToVjournal(_sampleNote());
      expect(ical, contains('BEGIN:VCALENDAR'));
      expect(ical, contains('BEGIN:VJOURNAL'));
      expect(ical, contains('END:VJOURNAL'));
      expect(ical, contains('END:VCALENDAR'));
    });

    test('X-KINETIC-SHARED is 1 for shared notes', () {
      final ical = ICalSerializer.noteToVjournal(_sampleNote());
      expect(ical, contains('X-KINETIC-SHARED:1'));
    });

    test('X-KINETIC-SHARED is 0 for private notes', () {
      final note = _sampleNote().copyWith(isShared: false);
      final ical = ICalSerializer.noteToVjournal(note);
      expect(ical, contains('X-KINETIC-SHARED:0'));
    });

    test('vjournalToNote round-trips all fields', () {
      final original = _sampleNote();
      final ical = ICalSerializer.noteToVjournal(original);
      final parsed = ICalSerializer.vjournalToNote(ical);

      expect(parsed.uid, equals(original.uid));
      expect(parsed.summary, equals(original.summary));
      expect(parsed.description, equals(original.description));
      expect(parsed.isShared, equals(original.isShared));
      expect(parsed.createdAt, equals(original.createdAt));
      expect(parsed.updatedAt, equals(original.updatedAt));
      expect(parsed.remindAt, equals(original.remindAt));
    });

    test('note with no optional fields round-trips', () {
      final minimal = ICalNote(
        uid: 'note-min',
        summary: 'Quick note',
        createdAt: DateTime.utc(2026, 4, 1),
        updatedAt: DateTime.utc(2026, 4, 1),
      );
      final ical = ICalSerializer.noteToVjournal(minimal);
      final parsed = ICalSerializer.vjournalToNote(ical);
      expect(parsed.uid, equals('note-min'));
      expect(parsed.description, isNull);
      expect(parsed.remindAt, isNull);
      expect(parsed.isShared, isFalse);
    });
  });
}
