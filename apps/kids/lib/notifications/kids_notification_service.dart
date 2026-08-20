import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../l10n/generated/app_localizations.dart';

/// Minimal notification service for the kids app.
///
/// Shows a notification when the parent sends a new task.
class KidsNotificationService {
  static const _kChannelId = 'kinetic_kids_tasks';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  NotificationDetails? _notifDetails;

  Locale _resolveLocale() {
    final locale = WidgetsBinding.instance.platformDispatcher.locale;
    for (final supported in AppLocalizations.supportedLocales) {
      if (supported.languageCode == locale.languageCode) {
        return supported;
      }
    }
    return AppLocalizations.supportedLocales.first;
  }

  /// Must be called once at app start before showing any notifications.
  Future<void> initialize() async {
    final l10n = lookupAppLocalizations(_resolveLocale());
    _notifDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _kChannelId,
        l10n.notificationChannelName,
        channelDescription: l10n.notificationChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    );

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

  /// Shows a new-task notification for the given [taskTitle].
  Future<void> showNewTaskNotification(
    String taskTitle, {
    String? title,
  }) async {
    final details = _notifDetails;
    if (details == null) return;

    final resolvedTitle = title ??
        lookupAppLocalizations(_resolveLocale()).newTaskNotificationTitle;

    await _plugin.show(
      taskTitle.hashCode,
      resolvedTitle,
      taskTitle,
      details,
    );
  }
}
