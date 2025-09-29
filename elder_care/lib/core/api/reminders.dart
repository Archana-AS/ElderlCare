import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
// Declare the plugin globally
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

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

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}