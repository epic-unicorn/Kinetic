import 'package:flutter_test/flutter_test.dart';
import 'package:parent/todo/models/enums.dart';
import 'package:parent/todo/models/personal_task.dart';
import 'package:parent/todo/services/reminder_proposal_engine.dart';

void main() {
  final engine = ReminderProposalEngine();

  PersonalTask completed({
    required String title,
    required DateTime completedAt,
  }) {
    return PersonalTask.create(
      title: title,
      dueDate: completedAt,
      isAllDay: false,
    ).copyWith(isCompleted: true, completedAt: completedAt);
  }

  group('ReminderProposalEngine', () {
    test('empty title returns fallback chips', () {
      final chips = engine.propose(
        title: '',
        completedTasks: const [],
        now: DateTime(2026, 6, 17, 10),
      );
      expect(chips, isNotEmpty);
      expect(chips.map((c) => c.label), contains('In 1 hour'));
      expect(chips.map((c) => c.label), contains('Tomorrow 09:00'));
    });

    test('school keyword suggests tomorrow morning', () {
      final chips = engine.propose(
        title: 'Schooltas controleren',
        completedTasks: const [],
        now: DateTime(2026, 6, 17, 10),
      );
      expect(chips.first.label, 'Tomorrow 07:00');
    });

    test('habit time wins over category default', () {
      final saturday = DateTime(2026, 6, 13, 10);
      final chips = engine.propose(
        title: 'Boodschappen',
        category: TaskCategory.household,
        completedTasks: [
          completed(title: 'Boodschappen', completedAt: saturday),
          completed(
            title: 'Boodschappen',
            completedAt: saturday.subtract(const Duration(days: 7)),
          ),
        ],
        now: DateTime(2026, 6, 17, 10),
      );
      expect(chips.first.label, startsWith('Sat'));
      expect(chips.first.explanation, isNotNull);
    });

    test('hides vanavond chip after 20:00', () {
      final chips = engine.propose(
        title: 'Iets doen',
        completedTasks: const [],
        now: DateTime(2026, 6, 17, 21),
      );
      expect(chips.map((c) => c.label), isNot(contains('Tonight 20:00')));
    });

    test('deduplicates near-identical times', () {
      final chips = engine.propose(
        title: 'Taak',
        completedTasks: const [],
        now: DateTime(2026, 6, 17, 10),
        maxChips: 6,
      );
      for (var i = 0; i < chips.length; i++) {
        for (var j = i + 1; j < chips.length; j++) {
          final diff = chips[i].at.difference(chips[j].at).inMinutes.abs();
          expect(diff, greaterThanOrEqualTo(30));
        }
      }
    });
  });
}
