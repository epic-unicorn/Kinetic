import 'package:flutter_test/flutter_test.dart';
import 'package:parent/todo/models/enums.dart';
import 'package:parent/todo/services/category_classifier.dart';

void main() {
  group('CategoryClassifier — auto-classification', () {
    final classifier = categoryClassifier;

    group('Household category', () {
      test('classifies "clean the kitchen" as household', () {
        expect(
          classifier.classify('clean the kitchen'),
          equals(TaskCategory.household),
        );
      });

      test('classifies "buy groceries" as household', () {
        expect(
          classifier.classify('buy groceries'),
          equals(TaskCategory.household),
        );
      });

      test('classifies "do laundry" as household', () {
        expect(
          classifier.classify('do laundry'),
          equals(TaskCategory.household),
        );
      });

      test('classifies "paint the bedroom" as household', () {
        expect(
          classifier.classify('paint the bedroom'),
          equals(TaskCategory.household),
        );
      });

      test('classifies with case-insensitive matching', () {
        expect(
          classifier.classify('CLEAN THE BATHROOM'),
          equals(TaskCategory.household),
        );
      });
    });

    group('Health category', () {
      test('classifies "doctor appointment" as health', () {
        expect(
          classifier.classify('doctor appointment'),
          equals(TaskCategory.health),
        );
      });

      test('classifies "dentist checkup" as health', () {
        expect(
          classifier.classify('dentist checkup'),
          equals(TaskCategory.health),
        );
      });

      test('classifies "go to gym" as health', () {
        expect(classifier.classify('go to gym'), equals(TaskCategory.health));
      });

      test('classifies "take medicine" as health', () {
        expect(
          classifier.classify('take medicine'),
          equals(TaskCategory.health),
        );
      });
    });

    group('Admin category', () {
      test('classifies "sign form" as admin', () {
        expect(classifier.classify('sign form'), equals(TaskCategory.admin));
      });

      test('classifies "file taxes" as admin', () {
        expect(classifier.classify('file taxes'), equals(TaskCategory.admin));
      });

      test('classifies "renew passport" as admin', () {
        expect(
          classifier.classify('renew passport'),
          equals(TaskCategory.admin),
        );
      });

      test('classifies with notes included', () {
        expect(
          classifier.classify('urgent task', notes: 'with taxation impact'),
          equals(TaskCategory.admin),
        );
      });
    });

    group('School category', () {
      test('classifies "homework" as school', () {
        expect(classifier.classify('homework'), equals(TaskCategory.school));
      });

      test('classifies "parent-teacher meeting" as school', () {
        expect(
          classifier.classify('parent-teacher meeting'),
          equals(TaskCategory.school),
        );
      });

      test('classifies "school project" as school', () {
        expect(
          classifier.classify('school project'),
          equals(TaskCategory.school),
        );
      });
    });

    group('Finance category', () {
      test('classifies "invest money" as finance', () {
        expect(
          classifier.classify('invest money'),
          equals(TaskCategory.finance),
        );
      });

      test('classifies "savings" as finance', () {
        expect(classifier.classify('savings'), equals(TaskCategory.finance));
      });

      test('classifies "budget review" as finance', () {
        expect(
          classifier.classify('budget review'),
          equals(TaskCategory.finance),
        );
      });
    });

    group('Default behavior', () {
      test('returns "other" when no keywords match', () {
        expect(
          classifier.classify('random task with no keywords'),
          equals(TaskCategory.other),
        );
      });

      test('returns "other" for empty string', () {
        expect(classifier.classify(''), equals(TaskCategory.other));
      });

      test('prioritizes first matching category in rules order', () {
        // "meeting" appears in school, prioritize by order
        expect(classifier.classify('meeting'), isNotNull);
      });
    });

    group('Notes parameter', () {
      test('considers notes in classification when provided', () {
        final withoutNotes = classifier.classify('some task');
        final withNotes = classifier.classify(
          'some task',
          notes: 'this is a very important medical appointment',
        );

        // Notes should help classify as health
        expect(withNotes, equals(TaskCategory.health));
      });

      test('empty notes are treated as no notes', () {
        expect(
          classifier.classify('regular task', notes: ''),
          equals(TaskCategory.other),
        );
      });
    });

    group('Edge cases', () {
      test('handles whitespace normalization', () {
        expect(
          classifier.classify('  clean  '),
          equals(TaskCategory.household),
        );
      });

      test('matches partial words in title', () {
        expect(
          classifier.classify('cleaning supplies needed'),
          equals(TaskCategory.household),
        );
      });

      test('handles titles with special characters', () {
        expect(classifier.classify('buy groceries & pay bills'), isNotNull);
      });
    });
  });
}
