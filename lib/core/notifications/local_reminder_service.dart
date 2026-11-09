import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class LocalReminderService {
  LocalReminderService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const _reminderChannel = AndroidNotificationChannel(
    'rayna_reminders',
    'Rayna Reminders',
    description:
        'Gentle reminders to connect and share moments with your partner.',
    importance: Importance.defaultImportance,
  );

  static const _alertsChannel = AndroidNotificationChannel(
    'rayna_alerts',
    'Rayna Alerts',
    description: 'Notifications for moments, moods, and partner messages.',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      tz.initializeTimeZones();
    } catch (_) {}

    const android = AndroidInitializationSettings(
      '@drawable/ic_launcher_foreground',
    );
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(_reminderChannel);
    await androidPlugin?.createNotificationChannel(_alertsChannel);
    await androidPlugin?.requestNotificationsPermission();
  }

  /// Schedule a daily reminder at [hour]:[minute] (e.g. 20:00 = 8 PM).
  Future<void> scheduleDailyReminder({int hour = 20, int minute = 0}) async {
    await initialize();
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      7002,
      'A moment for two ❤️',
      'Take a minute to share a smile or sweet note with your partner.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'rayna_reminders',
          'Rayna Reminders',
          channelDescription:
              'Gentle reminders to connect and share moments with your partner.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@drawable/ic_launcher_foreground',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() => _plugin.cancel(7002);

  /// Schedule a spontaneous reminder within the next 24 hours.
  Future<void> scheduleRandomReminder({int? seed}) async {
    await initialize();
    final random = Random(seed);
    final now = tz.TZDateTime.now(tz.local);
    final scheduled = now.add(Duration(hours: 2 + random.nextInt(20)));

    await _plugin.zonedSchedule(
      7001,
      'Thinking of you',
      'Share a spontaneous photo or mood with your partner today.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'rayna_reminders',
          'Rayna Reminders',
          channelDescription:
              'Gentle reminders to connect and share moments with your partner.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@drawable/ic_launcher_foreground',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelReminder() => _plugin.cancel(7001);

  Future<void> cancelAllReminders() async {
    await _plugin.cancel(7001);
    await _plugin.cancel(7002);
  }

  /// Show an immediate test notification to verify delivery & sound/banner settings.
  Future<void> showTestNotification() async {
    await initialize();
    const android = AndroidNotificationDetails(
      'rayna_alerts',
      'Rayna Alerts',
      channelDescription:
          'Notifications for moments, moods, and partner messages.',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_launcher_foreground',
    );
    const details = NotificationDetails(android: android);

    await _plugin.show(
      9999,
      'Rayna ❤️',
      'This is a preview notification. You are connected with your partner!',
      details,
      payload: '{"type":"chat"}',
    );
  }
}
