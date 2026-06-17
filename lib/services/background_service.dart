import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'alarm_service.dart';
import 'offline_sync_service.dart';

/// PHASE 3: WorkManager-based background task names
const String kTaskRescheduleAlarms = 'reschedule_alarms_task';
const String kTaskCleanupPrefs = 'cleanup_prefs_task';
const String kTaskOfflineSync = 'offline_sync_task';

/// Top-level callback executed by WorkManager in a separate Isolate.
/// IMPORTANT: This runs isolated — no Flutter widgets, no Navigator.
/// Must be a top-level (or static) function annotated @pragma('vm:entry-point').
@pragma('vm:entry-point')
void workManagerCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('[WorkManager] Executing task: $taskName');
    try {
      switch (taskName) {
        case kTaskRescheduleAlarms:
          await _doRescheduleCheck();
          break;
        case kTaskCleanupPrefs:
          await AlarmService().cleanupOrphanedPrefs();
          break;
        case kTaskOfflineSync:
          await OfflineSyncService().attemptSync();
          break;
        default:
          debugPrint('[WorkManager] Unknown task: $taskName');
      }
    } catch (e) {
      debugPrint('[WorkManager] Task $taskName failed: $e');
    }
    return Future.value(true);
  });
}

/// Checks if any alarms need rescheduling by looking at a stored flag.
Future<void> _doRescheduleCheck() async {
  final prefs = await SharedPreferences.getInstance();
  final lastCheck = prefs.getInt('wm_last_reschedule_check') ?? 0;
  final now = DateTime.now().millisecondsSinceEpoch;

  // Debounce: only run if last check was > 30 minutes ago
  if (now - lastCheck < 30 * 60 * 1000) {
    debugPrint('[WorkManager] Reschedule check debounced — skipping');
    return;
  }
  await prefs.setInt('wm_last_reschedule_check', now);

  // Check if app has been killed for too long (> 6 hours) and alarms exist
  final alarmsScheduled = prefs.getBool('alarms_are_scheduled') ?? false;
  final lastAppOpen = prefs.getInt('last_app_open_ts') ?? 0;
  final hoursSinceOpen = (now - lastAppOpen) / (1000 * 60 * 60);

  if (alarmsScheduled && hoursSinceOpen > 6) {
    debugPrint('[WorkManager] App closed for ${hoursSinceOpen.toStringAsFixed(1)}h — flagging reschedule');
    await prefs.setBool('needs_alarm_reschedule_on_open', true);
  }

  // Always run prefs cleanup during reschedule check
  await AlarmService().cleanupOrphanedPrefs();
}

/// Initializes WorkManager with recurring tasks.
/// Call this once from main() after app startup.
Future<void> initWorkManager() async {
  await Workmanager().initialize(
    workManagerCallbackDispatcher,
    // isInDebugMode removed — deprecated, has no effect
  );

  // Register the reschedule check to run every 3 hours
  await Workmanager().registerPeriodicTask(
    kTaskRescheduleAlarms,
    kTaskRescheduleAlarms,
    frequency: const Duration(hours: 3),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: false,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  // Register weekly prefs cleanup
  await Workmanager().registerPeriodicTask(
    kTaskCleanupPrefs,
    kTaskCleanupPrefs,
    frequency: const Duration(days: 7),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  // Register offline sync task
  await Workmanager().registerPeriodicTask(
    kTaskOfflineSync,
    kTaskOfflineSync,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: false,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
  );

  debugPrint('[WorkManager] Background tasks registered: reschedule (3h), cleanup (7d), offline sync (15m)');
}
