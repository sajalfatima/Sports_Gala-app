import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'match_detail_scorecard.dart';

class TeamPerformanceScreen extends StatefulWidget {
  final String? teamName;
  final String? opponentName;
  final String? matchId;
  final String? gameName;
  final String? category;
  final bool isAdmin;
  final List<String>? teamMembers;

  const TeamPerformanceScreen({
    super.key,
    this.teamName,
    this.opponentName,
    this.matchId,
    this.gameName,
    this.category,
    required this.isAdmin,
    this.teamMembers,
  });

  @override
  State<TeamPerformanceScreen> createState() => _TeamPerformanceScreenState();
}

class _TeamPerformanceScreenState extends State<TeamPerformanceScreen> {
  late DatabaseReference _statusRef;
  late DatabaseReference _teamsListRef;
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  final _runsCtrl = TextEditingController();
  final _batsmanCtrl = TextEditingController();
  final _bowlerCtrl = TextEditingController();
  final _overCtrl = TextEditingController(text: "0");
  final _ballCtrl = TextEditingController(text: "1");
  final _targetCtrl = TextEditingController();
  final _totalOversCtrl = TextEditingController();

  bool isOut = false;
  String? editingKey;
  bool isMatchFinished = false;
  String? selectedOpponent;
  List<String> opponentTeamsList = [];
  int targetScore = 0;
  int totalMatchOvers = 0;

  @override
  void initState() {
    super.initState();
    selectedOpponent = widget.opponentName;

    // 🔥 FIX: Match-specific references using matchId
    _statusRef = _db.child('schedules/${widget.matchId}');
    _teamsListRef = _db.child('teams');

    _loadMatchData();
    _fetchRegisteredTeams();
  }

  // 🔥 FIX: Score node ab matchId ke andar hoga, overlap nahi karega
  DatabaseReference get _sharedScoreRef {
    return _db.child('match_scores/${widget.matchId}');
  }

  void _loadMatchData() {
    _statusRef.onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        setState(() {
          String status = data['status']?.toString() ?? "Pending";

          // 🔥 UPDATE: Played aur Drawn par bhi scoring lock hogi
          isMatchFinished = (status == "Finished" ||
              status == "Played" ||
              status == "Drawn" ||
              data['isFinished'] == true);

          selectedOpponent = data['opponent'] ?? widget.opponentName;
          targetScore = int.tryParse(data['target']?.toString() ?? "0") ?? 0;
          totalMatchOvers = int.tryParse(data['totalOvers']?.toString() ?? "0") ?? 0;

          if (targetScore > 0) _targetCtrl.text = targetScore.toString();
          if (totalMatchOvers > 0) _totalOversCtrl.text = totalMatchOvers.toString();
        });
      }
    });
  }

  void _finishMatch() async {
    String? localSelectedPotm;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("🏆 Select POTM", style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Award Player of the Match:"),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              decoration: _deco("Select Player"),
              items: (widget.teamMembers ?? []).map((p) =>
                  DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) => localSelectedPotm = v,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              if (localSelectedPotm == null) {
                _showMsg("Please select a player!", Colors.red);
                return;
              }
              Navigator.pop(context);
              _saveFinalData(localSelectedPotm!);
            },
            child: const Text("FINISH"),
          ),
        ],
      ),
    );
  }

  void _saveFinalData(String potmName) async {
    setState(() => isMatchFinished = true);

    // Update Schedule Node for Analytics & Global Status
    if (widget.matchId != null) {
      await _statusRef.update({
        'status': 'Finished',
        'potm': potmName,
        'winner': widget.teamName,
        'timestamp': ServerValue.timestamp,
        'isFinished': true,
      });
    }
    _showMsg("Match Finished & Analytics Updated!", Colors.purple);
  }

  void _fetchRegisteredTeams() {
    _teamsListRef.onValue.listen((event) {
      if (event.snapshot.value != null && mounted) {
        List<String> tempTeams = [];
        Map map = event.snapshot.value as Map;
        map.forEach((k, v) {
          String? name = v['teamName']?.toString();
          if (v['category'] == widget.category && name != null && name != widget.teamName) {
            tempTeams.add(name);
          }
        });
        setState(() => opponentTeamsList = tempTeams.toSet().toList());
      }
    });
  }

  void _updateBallCounter() {
    int currentBall = int.tryParse(_ballCtrl.text) ?? 1;
    int currentOver = int.tryParse(_overCtrl.text) ?? 0;
    if (currentBall >= 6) {
      _ballCtrl.text = "1";
      _overCtrl.text = (currentOver + 1).toString();
    } else {
      _ballCtrl.text = (currentBall + 1).toString();
    }
  }

  void _submitData() async {
    if (isMatchFinished || selectedOpponent == null) return;
    if (_batsmanCtrl.text.isEmpty || _bowlerCtrl.text.isEmpty || _runsCtrl.text.isEmpty) return;

    if (widget.isAdmin) {
      await _statusRef.update({
        'opponent': selectedOpponent,
        'target': _targetCtrl.text,
        'totalOvers': _totalOversCtrl.text,
      });
    }

    Map<String, dynamic> ballData = {
      'runs': _runsCtrl.text,
      'isOut': isOut,
      'batsman': _batsmanCtrl.text,
      'bowler': _bowlerCtrl.text,
      'over': _overCtrl.text,
      'ball': _ballCtrl.text,
      'timestamp': editingKey == null ? ServerValue.timestamp : null,
      'battingTeam': widget.teamName,
    };

    if (editingKey == null) {
      await _sharedScoreRef.push().set(ballData);
      _updateBallCounter();
    } else {
      await _sharedScoreRef.child(editingKey!).update(ballData);
    }
    _runsCtrl.clear();
    setState(() { isOut = false; editingKey = null; });
  }

  void _showMsg(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3FF),
      appBar: AppBar(
        centerTitle: true,
        elevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: Colors.deepPurple,
        title: InkWell(
          onTap: () {
            if (selectedOpponent != null) {
              Navigator.push(context, MaterialPageRoute(builder: (c) => MatchDetailScorecard(
                gameName: widget.gameName!,
                category: widget.category!,
                team1: widget.teamName!,
                team2: selectedOpponent!,
                matchId: widget.matchId, // 🔥 FIX: matchId lazmi bhejna hai taake data load ho
              )));
            }
          },
          child: Column(
            children: [
              const Text("LIVE SCORING", style: TextStyle(fontSize: 10, letterSpacing: 2, color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold)),
              Text("${widget.teamName} vs ${selectedOpponent ?? '...'}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: _sharedScoreRef.onValue,
        builder: (context, snapshot) {
          int runs = 0, wickets = 0;
          List<MapEntry<dynamic, dynamic>> items = [];
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            Map data = snapshot.data!.snapshot.value as Map;

            items = data.entries.toList()..sort((a, b) {
              var t1 = a.value['timestamp'] ?? 0;
              var t2 = b.value['timestamp'] ?? 0;
              return t2.compareTo(t1);
            });

            for (var i in items) {
              if (i.value['battingTeam'] == widget.teamName) {
                runs += int.tryParse(i.value['runs'].toString()) ?? 0;
                if (i.value['isOut'] == true) wickets++;
              }
            }
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildScoreCard(runs, wickets),
                const SizedBox(height: 20),
                if (widget.isAdmin && !isMatchFinished) _buildScorerForm(runs)
                else if (isMatchFinished) _buildFinishedLock(),
                const SizedBox(height: 25),
                const Row(
                  children: [
                    Icon(Icons.history_toggle_off, color: Colors.deepPurple, size: 20),
                    SizedBox(width: 8),
                    Text("BALL BY BALL FEED", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.deepPurple)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildHistoryList(items),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFinishedLock() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
    child: const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_clock_outlined, color: Colors.amber),
        SizedBox(width: 10),
        Text("Match Ended - Scoring Disabled", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
      ],
    ),
  );

  Widget _buildScoreCard(int r, int w) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _teamNameBox(widget.teamName ?? "TEAM A"),
              const Text("VS", style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w900, fontSize: 16)),
              _teamNameBox(selectedOpponent ?? "TEAM B"),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 15), child: Divider(color: Colors.white24)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("TOTAL RUNS", style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                  Text("$r/$w", style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.bold)),
                ],
              ),
              if (targetScore > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("TARGET", style: TextStyle(color: Colors.amberAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    Text("$targetScore", style: const TextStyle(color: Colors.amberAccent, fontSize: 36, fontWeight: FontWeight.bold)),
                  ],
                ),
            ],
          ),
          if (isMatchFinished)
            Container(
              margin: const EdgeInsets.only(top: 15),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(50)),
              child: const Text("MATCH FINISHED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            )
        ],
      ),
    );
  }

  Widget _teamNameBox(String name) {
    return Expanded(
      child: Text(name.toUpperCase(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1), maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  Widget _buildScorerForm(int currentRuns) {
    bool canFinish = isMatchFinished || (targetScore > 0 && currentRuns >= targetScore);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.deepPurple.withOpacity(0.05), blurRadius: 10)], border: Border.all(color: Colors.deepPurple.shade50)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(flex: 2, child: DropdownButtonFormField<String>(
                value: opponentTeamsList.contains(selectedOpponent) ? selectedOpponent : null,
                items: opponentTeamsList.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (v) => setState(() { selectedOpponent = v; _bowlerCtrl.clear(); }),
                decoration: _deco("Opponent Team"),
              )),
              const SizedBox(width: 8),
              Expanded(child: _input(_targetCtrl, "Target")),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(flex: 2, child: DropdownButtonFormField<String>(
                value: (widget.teamMembers != null && widget.teamMembers!.contains(_batsmanCtrl.text)) ? _batsmanCtrl.text : null,
                items: (widget.teamMembers ?? []).map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (v) => setState(() => _batsmanCtrl.text = v ?? ""),
                decoration: _deco("Batsman"),
              )),
              const SizedBox(width: 8),
              Expanded(child: _input(_runsCtrl, "Runs")),
              const SizedBox(width: 8),
              _outToggle(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(flex: 2, child: StreamBuilder<DatabaseEvent>(
                  stream: _teamsListRef.onValue,
                  builder: (context, snapshot) {
                    List<String> bPlayers = [];
                    if (snapshot.hasData && snapshot.data!.snapshot.value != null && selectedOpponent != null) {
                      Map map = snapshot.data!.snapshot.value as Map;
                      map.forEach((k, v) {
                        if (v['teamName'].toString().trim() == selectedOpponent!.trim() && v['category'] == widget.category) {
                          bPlayers = List<String>.from(v['members'] ?? []);
                        }
                      });
                    }
                    return DropdownButtonFormField<String>(
                      key: ValueKey(selectedOpponent),
                      value: bPlayers.contains(_bowlerCtrl.text) ? _bowlerCtrl.text : null,
                      items: bPlayers.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12)))).toList(),
                      onChanged: (v) => setState(() => _bowlerCtrl.text = v ?? ""),
                      decoration: _deco("Bowler"),
                    );
                  }
              )),
              const SizedBox(width: 8),
              Expanded(child: _input(_overCtrl, "Over")),
              const SizedBox(width: 8),
              Expanded(child: _input(_ballCtrl, "Ball")),
            ],
          ),
          const SizedBox(height: 20),
          if (!isMatchFinished)
            ElevatedButton(
              onPressed: _submitData,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              child: Text(editingKey == null ? "SUBMIT BALL" : "UPDATE BALL", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          if (canFinish && !isMatchFinished)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: ElevatedButton.icon(
                onPressed: _finishMatch,
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text("FINISH MATCH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: const Size(double.infinity, 45)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _outToggle() {
    return Column(
      children: [
        const Text("OUT", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.redAccent)),
        Checkbox(value: isOut, onChanged: (v) => setState(() => isOut = v!), activeColor: Colors.redAccent, visualDensity: VisualDensity.compact),
      ],
    );
  }

  Widget _buildHistoryList(List<MapEntry<dynamic, dynamic>> items) {
    return ListView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        var ball = items[index].value;
        String key = items[index].key;
        String bName = ball['batsman'] ?? "Unknown";
        int bTotal = _getBatsmanTotal(items, bName);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.deepPurple.shade50)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: ball['isOut'] ? Colors.redAccent : Colors.deepPurple.shade50,
              child: Text("${ball['runs']}", style: TextStyle(color: ball['isOut'] ? Colors.white : Colors.deepPurple, fontWeight: FontWeight.bold)),
            ),
            title: Text("$bName ($bTotal) • ${ball['bowler']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
            subtitle: Text("Over ${ball['over']}.${ball['ball']} ${ball['isOut'] ? '• WICKET' : ''}", style: TextStyle(color: Colors.grey.shade600)),
            trailing: widget.isAdmin && !isMatchFinished ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit_note, size: 20, color: Colors.deepPurpleAccent), onPressed: () {
                  setState(() {
                    editingKey = key;
                    _runsCtrl.text = ball['runs'].toString();
                    _batsmanCtrl.text = bName;
                    _bowlerCtrl.text = ball['bowler'].toString();
                    _overCtrl.text = ball['over'].toString();
                    _ballCtrl.text = ball['ball'].toString();
                    isOut = ball['isOut'] ?? false;
                  });
                }),
                IconButton(icon: Icon(Icons.delete_sweep_outlined, size: 20, color: Colors.red.shade300),
                    onPressed: () => _sharedScoreRef.child(key).remove()),
              ],
            ) : null,
          ),
        );
      },
    );
  }

  int _getBatsmanTotal(List<MapEntry<dynamic, dynamic>> items, String name) {
    int total = 0;
    for (var i in items) {
      if (i.value['batsman'] == name && i.value['battingTeam'] == widget.teamName) {
        total += int.tryParse(i.value['runs'].toString()) ?? 0;
      }
    }
    return total;
  }

  InputDecoration _deco(String label) => InputDecoration(
    labelText: label, labelStyle: const TextStyle(fontSize: 11, color: Colors.deepPurple),
    filled: true, fillColor: const Color(0xFFF5F3FF),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 1)),
  );

  Widget _input(TextEditingController ctrl, String label) => TextField(
    controller: ctrl, keyboardType: TextInputType.number,
    cursorColor: Colors.deepPurple,
    decoration: _deco(label),
  );
}