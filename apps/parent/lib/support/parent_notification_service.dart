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

const _kNotifDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    _kChannelId,
    _kChannelName,
    channelDescription: _kChannelDesc,
    importance: Importance.high,
    priority: Priority.high,
    icon: 'ic_notification',
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
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
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
    await _plugin.show(0, title, body, _kNotifDetails, payload: payload);
  }

}
