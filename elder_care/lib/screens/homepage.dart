import 'dart:convert';

import 'package:elder_care/screens/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../core/api/urlfinder.dart';
import 'package:timezone/timezone.dart' as tz;

class HomePage extends StatefulWidget {
  final String name;
  const HomePage({super.key, required this.name});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _expandedIndex = 0; // first section open by default
  List<Map<String, dynamic>> sections = [];
  String url='';
  bool _isLoading = true;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  //------------------------------------
  Future<List<Map<String, dynamic>>> fetchHealthStatsFromApi() async {
    String healthStatsApiUrl = '$url/health';
    return [
      {"text": "Steps today: 3,500", "icon": Icons.directions_walk},
      {"text": "Water intake: 3 glasses", "icon": Icons.water_drop},
      {"text": "Sleep: 7 hours", "icon": Icons.bedtime},
    ];
  }
  Future<void> scheduleNativeReminderNew(int notifId,String task, DateTime scheduledDateTime) async {
    try {
      final tz.TZDateTime scheduledTZDateTime = tz.TZDateTime.from(scheduledDateTime, tz.local);

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
        notifId,
        'Reminder: $task',
        'Time to complete your task!',
        scheduledTZDateTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'task_payload_$notifId',
      );

      print('✅ Notification scheduled successfully for $scheduledTZDateTime');
    } catch (e) {
      print('❌ Error scheduling notification: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchRemindersFromApi() async {
    String reminderURL = '$url/reminders';
    final response = await http.get(Uri.parse(reminderURL));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body); // ✅ dynamic first
      return data.map((item) => {
        "text": item["text"],
        "time": item["time"],
        "icon": Icons.alarm,
      }).toList();
    }
    return [];
    // [
    //   {"text": "Take medicine at 9:00 AM","time": "2025-09-29T03:30:00Z"},
    //   {"text": "Drink water at 11:00 AM","time": "2025-09-29T05:30:00Z"},
    //   {"text": "Doctor appointment at 5:00 PM", "time": "2025-09-29T11:30:00Z"}
    // ]

  }

  Future<List<Map<String, dynamic>>> fetchEmergencyContactsFromApi() async {
    String emergencyURL = '$url/emergency';

    final response = await http.get(Uri.parse(emergencyURL));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body); // ✅ dynamic first
      return data.map((item) => {
        "text": item["name"],
        "number": item["number"].toString(), // Convert to string
        "icon": Icons.call,
      }).toList();
      // [
      //   {"name": "Abk","number": "888888888"},
      //   {"name": "Abk","number": "888888888"},
      // ]
    }
    return [];
  }
//----------------------------------

  Future<void> fetchSections() async {
    setState(() => _isLoading = true);
    try {
      final healthStats = await fetchHealthStatsFromApi();
      final reminders = await fetchRemindersFromApi();
      final emergencyContacts = await fetchEmergencyContactsFromApi();

      sections = [
        {
          "title": "My Health Stats",
          "icon": Icons.favorite,
          "color": const Color(0xFF4CAF50),
          "content": healthStats,
        },
        {
          "title": "My Reminders",
          "icon": Icons.alarm,
          "color": const Color(0xFF2196F3),
          "content": reminders,
        },
        {
          "title": "Emergency Contact",
          "icon": Icons.emergency,
          "color": const Color(0xFFFF5722),
          "content": emergencyContacts,
        },
      ];
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error fetching data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> initApp() async {
    url = await getPublicUrl();
    await fetchSections();
    setState(() {});
  }

  void _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  void _sendSMS(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  void _showAddEmergencyContactDialog() {
    final nameController = TextEditingController();
    final numberController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Emergency Contact'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: numberController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final emergencyAddUrl = Uri.parse('$url/emergencyAdd');
                //print('Emergency Contact - Name: ${nameController.text}, Number: ${numberController.text}');
                final response = await http.post(
                  emergencyAddUrl,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'name': nameController.text,
                    'number': numberController.text,
                  }),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Emergency contact added")),
                );
                Navigator.pop(context);


                await fetchSections();
                setState(() {});
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _showAddReminderDialog() {
    final taskController = TextEditingController();
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Reminder'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: taskController,
                    decoration: const InputDecoration(
                      labelText: 'Task',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedTime = picked;
                        });
                      }
                    },
                    child: Text(
                      selectedTime != null
                          ? 'Time: ${selectedTime!.format(context)}'
                          : 'Select Time',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedTime != null) {
                      final now = DateTime.now();
                      var localDateTime = DateTime(
                        now.year,
                        now.month,
                        now.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      );
                      if (localDateTime.isBefore(now)) {
                        localDateTime = localDateTime.add(const Duration(days: 1));
                      }
                      final utcDateTime = localDateTime.toUtc();
                      final isoUtcTime = utcDateTime.toIso8601String();
                      final taskText = taskController.text.trim();

                      final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

                      await scheduleNativeReminderNew(notificationId, taskText, localDateTime);

                      if (taskText.isNotEmpty) {
                        final emergencyAddUrl = Uri.parse('$url/reminderAdd');
                        final response = await http.post(
                          emergencyAddUrl,
                          headers: {'Content-Type': 'application/json'},
                          body: jsonEncode({
                            "notifid":notificationId.toInt(),
                            'task': "$taskText at ${selectedTime?.format(context)}",
                            'time': isoUtcTime,
                          }),
                        );
                        Navigator.pop(context);

                        await fetchSections();
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Reminder added")),
                        );
                      }else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please enter a task name")),
                        );
                      }

                    }
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    initApp();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_alert),
            tooltip: 'Test Add Reminder',
            onPressed: _showAddReminderDialog,
          ),
          IconButton(
            icon: const Icon(Icons.contact_phone),
            tooltip: 'Test Add Contact',
            onPressed: _showAddEmergencyContactDialog,
          ),
          IconButton(
            icon: const Icon(Icons.chat),
            tooltip: 'Go to Chat',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const ChatScreen())
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: fetchSections,
        color: const Color(0xFF6C63FF),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.waving_hand,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Welcome back,",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      widget.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Have a wonderful day!",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),

              // Custom Accordion-style Cards
              ...List.generate(sections.length, (index) {
                final section = sections[index];
                final isExpanded = _expandedIndex == index;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Header
                      InkWell(
                        onTap: () {
                          setState(() {
                            _expandedIndex = isExpanded ? -1 : index;
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: (section["color"] as Color).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: section["color"] as Color,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  section["icon"] as IconData,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  section["title"] as String,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                              ),
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 28,
                                color: section["color"] as Color,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Content with AnimatedSize
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: isExpanded
                            ? Padding(
                          padding: const EdgeInsets.only(
                              left: 20, right: 20, top: 12, bottom: 20
                          ),
                          child: Column(
                            children: (section["content"] as List<Map<String, dynamic>>)
                                .map((item) {
                              // Check if this is Emergency Contact section
                              bool isEmergencyContact = section["title"] == "Emergency Contact";

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: (section["color"] as Color).withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      item["icon"] as IconData,
                                      color: section["color"] as Color,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        "${item["text"]}${ item["number"] != null ? '\n(${item["number"]})' : ''}",
                                        style: const TextStyle(
                                          fontSize: 17,
                                          color: Color(0xFF4A5568),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (isEmergencyContact) ...[
                                      IconButton(
                                        icon: const Icon(Icons.phone),
                                        color: const Color(0xFF4CAF50),
                                        onPressed: () => _makePhoneCall(item["number"].toString()),
                                        tooltip: 'Call',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.sms),
                                        color: const Color(0xFF2196F3),
                                        onPressed: () => _sendSMS(item["number"].toString()),
                                        tooltip: 'SMS',
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            })
                                .toList(),
                          ),
                        )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                );
              }),

              // Bottom spacing
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}