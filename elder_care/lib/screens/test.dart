import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../core/api/chat.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../core/api/reminders.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

Future<void> _scheduleNativeReminder(String task, String scheduledTimeUtc) async {
  // Parse the ISO 8601 UTC timestamp
  final scheduledDateTime = DateTime.parse(scheduledTimeUtc);

  // Convert the standard DateTime to a Timezone-aware DateTime (TZDateTime)
  // using the local location (tz.local) which was set up in initNotifications()
  final tz.TZDateTime scheduledTZDateTime =
  tz.TZDateTime.from(scheduledDateTime, tz.local);

  // You need a unique ID for each notification.
  // A simple way is to use the current time's millisecondsSinceEpoch
  // or a counter, though a dedicated database ID is best in a real app.
  const int notificationId = 0; // Use a different ID for each reminder

  const NotificationDetails notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminder_channel_id', // Must be unique
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
    notificationId, // The unique ID
    'Reminder: $task', // Notification Title
    'Time to complete your task!', // Notification Body
    scheduledTZDateTime, // The scheduled time as TZDateTime
    notificationDetails,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    // Required for scheduling exact alarms on modern Android devices
    uiLocalNotificationDateInterpretation:
    UILocalNotificationDateInterpretation.absoluteTime,
    // Optional: add a payload to handle taps, e.g., 'task_id_123'
    payload: 'task_payload_$notificationId',
  );

  print('--- Native Reminder Scheduled ---');
  print('Task: $task');
  print('Scheduled Time (Local TZ): $scheduledTZDateTime');
}

class _ChatScreenState extends State<ChatScreen> {
  // ... existing variables ...
  final OllamaChatService _chatService = OllamaChatService();
  final TextEditingController _controller = TextEditingController();
  // Using a list to store the chat history for a better display
  final List<String> _messages = [];
  String _currentTypingText = '';
  bool _isLoading = false;

  void _sendMessage() {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty || _isLoading) return;

    // Add user message to history
    setState(() {
      _messages.add("You: $prompt"); // Simple way to show user message
      _isLoading = true;
      _currentTypingText = '';
    });
    _controller.clear(); // Clear input field immediately

    try {
      // The stream now yields ChatResponse objects
      _chatService.streamChatResponse(prompt: prompt).listen(
            (response) {
          if (response.isReminder) {
            // --- HANDLER FOR REMINDER JSON RESPONSE ---
            final data = response.reminderData!;
            final task = data['task'] as String;
            final timeUtc = data['scheduled_time_utc'] as String;
            final acknowledgement = data['acknowledgement'] as String;

            // 1. SCHEDULE NATIVE PHONE REMINDER
            _scheduleNativeReminder(task, timeUtc);

            // 2. UPDATE CHAT HISTORY WITH ACKNOWLEDGEMENT
            setState(() {
              _messages.add("ElderCare: $acknowledgement");
              _isLoading = false;
            });

          } else {
            // --- HANDLER FOR STREAMING TEXT RESPONSE ---
            setState(() {
              _currentTypingText += response.text!;
            });
          }
        },
        onError: (error) {
          setState(() {
            _messages.add('Error: $error');
            _currentTypingText = '';
            _isLoading = false;
          });
        },
        onDone: () {
          if (_currentTypingText.isNotEmpty) {
            // Finalize the streamed response and add it to history
            setState(() {
              _messages.add("ElderCare: $_currentTypingText");
              _currentTypingText = '';
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      setState(() {
        _messages.add('Fatal Error: $e');
        _isLoading = false;
        _currentTypingText = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Companion Chat'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView.builder(
                // Use a ListView to display all messages
                itemCount: _messages.length + (_currentTypingText.isNotEmpty ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < _messages.length) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(_messages[index], style: const TextStyle(fontSize: 16.0)),
                    );
                  } else {
                    // Display the currently typing text
                    return Text(
                      "ElderCare: $_currentTypingText" + (_isLoading ? ' |' : ''), // ' |' to simulate typing
                      style: const TextStyle(fontSize: 16.0, fontStyle: FontStyle.italic),
                    );
                  }
                },
              ),
            ),

            const SizedBox(height: 16.0),

            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'Ask your companion...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8.0),
                FloatingActionButton(
                  onPressed: _sendMessage,
                  tooltip: 'Send Message',
                  elevation: 2,
                  child: _isLoading
                      ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                  )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}