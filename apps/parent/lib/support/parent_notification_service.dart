import 'dart:io';

import 'package:flutter/services.dart';
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

  // Action IDs for snooze / dismiss
  static const _snooze10MinId = 'snooze_10min';
  static const _snooze1HourId = 'snooze_1hour';
  static const _dismissId = 'dismiss';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  final OnReminderActionCallback? _onActionCallback;

  // Store reminder metadata for rescheduling
  final Map<int, ({String title, String body, DateTime originalTime})>
  _scheduledReminders = {};

  ParentNotificationService({OnReminderActionCallback? onActionCallback})
    : _onActionCallback = onActionCallback;

  // Stores any error that occurred during initialisation so callers can
  // surface it to the user in both debug and release builds.
  Object? initError;

  @override
  Future<void> init() => _ensureInitialized();

  @override
  Future<bool> areNotificationsEnabled() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return true; // iOS/other: assume granted
    return await android.areNotificationsEnabled() ?? true;
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    try {
      const channel = MethodChannel('net.moonbaseone.kinetic.parent/settings');
      final result = await channel.invokeMethod<bool>('canScheduleExactAlarms');
      return result ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;

    try {
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
          android: AndroidInitializationSettings('ic_notification'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          ),
        ),
        onDidReceiveNotificationResponse: _handleNotificationAction,
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
      initError = null;
    } catch (e, st) {
      initError = e;
      // Rethrow so the caller (main.dart) can surface the error.
      Error.throwWithStackTrace(e, st);
    }
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_notification',
      actions: [
        AndroidNotificationAction(
          _snooze10MinId,
          '10 min',
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          _snooze1HourId,
          '1 uur',
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          _dismissId,
          'Verwijderen',
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
      _onActionCallback.call(
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

    // Try exact alarm first (fires on time). If the OS throws a SecurityException
    // because SCHEDULE_EXACT_ALARM was not granted by the user (Android 12+),
    // fall back to inexact which fires within ±15 minutes and needs no special
    // permission. USE_EXACT_ALARM is intentionally not declared in the manifest
    // because it is restricted to alarm/clock apps on API 35+.
    try {
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
    } catch (_) {
      // SecurityException: SCHEDULE_EXACT_ALARM not granted — use inexact fallback.
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
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
  @override
  Future<DateTime> rescheduleReminder({
    required int id,
    required String actionId,
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();

    final newTime = switch (actionId) {
      _snooze10MinId => DateTime.now().add(const Duration(minutes: 10)),
      _snooze1HourId => DateTime.now().add(const Duration(hours: 1)),
      _ => DateTime.now().add(const Duration(hours: 1)),
    };

    await scheduleReminder(id: id, title: title, body: body, at: newTime);

    return newTime;
  }

  static bool isDismissAction(String actionId) => actionId == _dismissId;
}
