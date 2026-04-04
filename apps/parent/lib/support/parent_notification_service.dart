import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../notifications/notification_service.dart';

// Callback function type for snooze/postpone actions
typedef OnReminderActionCallback =
    Future<void> Function(
      int reminderId,
      String actionId,
      String title,
      String body,
      DateTime originalTime,
    );

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

  // Action IDs for snooze/postpone
  static const _snooze5MinId = 'snooze_5min';
  static const _snooze15MinId = 'snooze_15min';
  static const _snooze1HourId = 'snooze_1hour';
  static const _postpone1DayId = 'postpone_1day';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  OnReminderActionCallback? _onActionCallback;

  // Store reminder metadata for rescheduling
  final Map<int, ({String title, String body, DateTime originalTime})>
  _scheduledReminders = {};

  ParentNotificationService({OnReminderActionCallback? onActionCallback})
    : _onActionCallback = onActionCallback;

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
      onDidReceiveNotificationResponse: _handleNotificationAction,
      onDidReceiveBackgroundNotificationResponse: _handleNotificationAction,
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
      icon: 'mipmap/ic_launcher',
      actions: [
        AndroidNotificationAction(
          _snooze5MinId,
          'Snooze 5 min',
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          _snooze15MinId,
          'Snooze 15 min',
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          _snooze1HourId,
          'Snooze 1 hour',
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          _postpone1DayId,
          'Postpone 1 day',
          showsUserInterface: false,
        ),
      ],
    ),
    iOS: DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  void _handleNotificationAction(NotificationResponse response) {
    final actionId = response.actionId;
    if (actionId == null || actionId.isEmpty) return;

    final reminderId = response.id ?? 0;
    final reminder = _scheduledReminders[reminderId];

    if (reminder != null && _onActionCallback != null) {
      _onActionCallback!.call(
        reminderId,
        actionId,
        reminder.title,
        reminder.body,
        reminder.originalTime,
      );
    }
  }

  @override
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    await _ensureInitialized();

    // Store reminder metadata for action handling
    _scheduledReminders[id] = (title: title, body: body, originalTime: at);

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
    _scheduledReminders.remove(id);
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

  /// Reschedule a reminder for a later time based on the action taken.
  /// Returns the new scheduled time.
  Future<DateTime> rescheduleReminder({
    required int id,
    required String actionId,
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();

    final newTime = switch (actionId) {
      _snooze5MinId => DateTime.now().add(const Duration(minutes: 5)),
      _snooze15MinId => DateTime.now().add(const Duration(minutes: 15)),
      _snooze1HourId => DateTime.now().add(const Duration(hours: 1)),
      _postpone1DayId => DateTime.now().add(const Duration(days: 1)),
      _ => DateTime.now().add(const Duration(minutes: 5)), // default fallback
    };

    await scheduleReminder(id: id, title: title, body: body, at: newTime);

    return newTime;
  }
}
