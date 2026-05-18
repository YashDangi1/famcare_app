import 'dart:async';
import 'dart:convert';
import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'main_app_shell.dart';
import 'screens/alarm_screen.dart';
import 'services/alarm_service.dart';
import 'splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Guard against double-calling (early listener + AlarmService listener both fire)
final Set<int> _handledAlarmIds = {};

// BUG 2: Guard against double-execution of notification action handlers
final Set<int> _handledNotificationActionIds = {};

// Global alarm state — when set, app shows ONLY the AlarmScreen (no home/nav)
// Value is the alarm ID. Null = show normal app.
final ValueNotifier<int?> activeAlarmIdNotifier = ValueNotifier(null);

// Notifier for Due Soon panel refresh when medicine alarm time is edited
final ValueNotifier<int> medicineUpdatedNotifier = ValueNotifier(0);

@pragma('vm:entry-point')
// Called when alarm rings (app running OR woken up from killed state)
Future<void> handleAlarmRing(AlarmSettings settings) async {
  if (_handledAlarmIds.contains(settings.id)) {
    debugPrint("handleAlarmRing: ID=${settings.id} already handled, skipping");
    return;
  }
  _handledAlarmIds.add(settings.id);
  debugPrint("handleAlarmRing: ID=${settings.id}");

  // Wait for navigator — up to 6 seconds (slow phones + cold start)
  int attempts = 0;
  while (navigatorKey.currentState == null && attempts < 20) {
    await Future.delayed(const Duration(milliseconds: 300));
    attempts++;
    debugPrint("Waiting for navigator... attempt $attempts");
  }

  if (navigatorKey.currentState == null) {
    debugPrint("Navigator not ready - alarm sound plays but no UI");
    return;
  }

  try {
    // Supabase initialize hone ka wait karo (killed state mein time lagta hai)
    int supabaseAttempts = 0;
    while (supabaseAttempts < 10) {
      try {
        Supabase.instance.client; // Test karo accessible hai ya nahi
        break;
      } catch (_) {
        await Future.delayed(const Duration(milliseconds: 500));
        supabaseAttempts++;
      }
    }
    final supabase = Supabase.instance.client;

    final isSnooze = settings.id > 10000;
    final originalId = isSnooze ? settings.id - 10000 : settings.id;

    Map<String, dynamic>? response;

    // Try alarm_id1
    response = await supabase
        .from('medications')
        .select('*')
        .eq('alarm_id1', originalId)
        .maybeSingle()
        .timeout(const Duration(seconds: 5));

    // Try alarm_id2 if not found
    if (response == null) {
      response = await supabase
          .from('medications')
          .select('*')
          .eq('alarm_id2', originalId)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
    }

    // Try alarm_id3 if not found
    if (response == null) {
      response = await supabase
          .from('medications')
          .select('*')
          .eq('alarm_id3', originalId)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
    }

    if (response == null) {
      debugPrint("No medication found for ID ${settings.id} - stopping");
      await Alarm.stop(settings.id);
      return;
    }

    final med = response!;

    // Check alarm style preference
    final prefs = await SharedPreferences.getInstance();
    final isFullScreen = prefs.getBool('alarm_style_fullscreen') ?? true;

    if (!isFullScreen) {
      // Notification only mode — replace alarm package notification with ours
      // Same notification ID = Android replaces native notification with our action buttons
      debugPrint("Alarm style: Notification only — replacing with action notification");

      await AlarmService().showActionNotification(
        alarmId: settings.id,
        medicineName: med['name'] ?? 'Medicine',
        dosage: med['dosage'] ?? '1 dose',
        scheduledTime: settings.dateTime,
      );

      // BUG 7: Auto-stop sound after 30 min if no action taken
      final autoStopId = settings.id;
      Timer(const Duration(minutes: 30), () async {
        if (_handledNotificationActionIds.contains(autoStopId)) return;
        try {
          final activeAlarms = await Alarm.getAlarms();
          final stillRinging = activeAlarms.any((a) => a.id == autoStopId);
          if (stillRinging) {
            await Alarm.stop(autoStopId);
            await _logAsMissed(autoStopId);
          }
        } catch (e) {
          debugPrint("Auto-stop error: $e");
        }
      });

      return;
    }

    int slot = 1;
    if (med['alarm_id2'] == originalId) slot = 2;
    if (med['alarm_id3'] == originalId) slot = 3;

    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => AlarmScreen(
          alarmId: settings.id,
          isSnooze: isSnooze,
          medicineName: med['name'] ?? 'Medicine',
          dosage: med['dosage'] ?? '1 dose',
          qty: int.tryParse(med['qty']?.toString() ?? '0') ?? 0,
          medicationId: med['id'] ?? '',
          alarmSlot: slot,
          scheduledTime: settings.dateTime,
          imagePath: med['image_path'],
        ),
      ),
    );
    debugPrint("AlarmScreen pushed for '${med['name']}'");
  } catch (e) {
    debugPrint("Error in handleAlarmRing: $e");
  }
}

// Handle alarm ring with just the ID (for killed-state relaunch via MethodChannel)
// Sets the global notifier — MyApp will rebuild and show ONLY AlarmScreen
Future<void> handleAlarmRingById(int alarmId) async {
  if (_handledAlarmIds.contains(alarmId)) {
    debugPrint("handleAlarmRingById: ID=$alarmId already handled, skipping");
    return;
  }
  _handledAlarmIds.add(alarmId);

  // Check preference — don't open AlarmScreen in notification-only mode
  final prefs = await SharedPreferences.getInstance();
  final isFullScreen = prefs.getBool('alarm_style_fullscreen') ?? true;
  if (!isFullScreen) {
    debugPrint("handleAlarmRingById: notification-only mode — not opening AlarmScreen for ID=$alarmId");
    return;
  }

  debugPrint("handleAlarmRingById: ID=$alarmId — activating full-screen mode");

  // BUG 4: Wait for Supabase using _supabaseReady bool
  int supabaseAttempts = 0;
  while (!_supabaseReady && supabaseAttempts < 20) {
    await Future.delayed(const Duration(milliseconds: 300));
    supabaseAttempts++;
  }

  // Set the global notifier — triggers MyApp rebuild with AlarmScreen only
  activeAlarmIdNotifier.value = alarmId;
}

// Handle notification action button taps (background — no UI)
// @pragma required for flutter_local_notifications background callback
@pragma('vm:entry-point')
void _onNotificationResponse(NotificationResponse response) async {
  final actionId = response.actionId ?? '';
  debugPrint("=== NOTIFICATION RESPONSE === actionId: $actionId, payload: ${response.payload}");

  if (actionId.startsWith('took_it_')) {
    final alarmId = int.tryParse(actionId.replaceFirst('took_it_', ''));
    if (alarmId != null) await _handleNotificationTookIt(alarmId);
  } else if (actionId.startsWith('take_later_')) {
    final alarmId = int.tryParse(actionId.replaceFirst('take_later_', ''));
    if (alarmId != null) await _handleNotificationTakeLater(alarmId);
  }
}

Future<void> _handleNotificationTookIt(int alarmId) async {
  // BUG 2: Double-execution guard
  if (_handledNotificationActionIds.contains(alarmId)) return;
  _handledNotificationActionIds.add(alarmId);
  Future.delayed(const Duration(minutes: 1), () => _handledNotificationActionIds.remove(alarmId));

  try {
    await Alarm.stop(alarmId);
    await AlarmService().notificationsPlugin.cancel(alarmId); // Cancel native notification

    // BUG 4: Wait for Supabase using _supabaseReady bool
    int attempts = 0;
    while (!_supabaseReady && attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 300));
      attempts++;
    }
    if (!_supabaseReady) {
      debugPrint('Supabase not ready after timeout — cannot log took_it');
      return;
    }

    final supabase = Supabase.instance.client;

    // BUG 5: Explicit userId null check with early return
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('userId null — cannot log took_it');
      return;
    }

    // Find medication by alarm ID
    final isSnooze = alarmId > 10000;
    final originalId = isSnooze ? alarmId - 10000 : alarmId;

    Map<String, dynamic>? med;
    med = await supabase.from('medications').select('*').eq('alarm_id1', originalId).maybeSingle().timeout(const Duration(seconds: 5));
    if (med == null) med = await supabase.from('medications').select('*').eq('alarm_id2', originalId).maybeSingle().timeout(const Duration(seconds: 5));
    if (med == null) med = await supabase.from('medications').select('*').eq('alarm_id3', originalId).maybeSingle().timeout(const Duration(seconds: 5));

    if (med == null) return;

    final medId = med['id'];
    if (medId == null || medId.toString().isEmpty) return;

    // Decrement qty
    final currentQty = int.tryParse(med['qty']?.toString() ?? '0') ?? 0;
    final newQty = (currentQty - 1).clamp(0, 99999);
    await supabase.from('medications').update({'qty': newQty}).eq('id', medId);

    if (newQty == 0) {
      await supabase.from('medications').update({'is_active': false}).eq('id', medId);
    }

    // Determine slot
    int slot = 1;
    if (med['alarm_id2'] == originalId) slot = 2;
    if (med['alarm_id3'] == originalId) slot = 3;

    // Read original scheduled time from cache
    final prefs = await SharedPreferences.getInstance();
    final scheduledStr = prefs.getString('alarm_scheduled_time_$alarmId');
    final scheduledTime = scheduledStr != null
        ? DateTime.parse(scheduledStr)
        : DateTime.now();

    // Log as taken
    await supabase.from('medicine_logs').insert({
      'user_id': userId,
      'medication_id': medId,
      'medicine_name': med['name'] ?? 'Medicine',
      'dosage': med['dosage'] ?? '1 dose',
      'status': 'taken',
      'alarm_slot': slot,
      'scheduled_time': scheduledTime.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });

    // Clean up cache
    try {
      await prefs.remove('cached_med_$alarmId');
      await prefs.remove('alarm_scheduled_time_$alarmId');
    } catch (_) {}

    debugPrint("Notification 'I Took It' handled for alarm $alarmId");
  } catch (e) {
    debugPrint("Error handling notification took_it: $e");
  }
}

Future<void> _handleNotificationTakeLater(int alarmId) async {
  // BUG 2: Double-execution guard
  if (_handledNotificationActionIds.contains(alarmId)) return;
  _handledNotificationActionIds.add(alarmId);
  Future.delayed(const Duration(minutes: 1), () => _handledNotificationActionIds.remove(alarmId));

  try {
    await Alarm.stop(alarmId);
    await AlarmService().notificationsPlugin.cancel(alarmId); // Cancel native notification

    // BUG 4: Wait for Supabase using _supabaseReady bool
    int attempts = 0;
    while (!_supabaseReady && attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 300));
      attempts++;
    }
    if (!_supabaseReady) {
      debugPrint('Supabase not ready after timeout — cannot log take_later');
      return;
    }

    final supabase = Supabase.instance.client;

    // BUG 5: Explicit userId null check with early return
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('userId null — cannot log take_later');
      return;
    }

    // Find medication by alarm ID
    final isSnooze = alarmId > 10000;
    final originalId = isSnooze ? alarmId - 10000 : alarmId;

    Map<String, dynamic>? med;
    med = await supabase.from('medications').select('*').eq('alarm_id1', originalId).maybeSingle().timeout(const Duration(seconds: 5));
    if (med == null) med = await supabase.from('medications').select('*').eq('alarm_id2', originalId).maybeSingle().timeout(const Duration(seconds: 5));
    if (med == null) med = await supabase.from('medications').select('*').eq('alarm_id3', originalId).maybeSingle().timeout(const Duration(seconds: 5));

    String medicineName = 'Medicine';
    String dosage = '1 dose';
    String medId = '';
    int slot = 1;

    if (med != null) {
      medicineName = med['name'] ?? 'Medicine';
      dosage = med['dosage'] ?? '1 dose';
      medId = med['id'] ?? '';
      if (med['alarm_id2'] == originalId) slot = 2;
      if (med['alarm_id3'] == originalId) slot = 3;
    }

    // BUG 3: Schedule snooze from ORIGINAL scheduled time, not DateTime.now()
    final prefs = await SharedPreferences.getInstance();
    final scheduledStr = prefs.getString('alarm_scheduled_time_$alarmId');
    final scheduledTime = scheduledStr != null
        ? DateTime.parse(scheduledStr)
        : DateTime.now();

    await AlarmService().scheduleSnoozeAlarm(
      originalId: originalId,
      medicineName: medicineName,
      originalTime: scheduledTime,
    );

    // Log as snoozed
    if (userId != null && medId.isNotEmpty) {
      await supabase.from('medicine_logs').insert({
        'user_id': userId,
        'medication_id': medId,
        'medicine_name': medicineName,
        'dosage': dosage,
        'status': 'snoozed',
        'alarm_slot': slot,
        'scheduled_time': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    // Clean up cache
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_med_$alarmId');
      await prefs.remove('alarm_scheduled_time_$alarmId');
    } catch (_) {}

    debugPrint("Notification 'Take Later' handled for alarm $alarmId");
  } catch (e) {
    debugPrint("Error handling notification take_later: $e");
  }
}

/// BUG 7: Log alarm as missed when auto-stop timer fires (no action taken)
Future<void> _logAsMissed(int alarmId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_med_$alarmId');
    if (cached == null) return;

    final data = jsonDecode(cached) as Map<String, dynamic>;

    // Wait for Supabase
    int attempts = 0;
    while (!_supabaseReady && attempts < 20) {
      await Future.delayed(const Duration(milliseconds: 300));
      attempts++;
    }
    if (!_supabaseReady) return;

    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase.from('medicine_logs').insert({
      'user_id': userId,
      'medication_id': data['id'] ?? '',
      'medicine_name': data['name'] ?? 'Medicine',
      'dosage': data['dosage'] ?? '1 dose',
      'status': 'missed',
      'alarm_slot': int.tryParse(data['slot']?.toString() ?? '1') ?? 1,
      'scheduled_time': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });

    // Clean up
    await prefs.remove('cached_med_$alarmId');
    await prefs.remove('alarm_scheduled_time_$alarmId');

    debugPrint("Auto-stop: logged as missed for alarm $alarmId");
  } catch (e) {
    debugPrint("Error logging missed dose: $e");
  }
}

// Buffer for alarm events received before Supabase is ready
final List<AlarmSettings> _pendingAlarms = [];
bool _supabaseReady = false;

// MethodChannel for native alarm events (killed-state relaunch)
const _alarmChannel = MethodChannel('com.famcare/alarm');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // STEP 1: Check for alarm FIRST — lightweight, fast.
  bool alarmMode = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    final storedAlarmId = prefs.getInt('ringing_alarm_id');
    if (storedAlarmId != null && storedAlarmId != -1) {
      final isFullScreen = prefs.getBool('alarm_style_fullscreen') ?? true;
      if (isFullScreen) {
        debugPrint("ALARM MODE: Found stored alarm ID=$storedAlarmId");
        activeAlarmIdNotifier.value = storedAlarmId;
        alarmMode = true;
      } else {
        debugPrint("ALARM MODE: Notification-only — skipping stored alarm ID=$storedAlarmId");
      }
      prefs.remove('ringing_alarm_id');
    }
  } catch (e) {
    debugPrint("Error checking stored alarm ID: $e");
  }

  // STEP 2: Show UI IMMEDIATELY — no blocking calls before runApp.
  runApp(const MyApp());

  // STEP 3: Supabase init — runs AFTER runApp so UI shows instantly.
  // In alarm mode, _AlarmScreenWrapper shows loading screen while this runs.
  await dotenv.load(fileName: '.env');
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
    _supabaseReady = true;
  } catch (e) {
    debugPrint("Supabase Init Error: $e");
    _supabaseReady = false;
  }

  // STEP 4: Post-launch init.
  // In alarm mode: skip ALL alarm init — AlarmScreen wrapper handles everything.
  // The native AlarmService is already playing audio + vibrating.
  if (!alarmMode) {
    // Normal mode: full alarm init
    Alarm.ringStream.stream.listen((settings) {
      debugPrint("Early ringStream catch: ID=${settings.id}");
      if (_supabaseReady) {
        handleAlarmRing(settings);
      } else {
        _pendingAlarms.add(settings);
      }
    });

    await Alarm.init();
    await AlarmService().init();

    // Re-register notification callback directly (must be top-level @pragma function)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await AlarmService().notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onNotificationResponse,
    );

    // Foreground listener — check for stored alarm when app resumes
    FGBGEvents.instance.stream.listen((event) async {
      if (event == FGBGType.foreground) {
        debugPrint("App came to foreground — checking for stored alarm ID");
        try {
          final prefs = await SharedPreferences.getInstance();
          final storedAlarmId = prefs.getInt('ringing_alarm_id');
          if (storedAlarmId != null && storedAlarmId != -1) {
            debugPrint("Found stored alarm ID on foreground: $storedAlarmId");
            prefs.remove('ringing_alarm_id');
            handleAlarmRingById(storedAlarmId);
          }
        } catch (e) {
          debugPrint("Error checking stored alarm on foreground: $e");
        }
      }
    });
  }

  // MethodChannel for runtime alarm events (both modes)
  _alarmChannel.setMethodCallHandler((call) async {
    if (call.method == 'onAlarmRing') {
      final alarmId = call.arguments as int;
      debugPrint("MethodChannel onAlarmRing: ID=$alarmId");
      if (!alarmMode) {
        handleAlarmRingById(alarmId);
      }
    }
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    activeAlarmIdNotifier.addListener(_onAlarmChanged);
  }

  @override
  void dispose() {
    activeAlarmIdNotifier.removeListener(_onAlarmChanged);
    super.dispose();
  }

  void _onAlarmChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final activeAlarmId = activeAlarmIdNotifier.value;

    return MaterialApp(
      title: 'FamCare',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: const Color(0xFF0EA5E9),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0EA5E9),
          primary: const Color(0xFF0EA5E9),
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: Color(0xFF1E293B)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0EA5E9),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
        ),
      ),
      // When alarm is active, show ONLY the AlarmScreen — no home, no nav
      home: activeAlarmId != null
          ? _AlarmScreenWrapper(alarmId: activeAlarmId)
          : const SplashScreen(),
    );
  }
}

/// Observer that resets the global alarm state when AlarmScreen is popped
class _AlarmNavObserver extends NavigatorObserver {
  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    // AlarmScreen was popped — return to normal app and re-init alarms
    activeAlarmIdNotifier.value = null;
    // Re-initialize alarm system so future alarms work
    Alarm.init().then((_) => AlarmService().init());
  }
}

/// Wrapper that fetches alarm data from cache/DB and shows AlarmScreen
class _AlarmScreenWrapper extends StatefulWidget {
  final int alarmId;
  const _AlarmScreenWrapper({required this.alarmId});

  @override
  State<_AlarmScreenWrapper> createState() => _AlarmScreenWrapperState();
}

class _AlarmScreenWrapperState extends State<_AlarmScreenWrapper> {
  Map<String, dynamic>? _med;

  @override
  void initState() {
    super.initState();
    _loadFromCacheInstantly();
  }

  Future<void> _loadFromCacheInstantly() async {
    // Step 1: Read from SharedPreferences — INSTANT, no network
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_med_${widget.alarmId}');

    if (cached != null) {
      final data = jsonDecode(cached) as Map<String, dynamic>;
      if (mounted) setState(() => _med = data);
      // AlarmScreen is now visible — silently refresh qty in background
      _silentlyRefreshQty(prefs);
    } else {
      // No cache — wait for DB (fallback only)
      _loadFromDb();
    }
  }

  Future<void> _silentlyRefreshQty(SharedPreferences prefs) async {
    // Wait for Supabase — but AlarmScreen is already showing
    while (!_supabaseReady) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    try {
      final supabase = Supabase.instance.client;
      final medId = _med?['id'];
      if (medId == null || medId.toString().isEmpty) return;

      final latest = await supabase
          .from('medications')
          .select('qty, name')
          .eq('id', medId)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      if (latest != null && mounted) {
        setState(() => _med = {..._med!, 'qty': latest['qty']});
      }
    } catch (e) {
      debugPrint('Silent qty refresh error: $e');
    }
  }

  Future<void> _loadFromDb() async {
    // Fallback: no cache available — wait and query DB
    while (!_supabaseReady) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    try {
      final supabase = Supabase.instance.client;
      final isSnooze = widget.alarmId > 10000;
      final originalId = isSnooze ? widget.alarmId - 10000 : widget.alarmId;

      final responses = await Future.wait<Object?>([
        supabase.from('medications').select('*').eq('alarm_id1', originalId).maybeSingle(),
        supabase.from('medications').select('*').eq('alarm_id2', originalId).maybeSingle(),
        supabase.from('medications').select('*').eq('alarm_id3', originalId).maybeSingle(),
      ]);

      Map<String, dynamic>? response;
      int matchedSlot = 1;
      for (int i = 0; i < responses.length; i++) {
        if (responses[i] != null) {
          response = responses[i] as Map<String, dynamic>;
          matchedSlot = i + 1; // 1-indexed: alarm_id1→1, alarm_id2→2, alarm_id3→3
          break;
        }
      }

      if (response == null) {
        await Alarm.stop(widget.alarmId);
        activeAlarmIdNotifier.value = null;
        return;
      }
      response['slot'] = matchedSlot;
      if (mounted) setState(() => _med = response);
    } catch (e) {
      debugPrint('DB load error: $e');
      activeAlarmIdNotifier.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // No cache AND no DB yet — pure dark screen (NOT a spinner)
    // This should only show for <200ms in worst case
    if (_med == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1117),
        body: SizedBox.expand(), // Pure dark — no spinner, no text
      );
    }

    final isSnooze = widget.alarmId > 10000;
    final originalId = isSnooze ? widget.alarmId - 10000 : widget.alarmId;
    final slot = (_med!['slot'] as int?) ?? 1;

    return Navigator(
      observers: [_AlarmNavObserver()],
      onGenerateRoute: (_) => PageRouteBuilder(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => AlarmScreen(
          alarmId: widget.alarmId,
          isSnooze: isSnooze,
          medicineName: _med!['name'] ?? 'Medicine',
          dosage: _med!['dosage'] ?? '1 dose',
          qty: int.tryParse(_med!['qty']?.toString() ?? '0') ?? 0,
          medicationId: _med!['id'] ?? '',
          alarmSlot: slot,
          scheduledTime: DateTime.now(),
          imagePath: _med!['image_path'],
        ),
      ),
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    return session != null ? const MainAppShell() : const LoginScreen();
  }
}

