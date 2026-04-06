/// Abstract notification service.
///
/// Concrete implementation: [ParentNotificationService] in
/// `support/parent_notification_service.dart`.
abstract class NotificationService {
  /// Request permissions and set up the notification channel.
  /// Call once at app startup so the Android permission dialog is shown early.
  Future<void> init();

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  });

  Future<void> cancelReminder(int id);

  Future<void> sendLocalNotification({
    required String title,
    required String body,
    String? payload,
  });

  /// Reschedule a reminder for a later time based on snooze/postpone action.
  /// Returns the new scheduled time.
  Future<DateTime> rescheduleReminder({
    required int id,
    required String actionId,
    required String title,
    required String body,
  });
}
