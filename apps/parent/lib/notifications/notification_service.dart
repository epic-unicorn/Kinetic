/// Abstract notification service.
///
/// Concrete implementation: [ParentNotificationService] in
/// `support/parent_notification_service.dart`.
abstract class NotificationService {
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
}
