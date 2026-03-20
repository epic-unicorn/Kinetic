/// Abstract interface for delivering notifications to the device user.
///
/// The production implementation (using `flutter_local_notifications`) is wired
/// in Phase 4 alongside the kids-kiosk lockdown features.
/// This stub is sufficient for Phase 3 logic testing.
abstract class NotificationService {
  /// Displays an immediate local notification.
  Future<void> sendLocalNotification({
    required String title,
    required String body,
    String? payload,
  });

  /// Schedules a reminder notification for [at], identified by [id].
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  });

  /// Cancels a previously scheduled reminder.
  Future<void> cancelReminder(int id);
}

/// No-op implementation used during development and in tests.
///
/// Replace with a real plugin implementation in Phase 4.
class StubNotificationService implements NotificationService {
  /// Records calls made during tests.
  final List<({String title, String body})> sent = [];

  @override
  Future<void> sendLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    sent.add((title: title, body: body));
  }

  @override
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {}

  @override
  Future<void> cancelReminder(int id) async {}
}
