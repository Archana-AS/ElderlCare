import 'package:elder_care/screens/test.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  final String name;
  const HomePage({super.key, required this.name});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _expandedIndex = 0; // first section open by default

  @override
  Widget build(BuildContext context) {
    final sections = [
      {
        "title": "My Health Stats",
        "icon": Icons.favorite,
        "color": const Color(0xFF4CAF50), // Green
        "content": [
          {"text": "Steps today: 3,500", "icon": Icons.directions_walk},
          {"text": "Water intake: 3 glasses", "icon": Icons.water_drop},
          {"text": "Sleep: 7 hours", "icon": Icons.bedtime},
        ]
      },
      {
        "title": "My Reminders",
        "icon": Icons.alarm,
        "color": const Color(0xFF2196F3), // Blue
        "content": [
          {"text": "Take medicine at 9:00 AM", "icon": Icons.medication},
          {"text": "Drink water at 11:00 AM", "icon": Icons.local_drink},
          {"text": "Doctor appointment at 5:00 PM", "icon": Icons.local_hospital},
        ]
      },
      {
        "title": "Emergency Contact",
        "icon": Icons.emergency,
        "color": const Color(0xFFFF5722), // Red-Orange
        "content": [
          {"text": "John Doe", "icon": Icons.person},
          {"text": "+1 234 567 890", "icon": Icons.phone},
        ]
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF6C63FF),
        foregroundColor: Colors.white,
        actions: [
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
      body: SingleChildScrollView(
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

                    // Content
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      height: isExpanded
                          ? (section["content"] as List).length * 70.0 + 20
                          : 0,
                      child: ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          maxHeight: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.only(
                                left: 20, right: 20, bottom: 20
                            ),
                            child: Column(
                              children: (section["content"] as List<Map<String, dynamic>>)
                                  .map((item) => Container(
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
                                        item["text"] as String,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          color: Color(0xFF4A5568),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
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
    );
  }
}