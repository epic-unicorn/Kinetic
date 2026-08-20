import 'package:flutter_test/flutter_test.dart';
import 'package:parent/todo/reminder_time.dart';

void main() {
  group('suggestedReminderAt', () {
    test('08:00 → 09:00', () {
      final result = suggestedReminderAt(DateTime(2026, 8, 20, 8, 0));
      expect(result, DateTime(2026, 8, 20, 9, 0));
    });

    test('08:21 → 09:30', () {
      final result = suggestedReminderAt(DateTime(2026, 8, 20, 8, 21));
      expect(result, DateTime(2026, 8, 20, 9, 30));
    });

    test('08:31 → 10:00', () {
      final result = suggestedReminderAt(DateTime(2026, 8, 20, 8, 31));
      expect(result, DateTime(2026, 8, 20, 10, 0));
    });

    test('08:30 → 09:30', () {
      final result = suggestedReminderAt(DateTime(2026, 8, 20, 8, 30));
      expect(result, DateTime(2026, 8, 20, 9, 30));
    });

    test('23:40 rolls into the next day', () {
      final result = suggestedReminderAt(DateTime(2026, 8, 20, 23, 40));
      expect(result, DateTime(2026, 8, 21, 1, 0));
    });

    test('23:00 → 00:00 next day', () {
      final result = suggestedReminderAt(DateTime(2026, 8, 20, 23, 0));
      expect(result, DateTime(2026, 8, 21, 0, 0));
    });
  });
}
