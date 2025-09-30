import 'dart:async';
import 'package:elder_care/screens/homepage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_tts/flutter_tts.dart';
import '../core/api/chat.dart';
import '../core/api/reminders.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

Future<void> _scheduleNativeReminder(String task, String scheduledTimeUtc) async {
  final scheduledDateTime = DateTime.parse(scheduledTimeUtc);
  final tz.TZDateTime scheduledTZDateTime = tz.TZDateTime.from(scheduledDateTime, tz.local);

  const int notificationId = 0; // Update this in real app to unique ID

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

class _ChatScreenState extends State<ChatScreen> {
  final OllamaChatService _chatService = OllamaChatService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool isSpoken = false;

  FlutterTts flutterTts = FlutterTts();

  Future<void> configureTts() async {
    await flutterTts.setLanguage('en-US');
    await flutterTts.setSpeechRate(0.0);
    await flutterTts.setVolume(1.0);
  }


  final List<Map<String, dynamic>> _messages = []; // {'text': '', 'isUser': true/false}
  String _currentTypingText = '';
  bool _isLoading = false;

  // Speech-to-text
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    configureTts();
  }

  void _sendMessage() {
    final prompt = _controller.text.trim();
    if (prompt.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({'text': prompt, 'isUser': true});
      _isLoading = true;
      _currentTypingText = '';
      _scrollToBottom();

    });

    _controller.clear();

    try {
      _chatService.streamChatResponse(prompt: prompt).listen(
            (response) {
          if (response.isReminder) {
            final data = response.reminderData!;
            final task = data['task'] as String;
            final timeUtc = data['scheduled_time_utc'] as String;
            final acknowledgement = data['acknowledgement'] as String;

            _scheduleNativeReminder(task, timeUtc);

            setState(() {
              _messages.add({'text': acknowledgement, 'isUser': false});
              _isLoading = false;
              if (isSpoken==true) {
                print("here");
                flutterTts.speak(acknowledgement);
                isSpoken= false;
              }
              _scrollToBottom();

            });
          } else {
            setState(() {
              _currentTypingText += response.text!;
              _scrollToBottom();
            });
          }
        },
        onError: (error) {
          setState(() {
            _messages.add({'text': 'Error: $error', 'isUser': false});
            _currentTypingText = '';
            _isLoading = false;
          });
        },
        onDone: () {
          if (_currentTypingText.isNotEmpty) {
            setState(()  {
              _messages.add({'text': _currentTypingText, 'isUser': false});
              print(isSpoken);
              if (isSpoken==true) {
                flutterTts.speak(_currentTypingText);
                isSpoken= false;
              }
              _currentTypingText = '';
              _isLoading = false;
              _scrollToBottom();

            });
          }
        },
      );
    } catch (e) {
      setState(() {
        _messages.add({'text': 'Fatal Error: $e', 'isUser': false});
        _isLoading = false;
        _currentTypingText = '';
      });
    }
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
      onError: (error) {
        setState(() => _isListening = false);
        debugPrint('Speech error: $error');
      },
    );
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) {
          setState(() => _controller.text = val.recognizedWords);
          if (val.hasConfidenceRating && val.confidence > 0.8 && val.finalResult) {
            _speech.stop();
            setState(() {
              isSpoken = true;
              _isListening = false;
            });
            _sendMessage();
          }
        },
        listenFor: const Duration(seconds: 10),
      );
    } else {
      setState(() =>_isListening = false);
    }
  }

  void _scrollToBottom() {
    // Delayed to allow UI to build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }


  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.all(12.0),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? Colors.blueAccent : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isUser ? 12 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 12),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 16.0,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            tooltip: 'Go to Chat',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const HomePage(name: "ABK"))
              ); // or pushNamed()
            },
          ),
        ],
        title: const Text(
          "ElderCare",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        centerTitle: true,
        toolbarHeight: 70,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _messages.length + (_currentTypingText.isNotEmpty ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < _messages.length) {
                    final msg = _messages[index];
                    return _buildMessageBubble(msg['text'], msg['isUser']);
                  } else {
                    return _buildMessageBubble(
                      "ElderCare: $_currentTypingText" + (_isLoading ? ' |' : ''),
                      false,
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
                  heroTag: "send_btn",
                  onPressed: _sendMessage,
                  tooltip: 'Send Message',
                  elevation: 2,
                  backgroundColor: Colors.blueAccent,
                  child: _isLoading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Icon(Icons.send),
                ),
                const SizedBox(width: 8.0),
                FloatingActionButton(
                  heroTag: "mic_btn",
                  onPressed: _isListening ? null : _startListening,
                  tooltip: 'Voice Input',
                  elevation: 2,
                  backgroundColor: _isListening ? Colors.grey : Colors.green,
                  child: const Icon(Icons.mic),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }


}
