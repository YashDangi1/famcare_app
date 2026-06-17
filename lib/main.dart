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
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'models/medicine_entity.dart';
import 'providers/isar_provider.dart';
import 'screens/alarm_screen.dart';
import 'screens/group_alarm_screen.dart';
import 'main_app_shell.dart';
import 'services/alarm_service.dart';
import 'services/slot_preferences_service.dart';
import 'splash_screen.dart';
import 'theme/app_theme.dart';
import 'providers/theme_provider.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Snooze offset: real alarm IDs are small; snoozes get originalId + kSnoozeOffset.
// Any alarm with id > kSnoozeOffset is a snooze.
const int kSnoozeOffset = 900000;

// Guard against double-calling (early listener + AlarmService listener both fire)
final Set<int> _handledAlarmIds = {};

// BUG 2: Guard against double-execution of notification action handlers
final Set<int> _handledNotificationActionIds = {};

// Tracks the alarm id that has a pending auto-stop notification scheduled.
int? _pendingAutoStopId;

// Global alarm state — when set, app shows ONLY the AlarmScreen (no home/nav)
// Value is the alarm ID. Null = show normal app.
final ValueNotifier<int?> activeAlarmIdNotifier = ValueNotifier(null);
final ValueNotifier<String?> activeSlotAlarmNotifier = ValueNotifier(null);

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

  if (await _handleGroupAlarmIfNeeded(settings.id)) {
    return;
  }

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

    final isSnooze = settings.id > kSnoozeOffset;
    final originalId = isSnooze ? settings.id - kSnoozeOffset : settings.id;

    // Check alarm style preference
    final prefs = await SharedPreferences.getInstance();
    final isFullScreen = prefs.getBool('alarm_style_fullscreen') ?? true;

    // === CACHE-FIRST lookup (supports slot-based retry alarms) ===
    Map<String, dynamic>? med;
    int slot = 1;

    final cached = prefs.getString('cached_med_$originalId');
    if (cached != null) {
      try {
        final cacheData = jsonDecode(cached) as Map<String, dynamic>;
        med = cacheData;
        slot = int.tryParse(cacheData['slot_index']?.toString() ?? cacheData['slot']?.toString() ?? '1') ?? 1;
        debugPrint("handleAlarmRing: Cache HIT for ID=$originalId — ${med['name']} slot=$slot");
      } catch (e) {
        debugPrint("handleAlarmRing: Cache parse error: $e");
      }
    }

    // === FALLBACK: DB lookup by alarm_id1/2/3 ===
    if (med == null) {
      debugPrint("handleAlarmRing: Cache MISS for ID=$originalId — trying DB lookup");

      Map<String, dynamic>? response;
      response = await supabase
          .from('medications')
          .select('*')
          .eq('alarm_id1', originalId)
          .maybeSingle()
          .timeout(const Duration(seconds: 5));

      if (response == null) {
        response = await supabase
            .from('medications')
            .select('*')
            .eq('alarm_id2', originalId)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));
      }

      if (response == null) {
        response = await supabase
            .from('medications')
            .select('*')
            .eq('alarm_id3', originalId)
            .maybeSingle()
            .timeout(const Duration(seconds: 5));
      }

      if (response == null) {
        debugPrint("No medication found for ID ${settings.id} — stopping");
        await Alarm.stop(settings.id);
        return;
      }

      med = response;
      if (med['alarm_id2'] == originalId) slot = 2;
      if (med['alarm_id3'] == originalId) slot = 3;
    }

    if (!isFullScreen) {
      debugPrint("Alarm style: Notification only — replacing with action notification");

      await AlarmService().showActionNotification(
        alarmId: settings.id,
        medicineName: med['name'] ?? 'Medicine',
        dosage: med['dosage'] ?? '1 dose',
        scheduledTime: settings.dateTime,
      );

      final autoStopId = settings.id;
      final medicineName = med['name'] ?? 'Medicine';

      // Persist expiry time so startup check can catch missed doses if app is killed
      try {
        final expiryTime = DateTime.now().add(const Duration(minutes: 30));
        await prefs.setString('auto_stop_expiry_$autoStopId', expiryTime.toIso8601String());
        await prefs.setString('auto_stop_medname_$autoStopId', medicineName);

        // Schedule a native auto-stop notification 30 min later.
        // This survives app kill; a Dart Timer would not.
        final tzExpiry = tz.TZDateTime.from(expiryTime, tz.local);
        await AlarmService().notificationsPlugin.zonedSchedule(
          autoStopId + 20000, // unique notification ID offset from alarm ID
          'Missed Dose',
          '$medicineName was not taken',
          tzExpiry,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'missed_dose_channel',
              'Missed Dose Alerts',
              channelDescription: 'Alerts for missed medications',
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (e) {
        debugPrint("Auto-stop schedule error: $e");
      }

      return;
    }

    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => AlarmScreen(
          alarmId: settings.id,
          isSnooze: isSnooze,
          medicineName: med!['name'] ?? 'Medicine',
          dosage: med['dosage'] ?? '1 dose',
          qty: int.tryParse(med['qty']?.toString() ?? '0') ?? 0,
          medicationId: med['id']?.toString() ?? '',
          alarmSlot: slot,
          scheduledTime: settings.dateTime,
          imagePath: med['image_path'],
        ),
      ),
    );
    debugPrint("AlarmScreen pushed for '${med['name']}' slot=$slot");
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

  if (await _handleGroupAlarmIfNeeded(alarmId)) {
    return;
  }

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

Future<bool> _handleGroupAlarmIfNeeded(int alarmId) async {
  final prefs = await SharedPreferences.getInstance();
  final groupData = prefs.getString('group_alarm_$alarmId');
  if (groupData == null) return false;

  debugPrint('Group slot alarm detected: ID=$alarmId');

  final decoded = jsonDecode(groupData) as Map<String, dynamic>;
  final slotKey = decoded['slot_key'] as String?;
  final medicineNames = decoded['medicine_names'] as List<dynamic>?;

  final isFullScreen = prefs.getBool('alarm_style_fullscreen') ?? true;
  
  if (!isFullScreen) {
    debugPrint("Alarm style: Notification only — replacing group alarm with action notification");
    
    // Trigger notification
    final medListString = medicineNames?.join(', ') ?? 'Medicines';
    String formattedSlot = slotKey ?? "Unknown";
    if (formattedSlot.startsWith('custom')) {
      formattedSlot = 'Custom Time';
    } else if (formattedSlot.isNotEmpty) {
      formattedSlot = formattedSlot[0].toUpperCase() + formattedSlot.substring(1);
    }

    await AlarmService().showActionNotification(
      alarmId: alarmId,
      medicineName: 'Slot: $formattedSlot',
      dosage: medListString,
      scheduledTime: DateTime.now(), // Approximate
    );
  }

  if (!isFullScreen) {
    // If we're not in full screen mode, we just return true.
    // We DON'T set the notifier here to avoid interrupting the user if the app is foreground.
    // The notifier will be set when the user taps the notification.
    return true;
  }

  activeSlotAlarmNotifier.value = slotKey;

  // Persist so startup can catch it if navigator isn't ready (killed state)
  try {
    final startupPrefs = await SharedPreferences.getInstance();
    if (slotKey != null) {
      await startupPrefs.setString('pending_group_slot_alarm', slotKey);
    }
  } catch (_) {}

  // Wait for navigator to be ready and app to be initialized
  int attempts = 0;
  while (navigatorKey.currentState == null && attempts < 20) {
    await Future.delayed(const Duration(milliseconds: 300));
    attempts++;
  }

  // Clear pending flag
  try {
    final clearPrefs = await SharedPreferences.getInstance();
    await clearPrefs.remove('pending_group_slot_alarm');
  } catch (_) {}
  return true;
}

// Handle notification action button taps (background — no UI)
// @pragma required for flutter_local_notifications background callback
@pragma('vm:entry-point')
void _onNotificationResponse(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (!_supabaseReady) {
    try {
      await dotenv.load(fileName: '.env');
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL'] ?? '',
        anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
      );
      _supabaseReady = true;
    } catch (e) {
      debugPrint("Background supabase init failed: $e");
    }
  }

  final actionId = response.actionId ?? '';
  final payload = response.payload ?? '';
  debugPrint("=== NOTIFICATION RESPONSE === actionId: $actionId, payload: $payload");

  if (actionId.isEmpty && payload.startsWith('alarm_action_')) {
    // User tapped the notification body
    final alarmId = int.tryParse(payload.replaceFirst('alarm_action_', ''));
    if (alarmId != null) {
      // Check if it's a group alarm
      final prefs = await SharedPreferences.getInstance();
      final groupData = prefs.getString('group_alarm_$alarmId');
      if (groupData != null) {
        final decoded = jsonDecode(groupData) as Map<String, dynamic>;
        final slotKey = decoded['slot_key'] as String?;
        if (slotKey != null) {
          activeSlotAlarmNotifier.value = slotKey;
        }
      } else {
        // Normal alarm fallback
        activeAlarmIdNotifier.value = alarmId;
      }
    }
  } else if (actionId.startsWith('took_it_')) {
    final alarmId = int.tryParse(actionId.replaceFirst('took_it_', ''));
    if (alarmId != null) await _handleNotificationTookIt(alarmId);
  } else if (actionId.startsWith('take_later_')) {
    final alarmId = int.tryParse(actionId.replaceFirst('take_later_', ''));
    if (alarmId != null) await _handleNotificationTakeLater(alarmId);
  } else if (payload.startsWith('auto_stop:')) {
    // Auto-stop notification fired: stop the ringing alarm + log missed dose.
    final targetId = int.tryParse(payload.replaceFirst('auto_stop:', ''));
    if (targetId != null) {
      try {
        await Alarm.stop(targetId);
        await _logAsMissed(targetId);
        final cleanPrefs = await SharedPreferences.getInstance();
        await cleanPrefs.remove('auto_stop_expiry_$targetId');
      } catch (e) {
        debugPrint("Auto-stop callback error: $e");
      }
      _pendingAutoStopId = null;
    }
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

    // Check if it's a group alarm
    final prefs = await SharedPreferences.getInstance();
    final groupData = prefs.getString('group_alarm_$alarmId');
    if (groupData != null) {
      debugPrint("Notification 'I Took It' for group alarm $alarmId");
      final decoded = jsonDecode(groupData) as Map<String, dynamic>;
      final slotKey = decoded['slot_key'] as String?;
      final medIdsJson = decoded['medication_ids'] as List<dynamic>?;
      
      if (slotKey != null && medIdsJson != null) {
        final medIds = medIdsJson.cast<String>();
        final slotStr = slotKey.startsWith('custom') ? 'custom' : slotKey;
        int slotIndex = 1;
        if (slotStr == 'morning') slotIndex = 1;
        else if (slotStr == 'afternoon') slotIndex = 2;
        else if (slotStr == 'evening') slotIndex = 3;
        else if (slotStr == 'night') slotIndex = 4;
        else slotIndex = 5;

        final supabase = Supabase.instance.client;
        final userId = supabase.auth.currentUser?.id;
        
        if (userId != null && _supabaseReady) {
          final scheduledStr = prefs.getString('alarm_scheduled_time_$alarmId');
          final scheduledTime = scheduledStr != null ? DateTime.parse(scheduledStr) : DateTime.now();

          for (final medId in medIds) {
             final med = await supabase.from('medications').select('*').eq('id', medId).maybeSingle().timeout(const Duration(seconds: 5));
             if (med == null) continue;

             final currentQty = int.tryParse(med['qty']?.toString() ?? '0') ?? 0;
             final newQty = (currentQty - 1).clamp(0, 99999);
             await supabase.from('medications').update({'qty': newQty}).eq('id', medId);
             if (newQty == 0) {
               await supabase.from('medications').update({'is_active': false}).eq('id', medId);
             }

             await supabase.from('medicine_logs').insert({
               'user_id': userId,
               'medication_id': medId,
               'medicine_name': med['name'] ?? 'Medicine',
               'dosage': med['dosage'] ?? '1 dose',
               'status': 'taken',
               'alarm_slot': slotIndex,
               'scheduled_time': scheduledTime.toIso8601String(),
               'created_at': DateTime.now().toIso8601String(),
             });
          }
        }
      }
      
      // Clean up
      try {
        await prefs.remove('group_alarm_$alarmId');
        await prefs.remove('alarm_scheduled_time_$alarmId');
      } catch (_) {}
      return;
    }

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
    final isSnooze = alarmId > kSnoozeOffset;
    final originalId = isSnooze ? alarmId - kSnoozeOffset : alarmId;

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
      await prefs.remove('auto_stop_expiry_$alarmId');
      _handledNotificationActionIds.remove(alarmId);
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

    // Check if it's a group alarm
    final prefs = await SharedPreferences.getInstance();
    final groupData = prefs.getString('group_alarm_$alarmId');
    if (groupData != null) {
      debugPrint("Notification 'Take Later' for group alarm $alarmId — scheduling retry");
      final decoded = jsonDecode(groupData) as Map<String, dynamic>;
      final slot = decoded['slot'] as String?;
      final slotKey = decoded['slot_key'] as String?;
      final medicineNames = decoded['medicine_names'] as List<dynamic>?;
      final medicationIds = decoded['medication_ids'] as List<dynamic>?;

      if (slot != null && slotKey != null && medicineNames != null && medicationIds != null) {
        // Wait for Supabase
        int attempts = 0;
        while (!_supabaseReady && attempts < 20) {
          await Future.delayed(const Duration(milliseconds: 300));
          attempts++;
        }
        if (!_supabaseReady) {
          debugPrint('Supabase not ready after timeout — cannot schedule retry');
          return;
        }

        // Get retry interval from preferences
        final slotPrefs = await SlotPreferencesService().getPreferences();
        final retryInterval = slotPrefs['retry_interval'] as int? ?? 30;
        final retryTime = DateTime.now().add(Duration(minutes: retryInterval));

        // Schedule retry alarm
        await AlarmService().scheduleRetryAlarm(
          slot: slot,
          slotKey: slotKey,
          retryTime: retryTime,
          remainingMedicineNames: medicineNames.cast<String>(),
          remainingMedicationIdsJson: jsonEncode(medicationIds),
        );
      }
      // Clean up
      try {
        await prefs.remove('group_alarm_$alarmId');
        await prefs.remove('alarm_scheduled_time_$alarmId');
      } catch (_) {}
      return;
    }

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
    final isSnooze = alarmId > kSnoozeOffset;
    final originalId = isSnooze ? alarmId - kSnoozeOffset : alarmId;

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

    // Schedule snooze from ORIGINAL scheduled time, not DateTime.now()
    final scheduledStr = prefs.getString('alarm_scheduled_time_$alarmId');
    final scheduledTime = scheduledStr != null
        ? DateTime.parse(scheduledStr)
        : DateTime.now();

    await AlarmService().scheduleSnoozeAlarm(
      originalId: originalId,
      medicineName: medicineName,
      originalTime: scheduledTime,
    );

    // Log as snoozed — use original scheduled time, not DateTime.now()
    if (userId != null && medId.isNotEmpty) {
      await supabase.from('medicine_logs').insert({
        'user_id': userId,
        'medication_id': medId,
        'medicine_name': medicineName,
        'dosage': dosage,
        'status': 'snoozed',
        'alarm_slot': slot,
        'scheduled_time': scheduledTime.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    // Clean up cache
    try {
      await prefs.remove('cached_med_$alarmId');
      await prefs.remove('alarm_scheduled_time_$alarmId');
      await prefs.remove('auto_stop_expiry_$alarmId');
      _handledNotificationActionIds.remove(alarmId);
    } catch (_) {}

    debugPrint("Notification 'Take Later' handled for alarm $alarmId");
  } catch (e) {
    debugPrint("Error handling notification take_later: $e");
  }
}

/// Check for alarms that expired while app was killed (CRITICAL 3 fix)
Future<void> _checkExpiredAutoStopAlarms() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('auto_stop_expiry_')).toList();

    for (final key in keys) {
      final alarmIdStr = key.replaceFirst('auto_stop_expiry_', '');
      final alarmId = int.tryParse(alarmIdStr);
      if (alarmId == null) continue;

      final expiryStr = prefs.getString(key);
      if (expiryStr == null) continue;

      final expiry = DateTime.parse(expiryStr);
      if (DateTime.now().isAfter(expiry)) {
        // Timer expired while app was killed — check if still unhandled
        if (!_handledNotificationActionIds.contains(alarmId)) {
          debugPrint("Startup: expired auto-stop alarm $alarmId — logging as missed");
          await _logAsMissed(alarmId);
          _handledNotificationActionIds.add(alarmId);
        }
        await prefs.remove(key);
      }
    }
  } catch (e) {
    debugPrint("Error checking expired auto-stop alarms: $e");
  }
}

/// Log alarm as missed when auto-stop timer fires (no action taken)
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
  tz_data.initializeTimeZones();

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
    // Check for pending group slot alarm (killed-state group alarm that couldn't navigate)
    final pendingSlot = prefs.getString('pending_group_slot_alarm');
    if (pendingSlot != null) {
      debugPrint("STARTUP: Found pending group slot alarm: $pendingSlot");
      activeSlotAlarmNotifier.value = pendingSlot;
      prefs.remove('pending_group_slot_alarm');
    }
  } catch (e) {
    debugPrint("Error checking stored alarm ID: $e");
  }

  // STEP 2: Show UI IMMEDIATELY — no blocking calls before runApp.
  // We only block for Isar which takes <10ms and is required for offline access.
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

  // STEP 3: Supabase init — runs AFTER runApp so UI shows instantly.
  // In alarm mode, _AlarmScreenWrapper shows loading screen while this runs.
  await dotenv.load(fileName: '.env');
  int supabaseRetries = 0;
  while (!_supabaseReady && supabaseRetries < 3) {
    try {
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL'] ?? '',
        anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
      );
      _supabaseReady = true;
    } catch (e) {
      supabaseRetries++;
      debugPrint('Supabase init attempt $supabaseRetries failed: $e');
      if (supabaseRetries < 3) {
        await Future.delayed(Duration(seconds: supabaseRetries * 2));
      }
    }
  }
  if (!_supabaseReady) {
    debugPrint('⚠️ Supabase failed after 3 attempts — app will work offline');
  }

  // Check for missed alarms that expired while app was killed
  _checkExpiredAutoStopAlarms();

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

    Timer.periodic(const Duration(hours: 1), (_) {
      if (_handledAlarmIds.length > 200) {
        _handledAlarmIds.clear();
        debugPrint('Pruned _handledAlarmIds');
      }
      if (_handledNotificationActionIds.length > 200) {
        _handledNotificationActionIds.clear();
      }
    });

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
    activeSlotAlarmNotifier.addListener(_onAlarmChanged);
  }

  @override
  void dispose() {
    activeAlarmIdNotifier.removeListener(_onAlarmChanged);
    activeSlotAlarmNotifier.removeListener(_onAlarmChanged);
    super.dispose();
  }

  void _onAlarmChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final activeAlarmId = activeAlarmIdNotifier.value;
    final activeSlotKey = activeSlotAlarmNotifier.value;
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      title: 'FamCare',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      // When alarm is active, show ONLY the AlarmScreen — no home, no nav
      home: activeAlarmId != null
          ? _AlarmScreenWrapper(alarmId: activeAlarmId)
          : activeSlotKey != null
              ? const _SlotAlarmWrapper()
              : const SplashScreen(),
    );
  }
}

/// Wrapper for slot alarms that navigates to GroupAlarmScreen when app starts up
class _SlotAlarmWrapper extends ConsumerStatefulWidget {
  const _SlotAlarmWrapper();

  @override
  ConsumerState<_SlotAlarmWrapper> createState() => _SlotAlarmWrapperState();
}

class _SlotAlarmWrapperState extends ConsumerState<_SlotAlarmWrapper> {
  @override
  void initState() {
    super.initState();
    // Wait for app to initialize, then navigate to HomeScreen so GroupAlarmScreen can open
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const MainAppShell(),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D1117),
      body: SizedBox.expand(),
    );
  }
}

// End of file

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
  DateTime _scheduledTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadFromCacheInstantly();
    _loadScheduledTime();
  }

  Future<void> _loadScheduledTime() async {
    try {
      final alarms = await Alarm.getAlarms();
      final match = alarms.where((a) => a.id == widget.alarmId).toList();
      if (match.isNotEmpty && mounted) {
        setState(() => _scheduledTime = match.first.dateTime);
      }
    } catch (_) {}
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
      final isSnooze = widget.alarmId > kSnoozeOffset;
      final originalId = isSnooze ? widget.alarmId - kSnoozeOffset : widget.alarmId;

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

    final isSnooze = widget.alarmId > kSnoozeOffset;
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
          scheduledTime: _scheduledTime,
          imagePath: _med!['image_path'],
        ),
      ),
    );
  }
}


