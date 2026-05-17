import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'services/alarm_service.dart';
import 'utils/snackbar_utils.dart';

import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/medicine_model.dart';
import 'screens/alarm_setup_screen.dart';
import 'family_hub_screen.dart';
import 'screens/vitals_screen.dart';
import 'meds_screen.dart';
import 'vault_screen.dart';
import 'settings_screen.dart';
import 'screens/health_dashboard_screen.dart';
import 'services/activity_service.dart';

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
  int _homeRefreshVersion = 0;
  
  final _supabase = Supabase.instance.client;
  int _pendingMedsCount = 0;
  StreamSubscription? _medsSubscription;

  @override
  void initState() {
    super.initState();

    // Listen for medication changes to update badge
    _setupMedsSubscription();
    _updatePendingMedsCount();
    _checkFirstLaunchPermissions();
  }

  List<Widget> _buildPages() {
    return [
      HomeScreen(
        key: ValueKey('home_$_homeRefreshVersion'),
        onTabChange: (index) => setState(() => _currentIndex = index),
      ),
      const MedsScreen(),
      const VitalsScreen(),
      const VaultScreen(),
      const FamilyHubScreen(),
    ];
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

      final today = DateTime.now().toIso8601String().split('T')[0];
      
      // ✅ Aaj ke active medicines count karo
      final response = await _supabase
          .from('medications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_active', true)
          .lte('start_date', today)
          .gte('end_date', today);
      
      if (mounted) {
        setState(() {
          _pendingMedsCount = (response as List).length;
        });
      }
    } catch (e) {
      debugPrint("Error updating pending meds count: $e");
    }
  }

  Future<void> _checkFirstLaunchPermissions() async {
    final prefs = await SharedPreferences.getInstance();
    final setupDone = prefs.getBool('alarm_setup_done') ?? false;

    if (!setupDone) {
      final notif = await Permission.notification.isGranted;
      final exact = await Permission.scheduleExactAlarm.isGranted;
      final battery = await Permission.ignoreBatteryOptimizations.isGranted;

      if (!notif || !exact || !battery) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AlarmSetupScreen(showAsOnboarding: true),
            ),
          );
          await prefs.setBool('alarm_setup_done', true);
        }
      } else {
        await prefs.setBool('alarm_setup_done', true);
      }
    }
  }

  @override
  void dispose() {
    _medsSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF0EA5E9),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() {
          if (index == 0 && _currentIndex != 0) {
            _homeRefreshVersion++;
          }
          _currentIndex = index;
        }),
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
  final _alarmService = AlarmService();
  String? _fullName;
  bool _isLoading = true;
  bool _isRefreshingDashboard = false;
  List<Medicine> _todaysMeds = [];
  Map<String, dynamic>? _latestVital;

  // New state variables for Quick Stats
  int _totalMedsToday = 0;
  int _takenMedsToday = 0;
  int _familyCount = 0;
  int _streakDays = 0;

  // Next Medication Data
  Map<String, dynamic>? _nextMedData;
  String? _nextMedTimeLabel;

  // Quick Action refresh + local slot tracking
  Timer? _minuteTimer;
  StreamSubscription? _medsSubscription;
  final Set<String> _takenSlotIdsToday = {};
  final Set<String> _skippedSlotIds = {}; // Format: "medId_slot"

  @override
  void initState() {
    super.initState();
    _initDashboard();
    _setupMedsSubscription();
    _minuteTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        _initDashboard();
      }
    });
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    _medsSubscription?.cancel();
    super.dispose();
  }

  void _setupMedsSubscription() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _medsSubscription = _supabase
        .from('medications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((_) => _initDashboard());
  }

  String _slotKey(String medId, int slot) => '${medId}_$slot';

  List<Map<String, dynamic>> _getUpcomingMedsInWindow() {
    List<Map<String, dynamic>> upcoming = [];
    final now = DateTime.now();

    for (var med in _todaysMeds) {
      final times = [med.time1, med.time2, med.time3];
      for (int index = 0; index < times.length; index++) {
        final timeStr = times[index];
        final slot = index + 1;
        if (timeStr != null && timeStr.isNotEmpty) {
          try {
            final parsedTime = DateFormat('hh:mm a').parse(timeStr.trim());
            final scheduledDateTime = DateTime(
              now.year,
              now.month,
              now.day,
              parsedTime.hour,
              parsedTime.minute,
            );

            final difference = scheduledDateTime.difference(now).inMinutes;
            final slotKey = _slotKey(med.id ?? '', slot);

            if (difference >= -30 &&
                difference <= 30 &&
                !_takenSlotIdsToday.contains(slotKey) &&
                !_skippedSlotIds.contains(slotKey)) {
              upcoming.add({
                'medicine': med,
                'slot': slot,
                'time': timeStr,
                'dateTime': scheduledDateTime,
              });
            }
          } catch (e) {
            debugPrint('Time parse error: $e');
          }
        }
      }
    }
    upcoming.sort(
      (a, b) => (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime),
    );
    return upcoming;
  }

  Future<void> _onEarlyTake(Map<String, dynamic> med) async {
    try {
      final medicine = med['medicine'] as Medicine;
      final medId = medicine.id;
      final int slot = med['slot'] as int;
      final scheduledTime = med['dateTime'] as DateTime;
      if (medId == null) {
        throw Exception('Medicine ID is missing');
      }
      final alarmId = slot == 1
          ? medicine.alarmId1
          : slot == 2
              ? medicine.alarmId2
              : medicine.alarmId3;

      // 1. Cancel alarm
      if (alarmId != null) {
        await _alarmService.cancelAlarm(alarmId);
      }

      // 2. Decrement qty — fresh DB fetch to avoid stale data
      final latest = await _supabase
          .from('medications')
          .select('qty')
          .eq('id', medId)
          .single();
      final currentQty = int.tryParse(latest['qty'].toString()) ?? 0;
      final newQty = (currentQty - 1).clamp(0, 99999);

      await _supabase
          .from('medications')
          .update({'qty': newQty, if (newQty == 0) 'is_active': false})
          .eq('id', medId);

      // 3. Log to medicine_logs
      final userId = _supabase.auth.currentUser?.id;
      final medicineName = medicine.name;
      await _supabase.from('medicine_logs').insert({
        'user_id': userId,
        'medication_id': medId,
        'medicine_name': medicineName,
        'dosage': medicine.dosage,
        'status': 'taken',
        'alarm_slot': slot,
        'scheduled_time': scheduledTime.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });

      // 4. Activity Log
      try {
        await ActivityService.log(
          actionType: 'MEDICINE_TAKEN',
          description: 'Took $medicineName',
        );
      } catch (e) {
        debugPrint('Feed log error: $e');
      }

      // 5. Update UI
      if (mounted) {
        _takenSlotIdsToday.add(_slotKey(medId, slot));
        _skippedSlotIds.remove(_slotKey(medId, slot));
        AppSnackBar.showSuccess(context, "Medicine marked as taken early!");
        _initDashboard(); // Refresh all data
      }
    } catch (e) {
      debugPrint("Error in _onEarlyTake: $e");
      if (mounted) AppSnackBar.showError(context, "Error: $e");
    }
  }

  void _onSkipWindow(Map<String, dynamic> med) async {
    final medicine = med['medicine'] as Medicine;
    final slot = med['slot'] as int;
    final slotId = _slotKey(medicine.id ?? '', slot);
    final scheduledTime = med['dateTime'] as DateTime;

    // 1. UI se immediately hatao
    setState(() {
      _skippedSlotIds.add(slotId);
    });

    // 2. Alarm cancel karo (warna bajta rahega)
    final alarmId = slot == 1
        ? medicine.alarmId1
        : slot == 2
            ? medicine.alarmId2
            : medicine.alarmId3;
    if (alarmId != null) {
      await _alarmService.cancelAlarm(alarmId);
    }

    // 3. DB mein save karo taaki refresh ke baad bhi survive kare
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null && medicine.id != null) {
        await _supabase.from('medicine_logs').insert({
          'user_id': userId,
          'medication_id': medicine.id,
          'medicine_name': medicine.name,
          'dosage': medicine.dosage,
          'status': 'skipped',
          'alarm_slot': slot,
          'scheduled_time': scheduledTime.toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      debugPrint('Skip log error: $e');
    }

    AppSnackBar.showInfo(context, "Alarm cancelled for this dose");
  }

  Future<void> _initDashboard() async {
    if (_isRefreshingDashboard) return;
    _isRefreshingDashboard = true;
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Fetch ALL medications (no is_active filter — filter locally like meds_screen)
      final response = await _supabase
          .from('medications')
          .select()
          .eq('user_id', userId);

      debugPrint("Dashboard: Fetched ${response.length} active meds from DB.");

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      int tempTotal = 0;
      List<Medicine> todaysMeds = [];

      // 2. Filter locally with foolproof inclusive date check
      for (var item in response) {
        final med = Medicine.fromJson(item);
        final start = DateTime(med.startDate.year, med.startDate.month, med.startDate.day);
        DateTime end = DateTime(med.endDate.year, med.endDate.month, med.endDate.day);
        final parsedEndDate = DateTime.tryParse(item['end_date']?.toString() ?? '');
        if (parsedEndDate != null) {
          end = DateTime(parsedEndDate.year, parsedEndDate.month, parsedEndDate.day);
        }

        // compareTo logic: 0 means same day, >0 means today is after start, <0 means today is before end
        if (today.compareTo(start) >= 0 && today.compareTo(end) <= 0) {
          todaysMeds.add(med);
          tempTotal += med.frequency; // Total doses for today
        }
      }

      debugPrint("Dashboard: ${todaysMeds.length} meds scheduled for exactly today. Total doses: $tempTotal");

      // 3. Fetch taken logs for today safely
      final startOfDay = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59).toUtc().toIso8601String();
      
      final logsResponse = await _supabase
          .from('medicine_logs')
          .select()
          .eq('user_id', userId)
          .inFilter('status', ['taken', 'skipped'])
          .gte('created_at', startOfDay)
          .lte('created_at', endOfDay);

      final allLogs = List<Map<String, dynamic>>.from(logsResponse as List);
      // Taken + skipped dono hide karo Today's Medicines se
      final hiddenSlotIds = allLogs
          .where((log) => log['medication_id'] != null && log['alarm_slot'] != null)
          .map((log) => _slotKey(log['medication_id'].toString(), log['alarm_slot'] as int))
          .toSet();
      // Adherence ke liye sirf taken count karo
      int tempTaken = allLogs.where((log) => log['status'] == 'taken').length;

      // 4. Find Next Medication (Closest upcoming time not taken)
      Medicine? nextMedication;
      DateTime? closestTime;
      String? nextSlotLabel;

      for (var med in todaysMeds) {
        final activeTimes = med.activeTimes;
        for (int i = 0; i < activeTimes.length; i++) {
          final timeStr = activeTimes[i];
          final slot = i + 1;

          try {
            final format = DateFormat("hh:mm a");
            final tod = format.parse(timeStr);
            final scheduledTime = DateTime(today.year, today.month, today.day, tod.hour, tod.minute);

            // Check if already taken today
            bool alreadyTaken = allLogs.any((log) =>
              log['medication_id'] == med.id && log['alarm_slot'] == slot
            );

            if (!alreadyTaken && scheduledTime.isAfter(now)) {
              if (closestTime == null || scheduledTime.isBefore(closestTime)) {
                closestTime = scheduledTime;
                nextMedication = med;
                nextSlotLabel = timeStr;
              }
            }
          } catch (e) {
            debugPrint("Error parsing time for next med: $e");
          }
        }
      }

      // Fetch Latest Vital
      final vitalsData = await _supabase.from('vitals')
          .select('*')
          .eq('user_id', userId)
          .order('measured_at', ascending: false)
          .limit(1)
          .maybeSingle();

      // Fetch Family Members
      final familyData = await _supabase.from('family_members')
          .select('group_id')
          .eq('user_id', userId)
          .maybeSingle();
      
      int familyMembers = 0;
      if (familyData != null) {
        final members = await _supabase.from('family_members')
            .select('id')
            .eq('group_id', familyData['group_id']);
        familyMembers = (members as List).length;
      }

      // Calculate streak (single optimized query)
      final streak = await _calculateStreak(userId);

      // Fetch Profile Name
      final profileData = await _supabase.from('profiles').select('full_name').eq('id', userId).maybeSingle();
      if (profileData != null && mounted) setState(() => _fullName = profileData['full_name']);

      if (mounted) {
        setState(() {
          _todaysMeds = todaysMeds;
          _takenSlotIdsToday
            ..clear()
            ..addAll(hiddenSlotIds);
          // Sync skipped from DB so cross-clicked cards survive restart
          _skippedSlotIds
            ..clear()
            ..addAll(allLogs
                .where((log) =>
                    log['status'] == 'skipped' &&
                    log['medication_id'] != null &&
                    log['alarm_slot'] != null)
                .map((log) => _slotKey(
                    log['medication_id'].toString(), log['alarm_slot'] as int)));
          _latestVital = vitalsData;
          _totalMedsToday = tempTotal;
          _takenMedsToday = tempTaken;
          _familyCount = familyMembers;
          _streakDays = streak;
          _isLoading = false;
          
          _nextMedData = nextMedication != null ? {
            'name': nextMedication.name,
            'dosage': nextMedication.dosage,
            'image_path': nextMedication.imagePath,
          } : null;
          _nextMedTimeLabel = nextSlotLabel;
        });
      }
    } catch (e) {
      debugPrint("Dashboard Fetch Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dashboard Error: ${e.toString()}')),
        );
        setState(() => _isLoading = false);
      }
    } finally {
      _isRefreshingDashboard = false;
    }
  }

  Future<int> _calculateStreak(String userId) async {
    // Fetch last 30 days of logs in ONE query
    final thirtyDaysAgo = DateTime.now()
        .subtract(const Duration(days: 30))
        .toUtc()
        .toIso8601String();

    final logs = await _supabase
        .from('medicine_logs')
        .select('created_at')
        .eq('user_id', userId)
        .eq('status', 'taken')
        .gte('created_at', thirtyDaysAgo)
        .order('created_at', ascending: false);

    // Extract unique dates
    final takenDates = (logs as List)
        .map((log) {
          final dt = DateTime.parse(log['created_at']).toLocal();
          return DateTime(dt.year, dt.month, dt.day);
        })
        .toSet();

    // Count consecutive days from today backwards
    int streak = 0;
    final now = DateTime.now();
    for (int i = 0; i < 30; i++) {
      final checkDate = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i)
          
          
          
          
          
          
          
          
          
          
          
          
          
          
          
          
          );
      if (takenDates.contains(checkDate)) {
        streak++;
      } else if (i > 0) {
        break;
      }
    }
    return streak;
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
            icon: const Icon(LucideIcons.layoutDashboard, color: Color(0xFF0EA5E9)),
            tooltip: "Health Dashboard",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const HealthDashboardScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.bellRing, color: Color(0xFF0EA5E9)),
            tooltip: "Alarm Setup",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AlarmSetupScreen()),
            ),
          ),
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
                    Builder(
                      builder: (context) {
                        final upcoming = _getUpcomingMedsInWindow();
                        if (upcoming.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Today\'s Medicines',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                            const SizedBox(height: 12),
                            ...upcoming.map((item) {
                              return _buildTodayMedicineCard(item);
                            }),
                            const SizedBox(height: 25),
                          ],
                        );
                      },
                    ),

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

  Widget _buildTodayMedicineCard(Map<String, dynamic> item) {
    final med = item['medicine'] as Medicine;
    final imagePath = med.imagePath;
    final hasImage = imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(LucideIcons.pill, color: Color(0xFF0EA5E9), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  med.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    item['time'] as String,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0EA5E9),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Will ring at scheduled time',
                onPressed: () => _onSkipWindow(item),
                icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  padding: const EdgeInsets.all(8),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Mark as taken early',
                onPressed: () => _onEarlyTake(item),
                icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green.withValues(alpha: 0.1),
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ],
          ),
        ],
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
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
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
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
              backgroundColor: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
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
    if (_nextMedData == null) {
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
                  Text(_nextMedData!['name'] ?? 'Unknown', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(LucideIcons.clock, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(_nextMedTimeLabel ?? '--:--', style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 12),
                      const Icon(LucideIcons.scale, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(_nextMedData!['dosage'] ?? '-', style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
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
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle),
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
