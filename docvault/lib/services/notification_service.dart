import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

  static Future<void> scheduleExpiryReminder(Document doc) async {
    if (doc.expiryDate == null || doc.id == null) return;
    final notifyAt = doc.expiryDate!.subtract(const Duration(days: 30));
    if (notifyAt.isBefore(DateTime.now())) return;

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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelReminder(int docId) async {
    await _plugin.cancel(docId);
  }
}
