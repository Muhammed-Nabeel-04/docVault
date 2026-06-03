import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/document.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
  }

  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      // Notification permission (Android 13+)
      final status = await Permission.notification.request();
      if (status.isDenied) return false;

      // Exact alarm permission check (Android 12+)
      // Note: SCHEDULE_EXACT_ALARM is granted by default on most apps, 
      // but can be revoked by user.
      if (await Permission.scheduleExactAlarm.isDenied) {
        // We could request it, but it takes user to settings.
        // For now, we'll just check if we can proceed.
      }
    }
    return true;
  }

  static Future<void> scheduleExpiryReminder(Document doc) async {
    if (doc.expiryDate == null || doc.id == null) return;
    final notifyAt = doc.expiryDate!.subtract(const Duration(days: 30));
    if (notifyAt.isBefore(DateTime.now())) return;

    // Check if we can use exact alarms
    AndroidScheduleMode scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
    if (Platform.isAndroid) {
      final canScheduleExact = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.canScheduleExactNotifications();
      
      if (canScheduleExact == false) {
        scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      }
    }

    await _plugin.zonedSchedule(
      doc.id!,
      'Document expiring soon',
      '${doc.name} expires on ${doc.expiryDate!.day}/${doc.expiryDate!.month}/${doc.expiryDate!.year}',
      tz.TZDateTime.from(notifyAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'expiry_channel',
          'Document Expiry Reminders',
          channelDescription: 'Alerts when documents are about to expire',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelReminder(int docId) async {
    await _plugin.cancel(docId);
  }
}
