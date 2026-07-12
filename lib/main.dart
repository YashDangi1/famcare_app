import 'dart:async';
import 'package:alarm/alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'models/alarm_context.dart';
import 'models/medicine_entity.dart';
import 'providers/isar_provider.dart';
import 'screens/alarm_screen.dart';
import 'screens/group_alarm_screen.dart';
import 'services/alarm_service.dart';
import 'services/alarm_context_resolver.dart';
import 'services/alarm_action_engine.dart';
import 'services/alarm_recovery_manager.dart';
import 'services/background_service.dart'; // C4: WorkManager
import 'services/offline_sync_service.dart';
import 'splash_screen.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';
import 'dart:ui';
import 'services/ops_telemetry_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final Map<int, DateTime> _recentlyHandledAlarmIds = {};
final Map<int, Timer> _autoStopTimers = {};

final ValueNotifier<int?> activeAlarmIdNotifier = ValueNotifier(null);
final ValueNotifier<String?> activeSlotAlarmNotifier = ValueNotifier(null);
final ValueNotifier<int> medicineUpdatedNotifier = ValueNotifier(0);

bool _supabaseReady = false;
const _alarmChannel = MethodChannel('com.famcare/alarm');

bool _wasHandledRecently(int alarmId) {
  final lastHandled = _recentlyHandledAlarmIds[alarmId];
  if (lastHandled == null) return false;
  return DateTime.now().difference(lastHandled) < const Duration(seconds: 5);
}

void _markHandledNow(int alarmId) {
  _recentlyHandledAlarmIds[alarmId] = DateTime.now();
}

Future<void> _persistAlarmRuntimeState(
  int alarmId,
  Duration ttl, {
  bool markAsRinging = false,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final existingExpiry = prefs.getString('auto_stop_expiry_$alarmId');
  final existingExpiryDt =
      existingExpiry != null ? DateTime.tryParse(existingExpiry) : null;
  final effectiveExpiry = existingExpiryDt != null && existingExpiryDt.isAfter(DateTime.now())
      ? existingExpiryDt
      : DateTime.now().add(ttl);
  await prefs.setString(
    'auto_stop_expiry_$alarmId',
    effectiveExpiry.toIso8601String(),
  );
  if (markAsRinging) {
    await prefs.setInt('ringing_alarm_id', alarmId);
  }
}

Future<void> _clearAlarmRuntimeState(int alarmId) async {
  _autoStopTimers.remove(alarmId)?.cancel();
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('auto_stop_expiry_$alarmId');
  final ringingAlarmId = prefs.getInt('ringing_alarm_id');
  if (ringingAlarmId == alarmId) {
    await prefs.remove('ringing_alarm_id');
  }
}

Future<void> _scheduleAutoStopTimer(AlarmContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final expiryStr = prefs.getString('auto_stop_expiry_${context.alarmId}');
  final expiry = expiryStr != null ? DateTime.tryParse(expiryStr) : null;
  final remaining = expiry?.difference(DateTime.now());
  if (remaining == null || remaining <= Duration.zero) return;

  _autoStopTimers.remove(context.alarmId)?.cancel();
  _autoStopTimers[context.alarmId] = Timer(remaining, () async {
    final latestContext =
        await AlarmContextResolver.instance.resolveAlarmContext(context.alarmId) ??
            context;
    if (latestContext.isSingle) {
      await AlarmActionEngine.instance.missSingleDose(latestContext);
    } else {
      await AlarmActionEngine.instance.missGroupDoses(latestContext);
    }
    _autoStopTimers.remove(context.alarmId);
    if (activeAlarmIdNotifier.value == context.alarmId) {
      activeAlarmIdNotifier.value = null;
    }
  });
}

Future<void> _restorePendingAutoStopTimers() async {
  final prefs = await SharedPreferences.getInstance();
  final keys = prefs
      .getKeys()
      .where((key) => key.startsWith('auto_stop_expiry_'))
      .toList();

  for (final key in keys) {
    final alarmId = int.tryParse(key.replaceFirst('auto_stop_expiry_', ''));
    if (alarmId == null) continue;

    final expiryStr = prefs.getString(key);
    final expiry = expiryStr != null ? DateTime.tryParse(expiryStr) : null;
    if (expiry == null || expiry.isBefore(DateTime.now())) continue;

    final context = await AlarmContextResolver.instance.resolveAlarmContext(alarmId);
    if (context == null) continue;
    await _scheduleAutoStopTimer(context);
  }
}

@pragma('vm:entry-point')
Future<void> handleAlarmRing(AlarmSettings settings) async {
  if (_wasHandledRecently(settings.id)) return;
  _markHandledNow(settings.id);
  debugPrint("handleAlarmRing: ID=${settings.id}");

  final context = await AlarmContextResolver.instance.resolveAlarmContext(settings.id);
  if (context == null) {
    debugPrint("handleAlarmRing: Unresolved alarm context for ID=${settings.id}");
    await _clearAlarmRuntimeState(settings.id);
    await Alarm.stop(settings.id);
    return;
  }

  final autoStopTtl =
      context.isGroup ? const Duration(minutes: 15) : const Duration(minutes: 30);

  if (context.mode == 'notification') {
    debugPrint("handleAlarmRing: notification-only mode for ID=${settings.id}");
    await Alarm.stop(settings.id);

    // Show a human-readable slot name, not the raw slotKey (e.g. "custom_uuid_0")
    String _slotLabel(String key) {
      if (key.startsWith('custom')) return 'Custom Time Reminder';
      switch (key) {
        case 'morning': return 'Morning Medicines';
        case 'afternoon': return 'Afternoon Medicines';
        case 'evening': return 'Evening Medicines';
        case 'night': return 'Night Medicines';
        default: return 'Medicine Reminder';
      }
    }
    final title = context.isGroup
        ? _slotLabel((context.slotKey ?? '').split('_').first)
        : context.medicineNames.first;
    final body = context.isGroup ? context.medicineNames.join(', ') : context.dosages.first;

    await AlarmService.instance.showActionNotification(
      alarmId: settings.id,
      medicineName: title,
      dosage: body,
      scheduledTime: context.scheduledTime,
    );

    await _persistAlarmRuntimeState(settings.id, autoStopTtl);
    await _scheduleAutoStopTimer(context);
    return;
  }

  // Fullscreen mode UI state
  await _persistAlarmRuntimeState(
    settings.id,
    autoStopTtl,
    markAsRinging: true,
  );
  await _scheduleAutoStopTimer(context);
  activeAlarmIdNotifier.value = settings.id;
}

Future<void> handleAlarmRingById(int alarmId) async {
  if (_wasHandledRecently(alarmId)) return;
  _markHandledNow(alarmId);
  
  final context = await AlarmContextResolver.instance.resolveAlarmContext(alarmId);
  if (context == null) {
    await _clearAlarmRuntimeState(alarmId);
    return;
  }

  if (context.mode == 'notification') return;

  final autoStopTtl =
      context.isGroup ? const Duration(minutes: 15) : const Duration(minutes: 30);
  await _persistAlarmRuntimeState(
    alarmId,
    autoStopTtl,
    markAsRinging: true,
  );
  await _scheduleAutoStopTimer(context);
  activeAlarmIdNotifier.value = alarmId;
}

@pragma('vm:entry-point')
void _onNotificationResponse(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();

  // C1: Since showsUserInterface:true is set, the app will be foregrounded.
  // This callback still fires but now runs in the main isolate (foreground),
  // so Supabase/Alarm are already initialized. We only need these as fallback.
  try {
    await Alarm.init();
  } catch (e) {
    debugPrint('[NotifResponse] Alarm.init failed: $e');
  }

  if (!_supabaseReady) {
    try {
      await dotenv.load(fileName: '.env');
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL'] ?? '',
        anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
      );
      _supabaseReady = true;
      debugPrint('[NotifResponse] Supabase initialized in background isolate OK');
    } catch (e) {
      // C1: Log this so we can diagnose background-isolate init failures
      debugPrint('[NotifResponse] ERROR: Supabase init failed in background: $e');
    }
  }

  final actionId = response.actionId ?? '';
  final payload = response.payload ?? '';

  int? alarmId;
  if (payload.startsWith('alarm_action_')) {
    alarmId = int.tryParse(payload.replaceFirst('alarm_action_', ''));
  }

  if (alarmId == null) return;

  final context = await AlarmContextResolver.instance.resolveAlarmContext(alarmId);
  if (context == null) return;

  // Clean up auto stop expiry whenever an explicit action is taken
  await _clearAlarmRuntimeState(alarmId);

  if (actionId.isEmpty) {
    // Body tap -> Open fullscreen app UI
    final autoStopTtl =
        context.isGroup ? const Duration(minutes: 15) : const Duration(minutes: 30);
    await _persistAlarmRuntimeState(
      alarmId,
      autoStopTtl,
      markAsRinging: true,
    );
    await _scheduleAutoStopTimer(context);
    activeAlarmIdNotifier.value = alarmId;
  } else if (actionId == 'took_it') {
    if (context.isSingle) {
      await AlarmActionEngine.instance.takeSingleDose(context);
    } else {
      await AlarmActionEngine.instance.takeGroupDoses(context, context.medicationIds);
    }
    medicineUpdatedNotifier.value++;
  } else if (actionId == 'snooze') {
    if (context.isSingle) {
      await AlarmActionEngine.instance.snoozeSingleDose(context, 30);
    } else {
      await AlarmActionEngine.instance.snoozeGroupDoses(context, context.medicationIds, 30);
    }
    medicineUpdatedNotifier.value++;
  } else if (actionId == 'skip') {
    if (context.isSingle) {
      await AlarmActionEngine.instance.skipSingleDose(context);
    } else {
      await AlarmActionEngine.instance.skipGroupDoses(context);
    }
    medicineUpdatedNotifier.value++;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    try {
      OpsTelemetryService.instance.recordCrash(details.exception, details.stack);
    } catch (_) {}
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    try {
      OpsTelemetryService.instance.recordCrash(error, stack);
    } catch (_) {}
    return true;
  };

  try {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await AlarmService.instance.notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onNotificationResponse,
    );
  } catch (e) {
    debugPrint("Early notification plugin init failed: $e");
  }

  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [MedicineEntitySchema],
    directory: dir.path,
  );

  runApp(ProviderScope(
    overrides: [
      isarProvider.overrideWithValue(isar),
    ],
    child: const MyApp(),
  ));

  await dotenv.load(fileName: '.env');
  try {
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
    );
    _supabaseReady = true;
  } catch (e) {
    debugPrint('Supabase init failed: $e');
  }

  // Use new recovery manager
  await AlarmRecoveryManager.instance.init();
  await _restorePendingAutoStopTimers();

  Alarm.ringStream.stream.listen((settings) {
    if (_supabaseReady) {
      handleAlarmRing(settings);
    }
  });

  await Alarm.init();
  await AlarmService.instance.init();
  
  // Initialize Offline Sync Background Listener
  OfflineSyncService.instance.initialize();

  // C4: Initialize WorkManager for background tasks (reschedule, cleanup, offline sync)
  // This was never called before, so all periodic background tasks were silently skipped.
  try {
    await initWorkManager();
  } catch (e) {
    debugPrint('[WorkManager] Init failed (non-critical): $e');
  }

  Timer.periodic(const Duration(hours: 1), (_) {
    if (_recentlyHandledAlarmIds.length > 200) {
      final cutoff = DateTime.now().subtract(const Duration(minutes: 10));
      _recentlyHandledAlarmIds.removeWhere((_, ts) => ts.isBefore(cutoff));
    }
  });

  FGBGEvents.instance.stream.listen((event) async {
    if (event == FGBGType.foreground) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final storedAlarmId = prefs.getInt('ringing_alarm_id');
        if (storedAlarmId != null && storedAlarmId != -1) {
          prefs.remove('ringing_alarm_id');
          handleAlarmRingById(storedAlarmId);
        }
      } catch (_) {}
    }
  });

  _alarmChannel.setMethodCallHandler((call) async {
    if (call.method == 'onAlarmRing') {
      final alarmId = call.arguments as int;
      handleAlarmRingById(alarmId);
    }
  });
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
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
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'FamCare',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: activeAlarmId != null
          ? _AlarmScreenWrapper(alarmId: activeAlarmId)
          : const SplashScreen(),
    );
  }
}



class _AlarmNavObserver extends NavigatorObserver {
  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    activeAlarmIdNotifier.value = null;
    Alarm.init().then((_) => AlarmService.instance.init());
  }
}

class _AlarmScreenWrapper extends StatefulWidget {
  final int alarmId;
  const _AlarmScreenWrapper({required this.alarmId});

  @override
  State<_AlarmScreenWrapper> createState() => _AlarmScreenWrapperState();
}

class _AlarmScreenWrapperState extends State<_AlarmScreenWrapper> {
  bool _isLoading = true;

  bool _isGroup = false;

  @override
  void initState() {
    super.initState();
    _checkContext();
  }

  Future<void> _checkContext() async {
    final context = await AlarmContextResolver.instance.resolveAlarmContext(widget.alarmId);
    if (context == null) {
      if (mounted) {
        activeAlarmIdNotifier.value = null;
      }
      return;
    }
    
    if (mounted) {
      setState(() {
        _isGroup = context.isGroup;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1117),
        body: SizedBox.expand(),
      );
    }

    return Navigator(
      observers: [_AlarmNavObserver()],
      onGenerateRoute: (_) => PageRouteBuilder(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => _isGroup
            ? GroupAlarmScreen(alarmId: widget.alarmId)
            : AlarmScreen(alarmId: widget.alarmId),
      ),
    );
  }
}
