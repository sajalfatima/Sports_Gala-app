import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'team_list_screen.dart';

class TeamsScreen extends StatefulWidget {
  final bool isAdmin;
  const TeamsScreen({super.key, required this.isAdmin});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  final DatabaseReference _eventsRef = FirebaseDatabase.instance.ref().child('events');
  String selectedTab = "Boys";

  // 🎨 Syncing with Global Theme
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color darkSlate = Color(0xFF1E293B);
  static const Color lightBg = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
      // 🔹 Custom Minimal App Bar
      appBar: AppBar(
        title: const Text("Participating Teams",
            style: TextStyle(color: darkSlate, fontWeight: FontWeight.w900, fontSize: 20)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkSlate, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 🔹 Header Subtitle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 5),
            child: Text(
              "First select a sport category to see its registered teams.",
              textAlign: TextAlign.center,
              style: TextStyle(color: darkSlate.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),

          // 🔹 Premium Toggle Switcher
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 4))
              ],
            ),
            child: Row(
              children: [
                _buildToggleButton("Boys"),
                _buildToggleButton("Girls"),
              ],
            ),
          ),

          // 🔹 Event Selection List
          Expanded(
            child: StreamBuilder(
              stream: _eventsRef.onValue,
              builder: (context, AsyncSnapshot<DatabaseEvent> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryPurple));
                }

                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return _buildEmptyMsg();
                }

                Map<dynamic, dynamic> map = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                List<Map<dynamic, dynamic>> events = [];

                map.forEach((key, value) {
                  var eventData = Map<dynamic, dynamic>.from(value);
                  eventData['key'] = key;
                  if (eventData['category'].toString().toLowerCase() == selectedTab.toLowerCase()) {
                    events.add(eventData);
                  }
                });

                if (events.isEmpty) return _buildEmptyMsg();

                return ListView.builder(
                  itemCount: events.length,
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                  physics: const BouncingScrollPhysics(),
                  itemBuilder: (context, index) => _eventSelectionCard(events[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Professional Event Selection Card ---
  Widget _eventSelectionCard(Map<dynamic, dynamic> event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 8))
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeamListScreen(
                eventId: event['key'],
                eventName: event['name'] ?? "Unnamed Event",
                isAdmin: widget.isAdmin,
                category: selectedTab,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              // Event Icon with Soft Glow
              Container(
                height: 55, width: 55,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primaryPurple.withOpacity(0.1), primaryPurple.withOpacity(0.02)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.groups_3_rounded, color: primaryPurple, size: 28),
              ),
              const SizedBox(width: 18),

              // Text Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event['name'] ?? "Unnamed Sport",
                      style: const TextStyle(color: darkSlate, fontWeight: FontWeight.w800, fontSize: 17),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, color: Colors.orange.withOpacity(0.6), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          event['venue'] ?? "No Venue Set",
                          style: TextStyle(color: darkSlate.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Selection Indicator
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: lightBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: primaryPurple),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Animated Toggle Switch ---
  Widget _buildToggleButton(String title) {
    bool isSelected = selectedTab == title;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = title),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? primaryPurple : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: isSelected
                ? [BoxShadow(color: primaryPurple.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))]
                : null,
          ),
          child: Center(
            child: Text(
              "$title Sports",
              style: TextStyle(
                color: isSelected ? Colors.white : darkSlate.withOpacity(0.4),
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Empty State UI ---
  Widget _buildEmptyMsg() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_rounded, size: 70, color: darkSlate.withOpacity(0.05)),
          const SizedBox(height: 15),
          Text(
            "No $selectedTab events available.",
            style: TextStyle(color: darkSlate.withOpacity(0.3), fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}