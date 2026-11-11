import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/reminder.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: initSettingsAndroid,
    );

    await _plugin.initialize(initSettings);

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
      await androidImpl.requestExactAlarmsPermission();
    }
  }

  static int _getNotificationId(String id) {
    return id.hashCode & 0x7FFFFFFF;
  }

  static Future<void> scheduleReminder(Reminder reminder) async {
    if (!reminder.isEnabled) return;

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    bool canScheduleExact =
        await androidImpl?.canScheduleExactNotifications() ?? true;

    if (!canScheduleExact) {
      await androidImpl?.requestExactAlarmsPermission();
      canScheduleExact =
          await androidImpl?.canScheduleExactNotifications() ?? true;
    }

    final scheduleMode = canScheduleExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    await cancelReminder(reminder.id);

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'reminders_channel_v3',
          'Напоминания',
          channelDescription: 'Плановые напоминания по времени',
          importance: Importance.max,
          priority: Priority.high,
        );
    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    final baseId = _getNotificationId(reminder.id);

    if (reminder.daysOfWeek.isEmpty) {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        reminder.hour,
        reminder.minute,
      );
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        baseId,
        'Напоминание',
        reminder.title,
        scheduledDate,
        details,
        androidScheduleMode: scheduleMode,
        matchDateTimeComponents: DateTimeComponents.time,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } else {
      for (final day in reminder.daysOfWeek) {
        final now = tz.TZDateTime.now(tz.local);
        var scheduledDate = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          reminder.hour,
          reminder.minute,
        );

        while (scheduledDate.weekday != day || scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(const Duration(days: 1));
        }

        await _plugin.zonedSchedule(
          baseId + day,
          'Напоминание',
          reminder.title,
          scheduledDate,
          details,
          androidScheduleMode: scheduleMode,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  static Future<void> cancelReminder(String id) async {
    final baseId = _getNotificationId(id);
    await _plugin.cancel(baseId);
    for (int i = 1; i <= 7; i++) {
      await _plugin.cancel(baseId + i);
    }
  }

  // --- НОВЫЙ МЕТОД ДЛЯ ДИАГНОСТИКИ ---
  static Future<List<PendingNotificationRequest>>
  getPendingNotifications() async {
    return await _plugin.pendingNotificationRequests();
  }
}
