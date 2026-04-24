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

  // Action IDs for snooze
  static const _snooze1HourId = 'snooze_1hour';
  static const _snooze1DayId = 'snooze_1day';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  OnReminderActionCallback? _onActionCallback;

  // Store reminder metadata for rescheduling
  final Map<int, ({String title, String body, DateTime originalTime})>
  _scheduledReminders = {};

  ParentNotificationService({OnReminderActionCallback? onActionCallback})
    : _onActionCallback = onActionCallback;

  @override
  Future<void> init() => _ensureInitialized();

  @override
  Future<bool> areNotificationsEnabled() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true; // iOS/other: assume granted
    return await android.areNotificationsEnabled() ?? true;
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return true; // iOS/other: assume granted
    return await android.canScheduleExactAlarms() ?? true;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    // Timezone setup — fall back to UTC if the device returns an unknown
    // identifier, so a timezone failure never blocks notification init.
    try {
      tz.initializeTimeZones();
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.UTC);
    }

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        ),
      ),
      onDidReceiveNotificationResponse: _handleNotificationAction,
      // onDidReceiveBackgroundNotificationResponse requires a top-level
      // @pragma('vm:entry-point') function and cannot be an instance method.
      // Background-tap actions are not supported; foreground tap/action
      // handling is covered by onDidReceiveNotificationResponse above.
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
      icon: '@drawable/ic_notification',
      actions: [
        AndroidNotificationAction(
          _snooze1HourId,
          '1 uur',
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          _snooze1DayId,
          '1 dag',
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

    // Use exact scheduling when permitted; fall back to inexact (±15 min) so
    // reminders always fire even if the Alarms & Reminders grant is missing.
    final exact = await canScheduleExactAlarms();
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      _details,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
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
      _snooze1HourId => DateTime.now().add(const Duration(hours: 1)),
      _snooze1DayId => DateTime.now().add(const Duration(days: 1)),
      _ => DateTime.now().add(const Duration(hours: 1)),
    };

    await scheduleReminder(id: id, title: title, body: body, at: newTime);

    return newTime;
  }
}
