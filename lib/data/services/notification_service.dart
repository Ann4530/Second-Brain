import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Daily reminder — the habit loop. One scheduled notification at the user's
/// chosen time, rescheduled whenever the time changes.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _dailyId = 1001;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin),
    );
    _inited = true;
  }

  /// Ask for the runtime notification permission (Android 13+ / iOS).
  Future<bool> requestPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true) ?? false;
    }
    return false;
  }

  /// Schedule the daily reminder at [hour]:[minute] local time, repeating.
  Future<void> scheduleDailyReminder({int hour = 21, int minute = 0}) async {
    await init();
    await _plugin.cancel(_dailyId);

    final now = tz.TZDateTime.now(tz.local);
    var when =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (when.isBefore(now)) when = when.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      _dailyId,
      'Time to reflect 🌙',
      'Two quiet minutes — how was your day?',
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Daily reminder',
          channelDescription: 'Reminds you to write your daily reflection.',
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
    );
  }

  Future<void> cancelDailyReminder() => _plugin.cancel(_dailyId);
}
