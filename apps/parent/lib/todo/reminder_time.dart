/// Suggested reminder instant: one hour from [now], rounded up to the next
/// half-hour. Exact `:00` after the +1h step stays on the hour.
///
/// Examples (local wall clock):
///   08:00 → 09:00
///   08:21 → 09:30
///   08:31 → 10:00
DateTime suggestedReminderAt(DateTime now) {
  final plusHour = now.add(const Duration(hours: 1));
  final minute = plusHour.minute;
  if (minute == 0) {
    return DateTime(plusHour.year, plusHour.month, plusHour.day, plusHour.hour);
  }
  if (minute <= 30) {
    return DateTime(
      plusHour.year,
      plusHour.month,
      plusHour.day,
      plusHour.hour,
      30,
    );
  }
  return DateTime(
    plusHour.year,
    plusHour.month,
    plusHour.day,
    plusHour.hour,
  ).add(const Duration(hours: 1));
}
