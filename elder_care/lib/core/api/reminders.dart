import 'dart:async';
import 'dart:io';
import 'package:elder_care/core/api/urlfinder.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
// Declare the plugin globally
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
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

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,// Correctly passed
    onDidReceiveNotificationResponse: (NotificationResponse response) async{
      final url = await getPublicUrl();
      final int? notifId = response.id;
      print(notifId);
      if (notifId != null) {

        final notifDeleteUrl = Uri.parse('$url/reminderDelete/$notifId');
        final response = await http.delete(notifDeleteUrl);
      }
    },
    onDidReceiveBackgroundNotificationResponse:notificationTapBackground

  );

}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async{
  final url = await getPublicUrl();
  final int? notifId = response.id;
  print(notifId);
  if (notifId != null) {

    final notifDeleteUrl = Uri.parse('$url/reminderDelete/$notifId');
    final response = await http.delete(notifDeleteUrl);
  }
}


Future<void> requestNotificationPermissionAndroidOnly() async {
  if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        final result = await Permission.notification.request();
        print('Notification permission: $result');
    }
  }
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
