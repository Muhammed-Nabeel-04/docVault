import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../models/document.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      const legacyNames = <String, String>{
        'Asia/Calcutta': 'Asia/Kolkata',
        'Asia/Ulaanbaatar': 'Asia/Ulan_Bator',
        'America/Buenos_Aires': 'America/Argentina/Buenos_Aires',
        'Asia/Katmandu': 'Asia/Kathmandu',
      };
      final identifier = legacyNames[tzInfo.identifier] ?? tzInfo.identifier;
      tz.setLocalLocation(tz.getLocation(identifier));
    } catch (e) {
      debugPrint('Timezone lookup failed: $e. Falling back to UTC.');
      tz.setLocalLocation(tz.UTC);
    }

    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);
  }

  static Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      // Notification permission (Android 13+)
      final status = await Permission.notification.request();
      if (status.isDenied) return false;

      // Exact alarm permission check (Android 12+)
      if (await Permission.scheduleExactAlarm.isDenied) {
        // Request permission - this takes the user to the system settings page
        // where they must manually enable "Allow setting alarms and reminders"
        await Permission.scheduleExactAlarm.request();
      }
    }
    return true;
  }

  static Future<bool> hasPermission() async {
    if (Platform.isAndroid) {
      return await Permission.notification.isGranted;
    }
    return true;
  }

  static Future<void> scheduleExpiryReminder(Document doc) async {
    if (!await hasPermission()) return;
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
