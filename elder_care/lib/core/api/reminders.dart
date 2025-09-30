import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
// Declare the plugin globally
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
final StreamController<NotificationResponse> selectNotificationStream =StreamController<NotificationResponse>.broadcast();

// Define a function for initialization
Future<void> initializeAppDependencies() async {
  // MUST be called first to ensure widget binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // --- TIMEZONE INITIALIZATION (Fixes the LateInitializationError) ---
  tz.initializeTimeZones();
  final String timeZoneName = await FlutterTimezone.getLocalTimezone();
  tz.setLocalLocation(tz.getLocation("Asia/Kolkata"));
  // -------------------------------------------------------------------

  // Local Notifications Setup
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  void onNotificationTap(NotificationResponse response) {
    print("Tapped Notification (foreground): ${response.id}");
  }

  @pragma('vm:entry-point')
  void notificationTapBackground(NotificationResponse notificationResponse) {
     print('notification(${notificationResponse.id}) action tapped: '
     '${notificationResponse.actionId} with'
     ' payload: ${notificationResponse.payload}');
  }

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: selectNotificationStream.add,
    onDidReceiveBackgroundNotificationResponse: notificationTapBackground, // Correctly passed
  );

}

Future<void> scheduleNativeReminder(String task, String scheduledTimeUtc) async {
  final scheduledDateTime = DateTime.parse(scheduledTimeUtc);
  final tz.TZDateTime scheduledTZDateTime = tz.TZDateTime.from(scheduledDateTime, tz.local);

  final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

  const NotificationDetails notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminder_channel_id',
      'Reminders',
      channelDescription: 'Notification channel for scheduled reminders',
      importance: Importance.max,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(
      sound: 'default',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  await flutterLocalNotificationsPlugin.zonedSchedule(
    notificationId,
    'Reminder: $task',
    'Time to complete your task!',
    scheduledTZDateTime,
    notificationDetails,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    payload: 'task_payload_$notificationId',
  );
}
