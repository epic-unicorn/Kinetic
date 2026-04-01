import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../notifications/notification_service.dart';

// ---------------------------------------------------------------------------
// ParentNotificationService
//
// Production implementation of [NotificationService] using
// flutter_local_notifications.  Initialization is lazy: the first call to any
// scheduling method triggers the underlying plugin setup so the service can be
// created synchronously in [_RootShellState.initState].
// ---------------------------------------------------------------------------

class ParentNotificationService implements NotificationService {
  static const _channelId = 'task_reminders';
  static const _channelName = 'Taakopdrachten';
  static const _channelDesc = 'Herinneringen voor taken en opdrachten';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
    );

    // Request Android 13+ POST_NOTIFICATIONS permission.
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    // Request exact-alarm permission (Android 12+).
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestExactAlarmsPermission();

    _initialized = true;
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  @override
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    await _ensureInitialized();
    final scheduled = tz.TZDateTime.from(at, tz.local);
    if (scheduled.isBefore(DateTime.now())) return; // skip past reminders
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  @override
  Future<void> cancelReminder(int id) async {
    await _ensureInitialized();
    await _plugin.cancel(id);
  }

  @override
  Future<void> sendLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _ensureInitialized();
    await _plugin.show(0, title, body, _details, payload: payload);
  }
}
