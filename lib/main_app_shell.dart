import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:audioplayers/audioplayers.dart';

import 'family_hub_screen.dart';
import 'vitals_screen.dart';
import 'meds_screen.dart';
import 'prescription_screen.dart';
import 'history_service.dart';

// ==========================================
// 1. MAIN APP SHELL (Navigation + Alarm Logic)
// ==========================================
class MainAppShell extends StatefulWidget {
  const MainAppShell({super.key});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  int _currentIndex = 0;
  late final List<Widget> _pages;
  
  final _supabase = Supabase.instance.client;
  final _audioPlayer = AudioPlayer();
  Timer? _alarmCheckTimer;
  final Set<String> _triggeredToday = {};
  String _lastResetDate = '';
  final Map<String, Future<void>> _pendingReminders = {}; 

  @override
  void initState() {
    super.initState();
    
    // Tab Pages Definition
    _pages = [
      HomeScreen(onTabChange: (index) => setState(() => _currentIndex = index)), // Tab 0
      const MedsScreen(),           // Tab 1
      const VitalsScreen(),         // Tab 2
      const PrescriptionScreen(),   // Tab 3
      const FamilyHubScreen(),      // Tab 4
    ];

    // 🔥 Global Alarm Checker (Every 5 seconds)
    _alarmCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkAlarms());
  }

  @override
  void dispose() {
    _alarmCheckTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // --- Alarm Logic ---
  Future<void> _checkAlarms() async {
    // Reset triggered alarms at midnight
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (_lastResetDate != today) {
      _triggeredToday.clear();
      _lastResetDate = today;
    }

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('medications')
          .select('*')
          .eq('user_id', user.id)
          .eq('is_taken', false);

      final now = DateTime.now();
      final currentMinute = now.hour * 60 + now.minute;

      for (var med in data) {
        String medTime = med['time'] ?? ""; 
        final medMinute = _parseTimeToMinutes(medTime);
        
        // Check if within 1 minute window (accounts for 5-second polling)
        if ((currentMinute - medMinute).abs() <= 1) {
          String alarmId = "${med['id']}_${now.hour}_${now.minute}";
          
          if (!_triggeredToday.contains(alarmId)) {
            _triggeredToday.add(alarmId);
            _triggerInAppAlarm(med);
          }
        }
      }
    } catch (e) {
      debugPrint("Alarm Check Error: $e");
    }
  }

  int _parseTimeToMinutes(String timeStr) {
    // Handle "02:30 PM" or "2:30 PM" or "14:30" formats
    try {
      final parts = timeStr.trim().toUpperCase().split(' ');
      if (parts.length == 2) {
        final timeParts = parts[0].split(':');
        var hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final period = parts[1];
        
        if (period == 'PM' && hour != 12) hour += 12;
        if (period == 'AM' && hour == 12) hour = 0;
        return hour * 60 + minute;
      } else if (parts.length == 1 && timeStr.contains(':')) {
        // Handle 24h format "14:30"
        final timeParts = timeStr.split(':');
        return int.parse(timeParts[0]) * 60 + int.parse(timeParts[1]);
      }
    } catch (e) {
      debugPrint('Time parse error for "$timeStr": $e');
    }
    return -1;
  }

  void _triggerInAppAlarm(Map<String, dynamic> med) async {
    if (!mounted) return;
    
    // 1. Show UI overlay immediately
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (context, _, __) => AlarmOverlay(
        medicine: med, 
        player: _audioPlayer,
        onActionTaken: () => setState(() {}),
        pendingReminders: _pendingReminders,
        onRemindLater: (medId) {
          final reminderKey = '${medId}_${DateTime.now().millisecondsSinceEpoch}';
          _pendingReminders[reminderKey] = Future.delayed(
            const Duration(minutes: 15),
            () {
              _pendingReminders.remove(reminderKey);
              _triggerInAppAlarm(med);
            },
          );
        },
      ),
    );

    // 2. Setup and play audio
    try {
      await _audioPlayer.stop();
      
      // Ensure audio plays loudly like an alarm, bypassing silent mode if possible
      await _audioPlayer.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.gainTransientExclusive,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.mixWithOthers},
        ),
      ));

      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      // AssetSource automatically prefixes 'assets/', so this maps to 'assets/alarm.mp3'
      await _audioPlayer.play(AssetSource('alarm.mp3')); 
    } catch (e) {
      debugPrint("Audio Play Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF0EA5E9),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(LucideIcons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.pill), label: 'Meds'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.activity), label: 'Vitals'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.folderLock), label: 'Vault'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.users), label: 'Family'),
        ],
      ),
    );
  }
}

// ==========================================
// 2. HOME SCREEN (Dashboard UI)
// ==========================================
class HomeScreen extends StatefulWidget {
  final Function(int) onTabChange;
  const HomeScreen({super.key, required this.onTabChange});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  String? _fullName;
  bool _isLoading = true;
  List<dynamic> _upcomingMeds = [];

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  Future<void> _initDashboard() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase.from('profiles').select('full_name').eq('id', user.id).maybeSingle();
        if (data != null && mounted) setState(() => _fullName = data['full_name']);
        
        final medsData = await _supabase.from('medications').select('*').eq('user_id', user.id).eq('is_taken', false);
        if (mounted) {
          setState(() {
            _upcomingMeds = medsData;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final displayName = _fullName ?? user?.email?.split('@')[0] ?? "User";

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('FamCare', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9))),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _initDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Good Morning,', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                    Text(displayName.toUpperCase(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 25),
                    
                    _buildSummaryCard(
                      context, 
                      _upcomingMeds.isNotEmpty ? 'Due Soon' : 'No Immediate Meds',
                      _upcomingMeds.isNotEmpty ? 'Next: ${_upcomingMeds[0]['name']}' : 'Check full schedule',
                      LucideIcons.pill, 
                      _upcomingMeds.isNotEmpty ? Colors.orange : Colors.grey,
                      () => widget.onTabChange(1)
                    ),
                    const SizedBox(height: 15),
                    _buildSummaryCard(context, 'Health Tracker', 'Log your vitals', LucideIcons.activity, const Color(0xFF0EA5E9), () => widget.onTabChange(2)),
                    const SizedBox(height: 15),
                    _buildSummaryCard(context, 'Family Hub', 'See what others are doing', LucideIcons.users, Colors.green, () => widget.onTabChange(4)),

                    const SizedBox(height: 30),
                    const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildActionButton(context, 'Add Med', LucideIcons.plusCircle, Colors.orange, () => widget.onTabChange(1)),
                        _buildActionButton(context, 'Vault', LucideIcons.folderLock, Colors.purple, () => widget.onTabChange(3)),
                        _buildActionButton(context, 'SOS', LucideIcons.phoneCall, Colors.red, () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Emergency SOS Triggered!")));
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[100]!)),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)),
            const SizedBox(width: 20),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)), Text(sub, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))])),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: color, size: 28)),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ==========================================
// 3. ALARM OVERLAY (The Popup Screen)
// ==========================================
class AlarmOverlay extends StatelessWidget {
  final Map<String, dynamic> medicine;
  final AudioPlayer player;
  final VoidCallback onActionTaken;
  final Map<String, Future<void>> pendingReminders;
  final Function(String) onRemindLater;

  const AlarmOverlay({
    super.key, 
    required this.medicine, 
    required this.player, 
    required this.onActionTaken,
    required this.pendingReminders,
    required this.onRemindLater,
  });

  @override
  Widget build(BuildContext context) {
    final imagePath = medicine['image_path'] as String?;
    final medId = medicine['id']?.toString() ?? '';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1117), Color(0xFF1A2332)],
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: ClipOval(
                  child: imagePath != null && File(imagePath).existsSync()
                      ? Image.file(File(imagePath), width: 150, height: 150, fit: BoxFit.cover)
                      : const Icon(LucideIcons.pill, size: 80, color: Colors.white70),
                ),
              ),
              const SizedBox(height: 30),
              const Icon(LucideIcons.bellRing, size: 50, color: Colors.white),
              const SizedBox(height: 20),
              const Text("TIME FOR MEDICINE", style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 2)),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  medicine['name'] ?? "Unknown",
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "Dosage: ${medicine['dosage'] ?? '1 dose'}",
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white, 
                        minimumSize: const Size(double.infinity, 60), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () async {
                        try {
                          await Supabase.instance.client.from('medications').update({'is_taken': true}).eq('id', medId);
                          await HistoryService.logAction(actionType: 'MED', description: 'Took ${medicine['name']}');
                        } catch (e) {
                          debugPrint('Error marking as taken: $e');
                        }
                        await player.stop();
                        if (context.mounted) Navigator.pop(context);
                        onActionTaken();
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.checkCircle, size: 24),
                          SizedBox(width: 10),
                          Text("I TOOK IT", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white, 
                        minimumSize: const Size(double.infinity, 60), 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () async {
                        await player.stop();
                        if (context.mounted) Navigator.pop(context);
                        onRemindLater(medId);
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.clock, size: 24),
                          SizedBox(width: 10),
                          Text("REMIND ME LATER", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ),
    );
  }
}