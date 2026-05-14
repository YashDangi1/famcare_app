import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:audioplayers/audioplayers.dart';

import 'family_hub_screen.dart';
import 'screens/vitals_screen.dart';
import 'meds_screen.dart';
import 'screens/prescription_screen.dart';
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
  int _pendingMedsCount = 0;
  StreamSubscription? _medsSubscription;

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

    // Listen for medication changes to update badge
    _setupMedsSubscription();
    _updatePendingMedsCount();
  }

  void _setupMedsSubscription() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _medsSubscription = _supabase
        .from('medications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((_) => _updatePendingMedsCount());
  }

  Future<void> _updatePendingMedsCount() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('medications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_taken', false);
      
      if (mounted) {
        setState(() {
          _pendingMedsCount = (response as List).length;
        });
      }
    } catch (e) {
      debugPrint("Error updating pending meds count: $e");
    }
  }

  @override
  void dispose() {
    _alarmCheckTimer?.cancel();
    _medsSubscription?.cancel();
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
        items: [
          const BottomNavigationBarItem(icon: Icon(LucideIcons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Badge(
              label: Text(_pendingMedsCount.toString()),
              isLabelVisible: _pendingMedsCount > 0,
              child: const Icon(LucideIcons.pill),
            ),
            label: 'Meds',
          ),
          const BottomNavigationBarItem(icon: Icon(LucideIcons.activity), label: 'Vitals'),
          const BottomNavigationBarItem(icon: Icon(LucideIcons.folderHeart), label: 'Vault'),
          const BottomNavigationBarItem(icon: Icon(LucideIcons.users), label: 'Family'),
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

  // New state variables for Quick Stats
  int _totalMedsToday = 0;
  int _takenMedsToday = 0;
  int _familyCount = 0;
  int _streakDays = 0;

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

        // Task 2: Fetch Quick Stats
        final allMedsToday = await _supabase.from('medications')
            .select('is_taken')
            .eq('user_id', user.id);
        
        // Fetch Family Members (if there's a family_groups table or similar)
        // For now, let's check if the user is in a group
        final familyData = await _supabase.from('family_members')
            .select('group_id')
            .eq('user_id', user.id)
            .maybeSingle();
        
        int familyMembers = 0;
        if (familyData != null) {
          final members = await _supabase.from('family_members')
              .select('id')
              .eq('group_id', familyData['group_id']);
          familyMembers = (members as List).length;
        }

        if (mounted) {
          setState(() {
            _upcomingMeds = medsData;
            _latestVital = vitalsData;
            _totalMedsToday = (allMedsToday as List).length;
            _takenMedsToday = (allMedsToday).where((m) => m['is_taken'] == true).length;
            _familyCount = familyMembers;
            _streakDays = 5; // Placeholder for now
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
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
                        Text('${_getGreeting()},', style: TextStyle(fontSize: 16, color: Colors.grey[600], letterSpacing: 0.5)),
                        Text('$displayName!', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Quick Stats Chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStatChip('Meds Today', '$_takenMedsToday/$_totalMedsToday', LucideIcons.pill, Colors.orange),
                          const SizedBox(width: 12),
                          _buildStatChip('Streak', '$_streakDays Days', LucideIcons.flame, Colors.red),
                          const SizedBox(width: 12),
                          _buildStatChip('Family', '$_familyCount Members', LucideIcons.users, Colors.green),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),

                    // Today's Progress Card
                    const Text('Today\'s Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 12),
                    _buildProgressCard(),

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

  Widget _buildStatChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final double progress = _totalMedsToday == 0 ? 1.0 : _takenMedsToday / _totalMedsToday;
    final int percentage = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Adherence', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600])),
              Text('$percentage%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9))),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.1),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _totalMedsToday == 0 
              ? 'No medications scheduled for today.' 
              : 'You have taken $_takenMedsToday out of $_totalMedsToday medications.',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
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
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
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
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
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

    String mainLabel = 'Vitals Reading';
    String mainValue = '--';
    IconData mainIcon = LucideIcons.activity;
    Color iconColor = const Color(0xFF0EA5E9);

    if (_latestVital!['bp_systolic'] != null) {
      mainLabel = 'Blood Pressure';
      mainValue = '${_latestVital!['bp_systolic']}/${_latestVital!['bp_diastolic']} mmHg';
      mainIcon = LucideIcons.activity;
    } else if (_latestVital!['heart_rate'] != null) {
      mainLabel = 'Heart Rate';
      mainValue = '${_latestVital!['heart_rate']} bpm';
      mainIcon = LucideIcons.heart;
      iconColor = Colors.red;
    } else if (_latestVital!['spo2'] != null) {
      mainLabel = 'SpO2';
      mainValue = '${_latestVital!['spo2']}%';
      mainIcon = LucideIcons.droplets;
      iconColor = Colors.blue;
    } else if (_latestVital!['weight'] != null) {
      mainLabel = 'Weight';
      mainValue = '${_latestVital!['weight']} kg';
      mainIcon = LucideIcons.scale;
      iconColor = Colors.green;
    }

    return InkWell(
      onTap: () => widget.onTabChange(2),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(mainIcon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mainLabel, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(mainValue, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
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
              color: color.withOpacity(0.1),
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