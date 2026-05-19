import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../notifications/notification_service.dart';

// ---------------------------------------------------------------------------
// Top-level constants — shared between the service and the background isolate
// handler so they can be referenced from a @pragma('vm:entry-point') function.
// ---------------------------------------------------------------------------

const _kChannelId = 'task_reminders';
const _kChannelName = 'Taakopdrachten';
const _kChannelDesc = 'Herinneringen voor taken en opdrachten';
const _kSnooze10MinId = 'snooze_10min';
const _kDismissId = 'dismiss';

const _kNotifDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    _kChannelId,
    _kChannelName,
    channelDescription: _kChannelDesc,
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_notification',
    actions: [
      AndroidNotificationAction(
        _kSnooze10MinId,
        'Snooze 10min',
        showsUserInterface: false,
      ),
      AndroidNotificationAction(
        _kDismissId,
        'Negeren',
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

// ---------------------------------------------------------------------------
// Background notification handler.
//
// Must be a top-level function with @pragma so the Dart VM can call it in a
// background isolate when the app is in the background or terminated.
// "Negeren" simply dismisses — the notification is already gone from the
// tray, so nothing needs to happen.  "Snooze 10min" re-schedules using a
// freshly created plugin instance; title/body are recovered from the payload
// that was stored when the notification was first scheduled.
// ---------------------------------------------------------------------------

@pragma('vm:entry-point')
Future<void> _notifBackgroundHandler(NotificationResponse response) async {
  final actionId = response.actionId;
  if (actionId == null || actionId == _kDismissId) return;

  if (actionId == _kSnooze10MinId) {
    String title = 'Herinnering';
    String body = '';
    final payload = response.payload;
    if (payload != null) {
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        title = data['title'] as String? ?? title;
        body = data['body'] as String? ?? body;
      } catch (_) {}
    }

    // Timezone initialisation — fall back to UTC on any failure.
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    final newTime = tz.TZDateTime.now(
      tz.local,
    ).add(const Duration(minutes: 10));
    try {
      await plugin.zonedSchedule(
        response.id ?? 0,
        title,
        body,
        newTime,
        _kNotifDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      await plugin.zonedSchedule(
        response.id ?? 0,
        title,
        body,
        newTime,
        _kNotifDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}

// Callback function type for snooze/dismiss actions
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
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  final OnReminderActionCallback? _onActionCallback;

  // Store reminder metadata for rescheduling (foreground use)
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
        // Handles action button taps when the app is in the background or
        // terminated.  Must reference a top-level @pragma function.
        onDidReceiveBackgroundNotificationResponse: _notifBackgroundHandler,
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

  void _handleNotificationAction(NotificationResponse response) {
    final actionId = response.actionId;
    if (actionId == null || actionId.isEmpty) return;

    final reminderId = response.id ?? 0;
    final reminder = _scheduledReminders[reminderId];

    // Fall back to payload when the in-memory map is empty (e.g. after a hot
    // restart or if the task was scheduled in a previous session).
    final title =
        reminder?.title ??
        _fieldFromPayload(response.payload, 'title', 'Herinnering');
    final body =
        reminder?.body ?? _fieldFromPayload(response.payload, 'body', '');
    final originalTime = reminder?.originalTime ?? DateTime.now();

    if (_onActionCallback != null) {
      _onActionCallback.call(reminderId, actionId, title, body, originalTime);
    }
  }

  String _fieldFromPayload(String? payload, String key, String fallback) {
    if (payload == null) return fallback;
    try {
      return (jsonDecode(payload) as Map<String, dynamic>)[key] as String? ??
          fallback;
    } catch (_) {
      return fallback;
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

    // Store reminder metadata for action handling (foreground)
    _scheduledReminders[id] = (title: title, body: body, originalTime: at);

    final scheduled = tz.TZDateTime.from(at, tz.local);
    if (scheduled.isBefore(DateTime.now())) return; // skip past reminders

    // Encode title/body into the payload so the background handler can
    // recover them without needing the in-memory map.
    final payload = jsonEncode({'title': title, 'body': body});

    // Try exact alarm first (fires on time). If the OS throws a
    // SecurityException because SCHEDULE_EXACT_ALARM was not granted (Android
    // 12+), fall back to inexact which fires within ±15 minutes.
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        _kNotifDetails,
        payload: payload,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        _kNotifDetails,
        payload: payload,
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
    await _plugin.show(0, title, body, _kNotifDetails, payload: payload);
  }

  /// Reschedule a reminder 10 minutes from now (snooze).
  /// Returns the new scheduled time.
  @override
  Future<DateTime> rescheduleReminder({
    required int id,
    required String actionId,
    required String title,
    required String body,
  }) async {
    await _ensureInitialized();

    final newTime = DateTime.now().add(const Duration(minutes: 10));
    await scheduleReminder(id: id, title: title, body: body, at: newTime);
    return newTime;
  }

  static bool isDismissAction(String actionId) => actionId == _kDismissId;
}
