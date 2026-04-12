import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'history_service.dart';

class MedsScreen extends StatefulWidget {
  final String? initialMemberId; // Admin ke liye auto-select
  const MedsScreen({super.key, this.initialMemberId});

  @override
  State<MedsScreen> createState() => _MedsScreenState();
}

class _MedsScreenState extends State<MedsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _submitting = false;
  List<dynamic> _medications = [];

  // --- Admin & Family State ---
  bool _isAdmin = false;
  String? _selectedMemberId;
  List<dynamic> _familyMembers = [];
  String? _currentGroupId;
  String? _myStatus;

  // --- Controllers ---
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _timeController = TextEditingController();

  // --- Partner's Alarm State ---
  final player = AudioPlayer();
  Timer? timer;
  Set<String> triggeredAlarms = {};
  String statusMessage = "Syncing schedule...";

  @override
  void initState() {
    super.initState();
    _initScreen();
    // Start Alarm Checker Timer (Har 5 second mein check karega)
    timer = Timer.periodic(const Duration(seconds: 5), (_) => _checkAlarms());

    // Agar Admin ne Family Hub se kisi ko select kiya hai, toh auto-open dialog
    if (widget.initialMemberId != null) {
      _selectedMemberId = widget.initialMemberId;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showAddMedDialog());
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    player.dispose();
    _nameController.dispose();
    _dosageController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  // ==========================================
  // 1. DATA FETCHING (Auth, Family, Meds)
  // ==========================================

  Future<void> _initScreen() async {
    await _checkAdminStatus();
    await _fetchMedications();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final memberData = await _supabase
          .from('family_members')
          .select('role, status, group_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (memberData != null) {
        _currentGroupId = memberData['group_id'];
        _isAdmin = (memberData['role'] == 'admin');
        _myStatus = memberData['status'];

        if (_isAdmin) {
          final members = await _supabase
              .from('family_members')
              .select('user_id, profiles(full_name)')
              .eq('group_id', _currentGroupId!);
          
          if (mounted) {
            setState(() {
              _familyMembers = members;
              _selectedMemberId ??= userId; // Default khud par set karo agar null hai
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Admin Check Error: $e');
    }
  }

  Future<void> _fetchMedications() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      var query = _supabase.from('medications').select('*');
      
      // Privacy Logic: Approved hai toh group ka dikhao, warna sirf apna
      if (_myStatus == 'approved' && _currentGroupId != null) {
        query = query.or('user_id.eq.$userId, group_id.eq.${_currentGroupId!}');
      } else {
        query = query.eq('user_id', userId!);
      }

      final data = await query.order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _medications = data;
          statusMessage = "Last updated: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";
        });
      }
    } catch (e) {
      setState(() => statusMessage = "Sync Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // 2. ALARM LOGIC (Partner's Code Integrated)
  // ==========================================

  void _checkAlarms() {
    if (_medications.isEmpty) return;
    final now = DateTime.now();
    final currentTimeStr = "${now.hour}:${now.minute.toString().padLeft(2, '0')}";
    final myUserId = _supabase.auth.currentUser?.id;

    for (var med in _medications) {
      // 1. Agar dawa le li hai, toh skip
      if (med['is_taken'] == true) continue;
      
      // 2. Sirf current user ke phone par alarm baje (Admin set kare toh us bande ke phone par baje)
      if (med['user_id'] != myUserId) continue;

      try {
        final timeStr = med['time']; // Format expected: "08:00 AM"
        final parts = timeStr.split(':');
        int hour = int.parse(parts[0]);
        int minute = int.parse(parts[1].split(' ')[0]);
        
        if (timeStr.contains('PM') && hour != 12) hour += 12;
        if (timeStr.contains('AM') && hour == 12) hour = 0;

        if (now.hour == hour && now.minute == minute) {
          String triggerKey = "${med['id']}_$currentTimeStr";
          if (!triggeredAlarms.contains(triggerKey)) {
            triggeredAlarms.add(triggerKey);
            _triggerAlarm(med);
          }
        }
      } catch (e) {
        // Ignore parse errors for badly formatted times
      }
    }
  }

  void _triggerAlarm(Map med) async {
    try {
      await player.stop();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource('alarm.mp3'));
    } catch (e) {
      debugPrint("Audio error: $e");
    }
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => AlarmScreen(medicine: med, player: player)));
  }

  Future<void> _updateMedicineStatus(String id, bool status) async {
    try {
      await _supabase.from('medications').update({'is_taken': status}).eq('id', id);
      _fetchMedications();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(status ? "✅ Marked as Taken" : "❌ Rejected"), backgroundColor: status ? Colors.green : Colors.red));
    } catch (e) {
      debugPrint("Update error: $e");
    }
  }

  Future<void> _deleteMedication(String id) async {
    try {
      await _supabase.from('medications').delete().eq('id', id);
      _fetchMedications();
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }

  // ==========================================
  // 3. ADD MEDICATION LOGIC
  // ==========================================

  Future<void> _addMedication() async {
    final name = _nameController.text.trim();
    final dosage = _dosageController.text.trim();
    final time = _timeController.text.trim();

    if (name.isEmpty || time.isEmpty) return;
    setState(() => _submitting = true);

    try {
      final userId = _supabase.auth.currentUser?.id;
      final targetUserId = _isAdmin ? (_selectedMemberId ?? userId) : userId;

      await _supabase.from('medications').insert({
        'user_id': targetUserId,
        'group_id': _currentGroupId,
        'name': name,
        'dosage': dosage,
        'time': time,
        'is_taken': false, // By default false
      });

      // HISTORY LOGGING
      String targetName = "themselves";
      if (_isAdmin && targetUserId != userId) {
        final member = _familyMembers.firstWhere((m) => m['user_id'] == targetUserId, orElse: () => {'profiles': {}});
        targetName = member['profiles']?['full_name'] ?? "a member";
      }

      await HistoryService.logAction(
        actionType: 'ALARM',
        description: 'Set $name alarm ($time) for $targetName',
      );

      if (mounted) {
        Navigator.pop(context);
        _nameController.clear(); _dosageController.clear(); _timeController.clear();
        _fetchMedications();
      }
    } catch (e) {
      debugPrint('Add Error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showAddMedDialog() async {
    // Time picker for proper formatting
    TimeOfDay? pickedTime = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (pickedTime != null && mounted) {
      final formattedTime = "${pickedTime.hourOfPeriod == 0 ? 12 : pickedTime.hourOfPeriod}:${pickedTime.minute.toString().padLeft(2, '0')} ${pickedTime.period == DayPeriod.am ? "AM" : "PM"}";
      _timeController.text = formattedTime;
    }

    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Set New Alarm', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isAdmin && _familyMembers.isNotEmpty) ...[
                  const Align(alignment: Alignment.centerLeft, child: Text("Set alarm for:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey))),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedMemberId,
                    decoration: InputDecoration(contentPadding: const EdgeInsets.symmetric(horizontal: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    items: _familyMembers.map((m) => DropdownMenuItem<String>(value: m['user_id'], child: Text(m['profiles']['full_name'] ?? 'Member'))).toList(),
                    onChanged: (val) {
                      setDialogState(() => _selectedMemberId = val);
                      setState(() => _selectedMemberId = val);
                    },
                  ),
                  const SizedBox(height: 20),
                ],
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Medicine Name', prefixIcon: Icon(LucideIcons.pill))),
                const SizedBox(height: 16),
                TextField(controller: _dosageController, decoration: const InputDecoration(labelText: 'Dosage (Optional)', prefixIcon: Icon(LucideIcons.activity))),
                const SizedBox(height: 16),
                TextField(controller: _timeController, readOnly: true, decoration: const InputDecoration(labelText: 'Selected Time', prefixIcon: Icon(LucideIcons.clock))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: _submitting ? null : _addMedication,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white),
              child: Text(_submitting ? 'Saving...' : 'Save Alarm'),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 4. MAIN UI BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Medication Vault', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true, backgroundColor: Colors.white, elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8), width: double.infinity,
            color: const Color(0xFF0EA5E9).withOpacity(0.1),
            child: Text(statusMessage, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9))),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchMedications,
                    child: _medications.isEmpty ? _buildEmptyState() : _buildMedList(),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMedDialog,
        backgroundColor: const Color(0xFF0EA5E9),
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: const Text('Add Alarm', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.pill, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text('No Alarms Set', style: GoogleFonts.poppins(fontSize: 20, color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

Widget _buildMedList() {
  return ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: _medications.length,
    itemBuilder: (context, index) {
      final med = _medications[index];
      final bool isTaken = med['is_taken'] ?? false;

      return StatefulBuilder( // For local scale effect
        builder: (context, setCardState) {
          return MouseRegion( // Hover effect for Web/Desktop
            onEnter: (_) => setCardState(() {}),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 16),
              curve: Curves.easeInOut,
              transform: Matrix4.identity()..scale(1.0), // Hover par 1.05 kar sakte ho
              child: Card(
                elevation: isTaken ? 1 : 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                color: isTaken ? Colors.green.shade50 : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      // WhatsApp Style Profile Icon (CircleAvatar)
                      Hero(
                        tag: 'med-${med['id']}',
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF0EA5E9), width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white,
                            child: Icon(LucideIcons.pill, color: const Color(0xFF0EA5E9), size: 30),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(med['name'], style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, decoration: isTaken ? TextDecoration.lineThrough : null)),
                            Text("${med['dosage'] ?? ''} • ${med['time']}", style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                      // TICK / UNTICK Button
                      IconButton(
                        icon: Icon(
                          isTaken ? LucideIcons.checkCircle2 : LucideIcons.circle,
                          color: isTaken ? Colors.green : Colors.grey,
                          size: 32,
                        ),
                        onPressed: () {
                          // Tick se hi alarm stop hoga aur DB update hoga
                          player.stop(); 
                          _updateMedicineStatus(med['id'].toString(), !isTaken);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
}

// ==========================================
// 5. HELPER CLASSES (Partner's UI)
// ==========================================

class ImagePreviewer extends StatelessWidget {
  final String imageUrl;
  final String name;
  const ImagePreviewer({super.key, required this.imageUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.9),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text(name, style: const TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: Hero(
            tag: imageUrl,
            child: InteractiveViewer(
              child: Image.network(imageUrl, fit: BoxFit.contain, width: double.infinity),
            ),
          ),
        ),
      ),
    );
  }
}

class AlarmScreen extends StatelessWidget {
  final Map medicine;
  final AudioPlayer player;
  const AlarmScreen({super.key, required this.medicine, required this.player});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade700,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notification_important, size: 80, color: Colors.white),
            const SizedBox(height: 20),
            const Text("TIME FOR MEDICINE", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            
            if (medicine['image_url'] != null)
              CircleAvatar(radius: 80, backgroundImage: NetworkImage(medicine['image_url']))
            else
              CircleAvatar(radius: 80, backgroundColor: Colors.white, child: const Icon(LucideIcons.pill, size: 60, color: Colors.red)),
              
            const SizedBox(height: 20),
            Text(medicine['name'] ?? 'Medicine', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            if (medicine['dosage'] != null && medicine['dosage'].toString().isNotEmpty)
              Text(medicine['dosage'], style: const TextStyle(color: Colors.white70, fontSize: 20)),
              
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SizedBox(
                width: double.infinity, height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, shape: const StadiumBorder()),
                  onPressed: () async { await player.stop(); Navigator.pop(context); },
                  child: const Text("STOP ALARM", style: TextStyle(color: Colors.red, fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}