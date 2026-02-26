import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'team_performance_screen.dart';

class TeamListScreen extends StatefulWidget {
  final String eventId;
  final String eventName;
  final bool isAdmin;
  final String category;

  const TeamListScreen({
    super.key,
    required this.eventId,
    required this.eventName,
    required this.isAdmin,
    required this.category,
  });

  @override
  State<TeamListScreen> createState() => _TeamListScreenState();
}

class _TeamListScreenState extends State<TeamListScreen> {
  final DatabaseReference _teamsRef = FirebaseDatabase.instance.ref('teams');

  // 🎨 Palette
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color darkSlate = Color(0xFF1E293B);
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color dangerRed = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        title: Column(
          children: [
            Text(widget.eventName,
                style: const TextStyle(color: darkSlate, fontWeight: FontWeight.w900, fontSize: 18)),
            Text("${widget.category} Division",
                style: TextStyle(color: darkSlate.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: darkSlate, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
        backgroundColor: primaryPurple,
        onPressed: () => _showTeamDialog(),
        label: const Text("REGISTER ENTRY", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
      )
          : null,

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Registered Entries", style: TextStyle(fontWeight: FontWeight.w800, color: darkSlate, fontSize: 15)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: primaryPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Text("Live", style: TextStyle(color: primaryPurple, fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _teamsRef.onValue,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryPurple));
                }

                if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
                  return _emptyState();
                }

                final Map<dynamic, dynamic> data = Map<dynamic, dynamic>.from(snapshot.data!.snapshot.value as Map);

                // 🔹 Fixed: Filtering by both EventId AND Category
                final List<MapEntry<dynamic, dynamic>> filteredTeams = data.entries.where((e) {
                  final teamData = Map<dynamic, dynamic>.from(e.value as Map);
                  return teamData['eventId'] == widget.eventId && teamData['category'] == widget.category;
                }).toList();

                if (filteredTeams.isEmpty) return _emptyState();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(25, 0, 25, 100),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredTeams.length,
                  itemBuilder: (context, index) {
                    final teamEntry = filteredTeams[index];
                    final String teamId = teamEntry.key;
                    final Map teamData = teamEntry.value;
                    final List members = teamData['members'] ?? [];
                    final String captain = teamData['captain'] ?? "N/A";

                    return _teamCard(teamId, teamData['teamName'], captain, members);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- Premium Interactive Team Card ---
  Widget _teamCard(String id, String name, String captain, List members) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 8))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            backgroundColor: Colors.white,
            collapsedBackgroundColor: Colors.white,
            iconColor: primaryPurple,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: primaryPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
              child: Icon(members.length > 1 ? Icons.groups_rounded : Icons.person_rounded, color: primaryPurple, size: 24),
            ),
            title: Text(name, style: const TextStyle(color: darkSlate, fontWeight: FontWeight.w900, fontSize: 17)),
            subtitle: Text(captain == "N/A" ? "Individual Participant" : "Captain: $captain",
                style: TextStyle(color: darkSlate.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w600)),
            trailing: widget.isAdmin
                ? IconButton(
              icon: const Icon(Icons.settings_suggest_rounded, color: Colors.blueGrey, size: 22),
              onPressed: () => _showOptionsBottomSheet(id, name),
            )
                : const Icon(Icons.unfold_more_rounded, size: 18, color: Colors.black12),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 5, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 30, thickness: 0.5),
                    const Row(
                      children: [
                        Icon(Icons.badge_outlined, size: 14, color: primaryPurple),
                        SizedBox(width: 8),
                        Text("ROSTER / SQUAD", style: TextStyle(color: primaryPurple, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: members.map((m) => _memberChip(m.toString())).toList(),
                    ),
                    const SizedBox(height: 25),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 0,
                        ),
                        onPressed: () => _navigateToScoreboard(name, members),
                        icon: const Icon(Icons.analytics_rounded, size: 18),
                        label: const Text("OPEN PERFORMANCE TRACKER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔹 New: Confirm Delete Logic
  void _confirmDeleteTeam(String teamId, String teamName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text("Delete Entry?", style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text("Are you sure you want to remove '$teamName' from the event? This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: dangerRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              _teamsRef.child(teamId).remove();
              Navigator.pop(context); // Close Dialog
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("$teamName removed successfully"), behavior: SnackBarBehavior.floating),
              );
            },
            child: const Text("DELETE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showOptionsBottomSheet(String teamId, String teamName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(35))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 25),
            const Text("Entry Management", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: darkSlate)),
            const SizedBox(height: 20),
            _actionTile(Icons.edit_rounded, "Update Information", Colors.blue, () {
              Navigator.pop(context);
              _showTeamDialog(teamId: teamId);
            }),
            // 🔹 Modified: Call Confirmation Dialog instead of immediate delete
            _actionTile(Icons.delete_sweep_rounded, "Remove Entry", dangerRed, () {
              Navigator.pop(context);
              _confirmDeleteTeam(teamId, teamName);
            }),
          ],
        ),
      ),
    );
  }

  // --- Baqi Helper Widgets (No Change) ---
  void _navigateToScoreboard(String name, List members) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => TeamPerformanceScreen(
      teamName: name, gameName: widget.eventName, category: widget.category,
      isAdmin: widget.isAdmin, teamMembers: members.map((m) => m.toString()).toList(),
    )));
  }

  Widget _actionTile(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: darkSlate)),
      onTap: onTap,
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
    );
  }

  void _showTeamDialog({String? teamId}) {
    final TextEditingController teamController = TextEditingController();
    final TextEditingController captainController = TextEditingController();
    List<TextEditingController> memberControllers = [TextEditingController()];

    if (teamId != null) {
      _teamsRef.child(teamId).get().then((snap) {
        if (snap.value != null) {
          final data = Map<dynamic, dynamic>.from(snap.value as Map);
          teamController.text = data['teamName'] ?? "";
          captainController.text = data['captain'] == "N/A" ? "" : data['captain'] ?? "";
          List members = data['members'] ?? [];
          if (members.isNotEmpty) {
            memberControllers = members.map((m) => TextEditingController(text: m.toString())).toList();
          }
          if (mounted) setState(() {});
        }
      });
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          title: Text(teamId == null ? "Register Entry" : "Modify Record", style: const TextStyle(fontWeight: FontWeight.w900, color: darkSlate)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dialogField(teamController, "Entry Name", Icons.emoji_events_rounded),
                  const SizedBox(height: 15),
                  _dialogField(captainController, "Captain Name", Icons.stars_rounded),
                  const SizedBox(height: 25),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("MEMBERS", style: TextStyle(fontWeight: FontWeight.w900, color: primaryPurple, fontSize: 12)),
                      IconButton(icon: const Icon(Icons.add_circle_rounded, color: primaryPurple), onPressed: () => setDialogState(() => memberControllers.add(TextEditingController()))),
                    ],
                  ),
                  ...memberControllers.asMap().entries.map((entry) {
                    int index = entry.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(child: _dialogField(memberControllers[index], "Player ${index + 1}", Icons.person_outline_rounded)),
                          if (memberControllers.length > 1)
                            IconButton(icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 22), onPressed: () => setDialogState(() => memberControllers.removeAt(index))),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryPurple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
              onPressed: () {
                List<String> members = memberControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
                if (teamController.text.isNotEmpty && members.isNotEmpty) {
                  final data = {
                    'teamName': teamController.text.trim(),
                    'captain': captainController.text.isEmpty ? "N/A" : captainController.text.trim(),
                    'members': members,
                    'eventId': widget.eventId,
                    'category': widget.category,
                    'lastUpdated': DateTime.now().millisecondsSinceEpoch,
                  };
                  teamId == null ? _teamsRef.push().set(data) : _teamsRef.child(teamId).update(data);
                  Navigator.pop(context);
                }
              },
              child: const Text("Confirm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryPurple, size: 20),
        filled: true,
        fillColor: lightBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _memberChip(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: lightBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black.withOpacity(0.05))),
      child: Text(name, style: const TextStyle(color: darkSlate, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.diversity_3_rounded, size: 80, color: darkSlate.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text("No entries for ${widget.eventName} yet.", style: TextStyle(color: darkSlate.withOpacity(0.3), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}