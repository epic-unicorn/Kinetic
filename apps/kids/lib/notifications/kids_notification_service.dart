import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Minimal notification service for the kids app.
///
/// Shows a notification when the parent sends a new task.
class KidsNotificationService {
  static const _kChannelId = 'kinetic_kids_tasks';
  static const _kChannelName = 'Opdrachten';
  static const _kChannelDesc = 'Meldingen voor nieuwe opdrachten van de ouder.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _kNotifDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _kChannelId,
      _kChannelName,
      channelDescription: _kChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
  );

  /// Must be called once at app start before showing any notifications.
  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(initSettings);

    // Request permission on Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  /// Shows a "Nieuwe opdracht" notification for the given [taskTitle].
  Future<void> showNewTaskNotification(String taskTitle) async {
    await _plugin.show(
      taskTitle.hashCode,
      'Nieuwe opdracht',
      taskTitle,
      _kNotifDetails,
    );
  }
}
