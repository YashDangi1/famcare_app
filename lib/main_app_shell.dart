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
import 'main.dart' show medicineUpdatedNotifier;
import 'meds_screen.dart';
import 'vault_screen.dart';
import 'settings_screen.dart';
import 'screens/health_dashboard_screen.dart';
import 'services/activity_service.dart';
import 'services/notification_service.dart';
import 'services/slot_preferences_service.dart';
import 'screens/appointment_screen.dart';

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
        .listen(
          (_) => _updatePendingMedsCount(),
          onError: (e) => debugPrint('Meds stream error: $e'),
        );
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
  final Set<String> _existingImagePaths = {};
  Map<String, dynamic>? _latestVital;

  // New state variables for Quick Stats
  int _totalMedsToday = 0;
  int _takenMedsToday = 0;
  int _familyCount = 0;
  int _streakDays = 0;

  // Next Medication Data
  Map<String, dynamic>? _nextMedData;
  String? _nextMedTimeLabel;

  // Missed Medicines (last 7 days)
  List<Map<String, dynamic>> _missedLogs = [];

  // Next Appointment
  Map<String, dynamic>? _nextAppointment;

  // FIX 3: Due Soon animated list
  final GlobalKey<AnimatedListState> _dueSoonListKey = GlobalKey<AnimatedListState>();
  List<Map<String, dynamic>> _cachedDueSoon = [];

  // Quick Action refresh + local slot tracking
  Timer? _minuteTimer;
  StreamSubscription? _medsSubscription;
  final Set<String> _takenSlotIdsToday = {};
  final Set<String> _skippedSlotIds = {}; // Format: "medId_slot"
  Map<String, dynamic> _slotPrefs = {}; // Slot time preferences (morning_start, etc.)

  @override
  void initState() {
    super.initState();
    _initDashboard();
    _setupMedsSubscription();
    _minuteTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _initDashboard();
        _checkSlotWhatsAppReminders();
      }
    });
    // Refresh Due Soon panel when medicine alarm time is edited
    medicineUpdatedNotifier.addListener(_onMedicineUpdated);

    // One-time slot setup prompt
    _checkSlotSetupPrompt();
  }

  void _onMedicineUpdated() async {
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      _isRefreshingDashboard = false; // Reset guard so refresh isn't skipped
      _initDashboard();
    }
  }

  Future<void> _checkSlotSetupPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyShown = prefs.getBool('slot_setup_shown') ?? false;
    if (alreadyShown) return;

    // Check if user already has slot preferences saved
    final result = await Supabase.instance.client
        .from('user_slot_preferences')
        .select('user_id')
        .eq('user_id', Supabase.instance.client.auth.currentUser?.id ?? '')
        .maybeSingle();

    if (result != null) {
      // Already has preferences — mark as shown and skip
      await prefs.setBool('slot_setup_shown', true);
      return;
    }

    if (!mounted) return;

    // Show one-time bottom sheet
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(LucideIcons.clock, size: 48, color: Color(0xFF10B981)),
            const SizedBox(height: 16),
            const Text(
              'Set your medicine schedule times',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Get accurate reminders by setting your preferred time ranges for morning, afternoon, evening, and night slots.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  await prefs.setBool('slot_setup_shown', true);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Set Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                await prefs.setBool('slot_setup_shown', true);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text('Skip for now', style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }

  /// 6B — Check if any slot is starting now, send WhatsApp reminder to family admins.
  /// Uses SharedPreferences to avoid sending duplicate reminders within the same slot window.
  Future<void> _checkSlotWhatsAppReminders() async {
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final currentMinutes = now.hour * 60 + now.minute;

      // Load slot preferences
      final slotPrefs = await SlotPreferencesService().getPreferences();

      final slotNames = {
        'morning': 'Morning',
        'afternoon': 'Afternoon',
        'evening': 'Evening',
        'night': 'Night',
      };

      final prefs = await SharedPreferences.getInstance();

      for (final entry in slotNames.entries) {
        final slot = entry.key;
        final slotLabel = entry.value;
        final startStr = slotPrefs['${slot}_start'];
        if (startStr == null) continue;

        final parts = startStr.split(':');
        final slotStartMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);

        // Check if current time is within 2 minutes of slot start
        final diff = currentMinutes - slotStartMinutes;
        if (diff < 0 || diff > 2) continue;

        // Check if we already sent for this slot today
        final sentKey = 'wa_slot_sent_${todayStr}_$slot';
        if (prefs.getBool(sentKey) == true) continue;

        // Find today's active medications in this slot
        final userId = _supabase.auth.currentUser?.id;
        if (userId == null) continue;

        final response = await _supabase
            .from('medications')
            .select('name, slot_types, is_paused')
            .eq('user_id', userId)
            .eq('is_active', true);

        final medsInSlot = (response as List).where((m) {
          final slots = List<String>.from(m['slot_types'] ?? []);
          final isPaused = m['is_paused'] == true;
          return slots.contains(slot) && !isPaused;
        }).toList();

        if (medsInSlot.isEmpty) continue;

        // Get patient name
        final profile = await _supabase
            .from('profiles')
            .select('full_name')
            .eq('id', userId)
            .maybeSingle();
        final patientName = profile?['full_name'] ?? 'Patient';

        // Send WhatsApp for each medicine in this slot
        for (final med in medsInSlot) {
          final slotStart = DateTime(now.year, now.month, now.day,
              int.parse(parts[0]), int.parse(parts[1]));
          await NotificationService().sendSlotReminderAlert(
            patientName: patientName,
            medicineName: med['name'] ?? 'Medicine',
            slotName: slotLabel,
            slotStartTime: slotStart,
          );
        }

        // Mark as sent
        await prefs.setBool(sentKey, true);
        debugPrint('WhatsApp slot reminder sent for $slotLabel (${medsInSlot.length} meds)');
      }
    } catch (e) {
      debugPrint('WhatsApp slot reminder check error: $e');
    }
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    _medsSubscription?.cancel();
    medicineUpdatedNotifier.removeListener(_onMedicineUpdated);
    super.dispose();
  }

  void _setupMedsSubscription() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _medsSubscription = _supabase
        .from('medications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen(
          (_) => _initDashboard(),
          onError: (e) => debugPrint('Meds stream error: $e'),
        );
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

            if (difference >= -15 &&
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

  /// Returns the slot start DateTime for today
  DateTime _slotStartToday(String slot) {
    final now = DateTime.now();
    if (slot == 'custom') {
      // Custom slots use custom_start from prefs
      final startStr = _slotPrefs['custom_start'] ?? '08:00';
      final parts = startStr.split(':');
      return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    }
    final startStr = _slotPrefs['${slot}_start'] ?? _defaultSlotStart(slot);
    final parts = startStr.split(':');
    return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  /// Returns the slot end DateTime for today
  DateTime _slotEndToday(String slot) {
    final now = DateTime.now();
    if (slot == 'custom') {
      final endStr = _slotPrefs['custom_end'] ?? '09:00';
      final parts = endStr.split(':');
      return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
    }
    final endStr = _slotPrefs['${slot}_end'] ?? _defaultSlotEnd(slot);
    final parts = endStr.split(':');
    return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  static String _defaultSlotStart(String slot) {
    switch (slot) {
      case 'morning': return '08:00';
      case 'afternoon': return '12:00';
      case 'evening': return '16:00';
      case 'night': return '21:00';
      default: return '08:00';
    }
  }

  static String _defaultSlotEnd(String slot) {
    switch (slot) {
      case 'morning': return '09:30';
      case 'afternoon': return '14:00';
      case 'evening': return '18:00';
      case 'night': return '22:30';
      default: return '09:30';
    }
  }

  static int _slotIndex(String slot) {
    switch (slot) {
      case 'morning': return 1;
      case 'afternoon': return 2;
      case 'evening': return 3;
      case 'night': return 4;
      case 'custom': return 5;
      default: return 0;
    }
  }

  static String _slotNameLabel(String slot) {
    switch (slot) {
      case 'morning': return 'Morning';
      case 'afternoon': return 'Afternoon';
      case 'evening': return 'Evening';
      case 'night': return 'Night';
      case 'custom': return 'Custom';
      default: return slot;
    }
  }

  List<Map<String, dynamic>> _getDueSoonMeds() {
    final now = DateTime.now();
    final dueSoon = <Map<String, dynamic>>[];

    for (final med in _todaysMeds) {
      if (med.isPaused) continue;
      if (!med.isActiveOnDate(now)) continue;

      for (final slot in med.slotTypes) {
        if (slot == 'custom') {
          for (int i = 0; i < med.customTimes.length; i++) {
            final timeStr = med.customTimes[i];
            DateTime? customAlarmTime;

            try {
              final parsed = DateFormat('hh:mm a').parseStrict(timeStr.trim());
              customAlarmTime = DateTime(
                now.year,
                now.month,
                now.day,
                parsed.hour,
                parsed.minute,
              );
            } catch (_) {
              final parts = timeStr.trim().split(':');
              if (parts.length < 2) continue;
              final hour = int.tryParse(parts[0]);
              final minute = int.tryParse(parts[1]);
              if (hour == null || minute == null) continue;
              customAlarmTime = DateTime(
                now.year,
                now.month,
                now.day,
                hour,
                minute,
              );
            }

            final diff = customAlarmTime.difference(now).inMinutes;
            if (diff >= -30 && diff <= 15) {
              final slotKey = _slotKey(med.id ?? '', 500 + i);
              if (!_takenSlotIdsToday.contains(slotKey) &&
                  !_skippedSlotIds.contains(slotKey)) {
                dueSoon.add({
                  'medicine': med,
                  'slot': 500 + i,
                  'customTimeStr': timeStr,
                  'slotName': 'Custom',
                  'dateTime': customAlarmTime,
                });
              }
            }
          }
        } else {
          final slotStart = _slotStartToday(slot);
          final slotEnd = _slotEndToday(slot);

          // Medicine is due if current time is within the slot range
          if (now.isAfter(slotStart) && now.isBefore(slotEnd)) {
            final slotIdx = _slotIndex(slot);
            final slotKey = _slotKey(med.id ?? '', slotIdx);
            if (!_takenSlotIdsToday.contains(slotKey) &&
                !_skippedSlotIds.contains(slotKey)) {
              dueSoon.add({
                'medicine': med,
                'slot': slotIdx,
                'slotName': _slotNameLabel(slot),
                'dateTime': slotStart,
              });
            }
          }
        }
      }
    }

    dueSoon.sort(
      (a, b) => (a['dateTime'] as DateTime).compareTo(b['dateTime'] as DateTime),
    );
    return dueSoon;
  }

  /// FIX 3: Remove item from AnimatedList with slide animation
  void _removeDueSoonItem(Map<String, dynamic> item) {
    final index = _cachedDueSoon.indexOf(item);
    if (index < 0) return;
    final removedItem = _cachedDueSoon.removeAt(index);
    _dueSoonListKey.currentState?.removeItem(
      index,
      (context, animation) => SizeTransition(
        sizeFactor: animation,
        child: _buildDueSoonCard(removedItem),
      ),
      duration: const Duration(milliseconds: 300),
    );
  }

  Future<void> _onEarlyTake(Map<String, dynamic> med) async {
    // FIX 3: Animate item out first
    _removeDueSoonItem(med);

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

  Future<void> _onSkipWindow(Map<String, dynamic> med) async {
    // FIX 3: Animate item out first
    _removeDueSoonItem(med);

    final medicine = med['medicine'] as Medicine;
    final slot = med['slot'] as int;
    final slotId = _slotKey(medicine.id ?? '', slot);
    final scheduledTime = med['dateTime'] as DateTime;

    // 1. UI se immediately hatao
    setState(() {
      _skippedSlotIds.add(slotId);
    });

    // 2. Alarm cancel karo (warna bajta rahega)
    try {
      final alarmId = slot == 1
          ? medicine.alarmId1
          : slot == 2
              ? medicine.alarmId2
              : medicine.alarmId3;
      if (alarmId != null) {
        await _alarmService.cancelAlarm(alarmId);
      }
    } catch (e) {
      debugPrint('Cancel alarm error: $e');
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

    if (mounted) {
      AppSnackBar.showInfo(context, "Alarm cancelled for this dose");
    }
  }

  Future<void> _initDashboard() async {
    if (_isRefreshingDashboard) return;
    _isRefreshingDashboard = true;
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Load slot preferences for Due Soon panel
      final slotPrefs = await SlotPreferencesService().getPreferences();

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

      // 8A — Low stock alert check (fire-and-forget, don't block dashboard)
      _checkLowStockAlerts(todaysMeds);

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
          .map((log) => _slotKey(log['medication_id'].toString(), int.tryParse(log['alarm_slot'].toString()) ?? 1))
          .toSet();
      // Adherence ke liye sirf taken count karo
      int tempTaken = allLogs.where((log) => log['status'] == 'taken').length;

      // 9A — Schedule daily summary notification at 10 PM
      _alarmService.scheduleDailySummary(taken: tempTaken, total: tempTotal);

      // Fetch missed medicines (last 7 days)
      final sevenDaysAgo = DateTime.now()
          .subtract(const Duration(days: 7))
          .toIso8601String();
      final missedResponse = await _supabase
          .from('medicine_logs')
          .select('medicine_name, scheduled_time, alarm_slot')
          .eq('user_id', userId)
          .eq('status', 'missed')
          .gte('scheduled_time', sevenDaysAgo)
          .order('scheduled_time', ascending: false)
          .limit(10);
      final missedLogs = List<Map<String, dynamic>>.from(missedResponse as List);

      // Fetch next upcoming appointment
      Map<String, dynamic>? nextAppointment;
      try {
        nextAppointment = await _supabase
            .from('appointments')
            .select('doctor_name, appointment_time, notes')
            .eq('user_id', userId)
            .gte('appointment_time', DateTime.now().toIso8601String())
            .order('appointment_time', ascending: true)
            .limit(1)
            .maybeSingle();
      } catch (e) {
        debugPrint('Fetch next appointment error: $e');
      }

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
          _slotPrefs = slotPrefs;
          // Cache image existence to avoid sync I/O in build()
          _existingImagePaths.clear();
          for (final m in todaysMeds) {
            if (m.imagePath != null && m.imagePath!.isNotEmpty) {
              if (File(m.imagePath!).existsSync()) {
                _existingImagePaths.add(m.imagePath!);
              }
            }
          }
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
                    log['medication_id'].toString(), int.tryParse(log['alarm_slot'].toString()) ?? 1)));
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
          _missedLogs = missedLogs;
          _nextAppointment = nextAppointment;
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

  /// 8A — Check low stock and send alerts (fire-and-forget from _initDashboard)
  Future<void> _checkLowStockAlerts(List<Medicine> meds) async {
    try {
      for (final med in meds) {
        if (med.id == null) continue;

        if (med.qty <= 5 && !med.lowStockAlerted && !med.isPaused) {
          // Local notification
          await NotificationService().showLocalNotification(
            title: 'Low Stock Alert',
            body: '${med.name} — sirf ${med.qty} doses bachi hain. Refill karo!',
          );
          // WhatsApp to family admin
          await NotificationService().sendLowStockAlert(med.name, med.qty);
          // Mark as alerted in DB
          await _supabase
              .from('medications')
              .update({'low_stock_alerted': true})
              .eq('id', med.id!);
          debugPrint('Low stock alert sent for ${med.name} (${med.qty} left)');
        }

        // Reset alert flag when qty is refilled above 5
        if (med.qty > 5 && med.lowStockAlerted) {
          await _supabase
              .from('medications')
              .update({'low_stock_alerted': false})
              .eq('id', med.id!);
          debugPrint('Low stock alert reset for ${med.name} (${med.qty} left)');
        }
      }
    } catch (e) {
      debugPrint('Low stock check error: $e');
    }
  }

  Future<int> _calculateStreak(String userId) async {
    // Fetch last 30 days of ALL logs (not just taken) using scheduled_time
    final thirtyDaysAgo = DateTime.now()
        .subtract(const Duration(days: 30))
        .toUtc()
        .toIso8601String();

    final logs = await _supabase
        .from('medicine_logs')
        .select('scheduled_time, medication_id, status')
        .eq('user_id', userId)
        .gte('scheduled_time', thirtyDaysAgo);

    // Group logs by scheduled date — count taken per medicine per day
    final takenPerDate = <DateTime, Set<String>>{};
    for (final log in (logs as List)) {
      if (log['status'] != 'taken') continue;
      final dt = DateTime.tryParse(log['scheduled_time']?.toString() ?? '');
      if (dt == null) continue;
      final local = dt.toLocal();
      final dateKey = DateTime(local.year, local.month, local.day);
      final medId = log['medication_id']?.toString() ?? '';
      takenPerDate.putIfAbsent(dateKey, () => {}).add(medId);
    }

    // Fetch all medications to compute scheduled medicine count per day
    final medsResponse = await _supabase
        .from('medications')
        .select('id, start_date, end_date, is_paused, is_active, slot_types')
        .eq('user_id', userId);

    final allMeds = (medsResponse as List).map((m) {
      final start = DateTime.tryParse(m['start_date']?.toString() ?? '') ?? DateTime.now();
      final end = DateTime.tryParse(m['end_date']?.toString() ?? '') ?? DateTime.now();
      return {
        'id': m['id']?.toString() ?? '',
        'start': DateTime(start.year, start.month, start.day),
        'end': DateTime(end.year, end.month, end.day),
        'isPaused': m['is_paused'] == true,
        'isActive': m['is_active'] != false,
        'slotCount': (m['slot_types'] as List?)?.length ?? 1,
      };
    }).toList();

    // Count consecutive "perfect" days from today backwards
    int streak = 0;
    final now = DateTime.now();
    for (int i = 0; i < 30; i++) {
      final checkDate = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: i));

      // Count scheduled medicines for this day
      int scheduledMeds = 0;
      for (final m in allMeds) {
        if (m['isPaused'] == true || m['isActive'] == false) continue;
        final start = m['start'] as DateTime;
        final end = m['end'] as DateTime;
        if (!checkDate.isBefore(start) && !checkDate.isAfter(end)) {
          scheduledMeds++;
        }
      }

      // Skip days with no scheduled medicines
      if (scheduledMeds == 0) {
        if (i == 0) continue;
        break;
      }

      // Perfect day: ALL scheduled medicines have at least one taken log
      final takenMedIds = takenPerDate[checkDate] ?? {};
      final allTaken = takenMedIds.length >= scheduledMeds;

      if (allTaken) {
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
                        final dueSoonKeys = _getDueSoonMeds()
                            .map((m) => _slotKey((m['medicine'] as Medicine).id ?? '', m['slot'] as int))
                            .toSet();
                        final upcoming = _getUpcomingMedsInWindow()
                            .where((item) {
                              final med = item['medicine'] as Medicine;
                              final slotKey = _slotKey(med.id ?? '', item['slot'] as int);
                              return !dueSoonKeys.contains(slotKey);
                            })
                            .toList();
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

                    // Due Soon Panel — slot-based, max 4 visible, animated removal
                    Builder(
                      builder: (context) {
                        _cachedDueSoon = _getDueSoonMeds();
                        if (_cachedDueSoon.isEmpty) return const SizedBox.shrink();
                        final panelHeight = _cachedDueSoon.length > 4
                            ? 4.0 * 74.0
                            : _cachedDueSoon.length * 74.0;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(LucideIcons.bell, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Due Soon',
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.25),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          '${_cachedDueSoon.length}',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    height: panelHeight,
                                    child: AnimatedList(
                                      key: _dueSoonListKey,
                                      padding: EdgeInsets.zero,
                                      initialItemCount: _cachedDueSoon.length,
                                      itemBuilder: (context, index, animation) {
                                        if (index >= _cachedDueSoon.length) return const SizedBox.shrink();
                                        return SizeTransition(
                                          sizeFactor: animation,
                                          child: _buildDueSoonCard(_cachedDueSoon[index]),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
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

                    const SizedBox(height: 25),

                    // Next Appointment Card
                    if (_nextAppointment != null) ...[
                      const Text('Next Appointment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                      const SizedBox(height: 12),
                      _buildNextAppointmentCard(),
                      const SizedBox(height: 25),
                    ],

                    // Missed Medicines (last 7 days)
                    const Text('Missed Medicines', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    const SizedBox(height: 12),
                    _missedLogs.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(LucideIcons.checkCircle, color: Colors.green[400], size: 20),
                                const SizedBox(width: 10),
                                const Text(
                                  'No missed medicines this week',
                                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          )
                        : Column(
                            children: _missedLogs.map((log) {
                              final name = log['medicine_name'] ?? 'Medicine';
                              final scheduled = log['scheduled_time'] != null
                                  ? DateTime.tryParse(log['scheduled_time'].toString())?.toLocal()
                                  : null;
                              final slot = log['alarm_slot'];
                              final dateStr = scheduled != null
                                  ? '${scheduled.day}/${scheduled.month} ${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}'
                                  : '';
                              final slotLabel = slot == 1 ? 'Morning' : slot == 2 ? 'Afternoon' : slot == 3 ? 'Evening' : 'Dose';
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border(left: BorderSide(color: Colors.red[400]!, width: 4)),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF334155))),
                                          const SizedBox(height: 4),
                                          Text('$dateStr  •  $slotLabel', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                        ],
                                      ),
                                    ),
                                    Icon(LucideIcons.xCircle, color: Colors.red[300], size: 18),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),

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
                        _buildQuickAction(context, 'Book Appt', LucideIcons.calendarPlus, const Color(0xFFF59E0B), () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AppointmentScreen()));
                        }),
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
    final hasImage = imagePath != null && imagePath.isNotEmpty && _existingImagePaths.contains(imagePath);

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

  Widget _buildDueSoonCard(Map<String, dynamic> item) {
    final med = item['medicine'] as Medicine;
    final slotName = item['slotName'] as String? ?? 'Dose';
    final imagePath = med.imagePath;
    final hasImage = imagePath != null && imagePath.isNotEmpty && _existingImagePaths.contains(imagePath);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(File(imagePath), fit: BoxFit.cover),
                  )
                : const Icon(LucideIcons.pill, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
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
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    slotName,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Skip this dose',
                onPressed: () => _onSkipWindow(item),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  padding: const EdgeInsets.all(6),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Mark as taken',
                onPressed: () => _onEarlyTake(item),
                icon: const Icon(Icons.check_rounded, color: Colors.white, size: 24),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  padding: const EdgeInsets.all(6),
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

  Widget _buildNextAppointmentCard() {
    final appt = _nextAppointment!;
    final doctorName = appt['doctor_name'] ?? 'Doctor';
    final apptTime = DateTime.tryParse(appt['appointment_time']?.toString() ?? '')?.toLocal();
    final notes = appt['notes']?.toString() ?? '';
    final dateStr = apptTime != null ? DateFormat('EEE, dd MMM • hh:mm a').format(apptTime) : '';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppointmentScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.stethoscope, color: Color(0xFFF59E0B), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doctorName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                  const SizedBox(height: 4),
                  Text(dateStr, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(notes, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  ],
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: Colors.grey[300], size: 20),
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
      mainValue = '${_latestVital!['bp_systolic']}/${_latestVital!['bp_diastolic'] ?? '--'} mmHg';
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
