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
import 'vault_screen.dart';
import 'history_service.dart';
import 'settings_screen.dart';

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
      const VaultScreen(),          // Tab 3
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
    // Reset triggered alarms and reset is_taken flag at midnight
    final today = DateTime.now().toIso8601String().split('T')[0];
    if (_lastResetDate.isNotEmpty && _lastResetDate != today) {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        // Daily Reset: Set is_taken = false for ALL medications of the current user
        try {
          await _supabase
              .from('medications')
              .update({'is_taken': false})
              .eq('user_id', user.id)
              .eq('is_taken', true);
          
          _triggeredToday.clear();
          _lastResetDate = today;
          debugPrint("Daily Reset: All medications marked as not taken for today.");
          if (mounted) setState(() {});
        } catch (e) {
          debugPrint("Daily Reset Error: $e");
        }
      }
    } else if (_lastResetDate.isEmpty) {
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
    
    final medId = med['id']?.toString() ?? '';
    final now = DateTime.now();
    final triggerKey = "${medId}_${now.hour}_${now.minute}";

    // 1. Show UI overlay immediately
    if (!context.mounted) return;
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (context, _, __) => AlarmOverlay(
        medicine: med, 
        player: _audioPlayer,
        onActionTaken: () => setState(() {}),
        onRemindLater: () {
          // Trigger Bug Fix: Remove from triggered set BEFORE scheduling delay
          _triggeredToday.remove(triggerKey);
          
          Future.delayed(
            const Duration(minutes: 15),
            () => _triggerInAppAlarm(med),
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
          BottomNavigationBarItem(icon: Icon(LucideIcons.folderHeart), label: 'Vault'),
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
  Map<String, dynamic>? _latestVital;

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  Future<void> _initDashboard() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        // Fetch Profile Name
        final profileData = await _supabase.from('profiles').select('full_name').eq('id', user.id).maybeSingle();
        if (profileData != null && mounted) setState(() => _fullName = profileData['full_name']);
        
        // Fetch Upcoming Meds (is_taken false, ordered by time)
        final medsData = await _supabase.from('medications')
            .select('*')
            .eq('user_id', user.id)
            .eq('is_taken', false)
            .order('time', ascending: true);
        
        // Fetch Latest Vital
        final vitalsData = await _supabase.from('vitals')
            .select('*')
            .eq('user_id', user.id)
            .order('measured_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _upcomingMeds = medsData;
            _latestVital = vitalsData;
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('FamCare', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9))),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.settings, color: Colors.grey),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
        ],
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
                    // Welcome Header
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome back,', style: TextStyle(fontSize: 16, color: Colors.grey[600], letterSpacing: 0.5)),
                        Text('$displayName!', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      ],
                    ),
                    const SizedBox(height: 25),
                    
                    // Upcoming Medication Card
                    const Text('Next Medication', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 12),
                    _buildMedicationSummary(),

                    const SizedBox(height: 25),
                    
                    // Latest Vital Card
                    const Text('Latest Reading', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 12),
                    _buildVitalsSummary(),

                    const SizedBox(height: 30),
                    
                    // Quick Actions Section
                    const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildQuickAction(context, 'Log Vital', LucideIcons.activity, const Color(0xFF0EA5E9), () => widget.onTabChange(2)),
                        _buildQuickAction(context, 'Add Med', LucideIcons.pill, Colors.orange, () => widget.onTabChange(1)),
                        _buildQuickAction(context, 'Upload Rx', LucideIcons.filePlus, Colors.purple, () => widget.onTabChange(3)),
                        _buildQuickAction(context, 'Family', LucideIcons.users, Colors.green, () => widget.onTabChange(4)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMedicationSummary() {
    if (_upcomingMeds.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(LucideIcons.check, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('All caught up for today!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  Text('Check again later', style: TextStyle(fontSize: 13, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final nextMed = _upcomingMeds[0];
    return InkWell(
      onTap: () => widget.onTabChange(1),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(LucideIcons.pill, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nextMed['name'] ?? 'Unknown', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(LucideIcons.clock, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(nextMed['time'] ?? '--:--', style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 12),
                      const Icon(LucideIcons.scale, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(nextMed['dosage'] ?? '-', style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalsSummary() {
    if (_latestVital == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: const Row(
          children: [
            Icon(LucideIcons.activity, color: Colors.grey, size: 24),
            SizedBox(width: 16),
            Text('No vitals logged yet', style: TextStyle(color: Colors.grey, fontSize: 15)),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => widget.onTabChange(2),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(LucideIcons.activity, color: Color(0xFF0EA5E9), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_latestVital!['vital_type'] ?? 'Vital', style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('${_latestVital!['value']} ${_latestVital!['unit']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
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
  final VoidCallback onRemindLater;

  const AlarmOverlay({
    super.key, 
    required this.medicine, 
    required this.player, 
    required this.onActionTaken,
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
                        onRemindLater();
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