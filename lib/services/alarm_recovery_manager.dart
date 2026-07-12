import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'alarm_service.dart';
import 'alarm_context_resolver.dart';
import 'alarm_action_engine.dart';
import '../main.dart' show activeAlarmIdNotifier;

class AlarmRecoveryManager {
  static final AlarmRecoveryManager instance = AlarmRecoveryManager._internal();
  factory AlarmRecoveryManager() => instance;
  AlarmRecoveryManager._internal();

  Future<void> init() async {
    await checkExpiredAutoStopAlarms();
    await restoreActiveAlarmOnStartup();
    await cleanupOrphanedAlarmState();
  }

  Future<void> restoreActiveAlarmOnStartup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ringingAlarmId = prefs.getInt('ringing_alarm_id');
      if (ringingAlarmId == null || ringingAlarmId == -1) return;

      final expiryStr = prefs.getString('auto_stop_expiry_$ringingAlarmId');
      final expiry = expiryStr != null ? DateTime.tryParse(expiryStr) : null;
      if (expiry == null || DateTime.now().isAfter(expiry)) {
        return;
      }

      final context =
          await AlarmContextResolver.instance.resolveAlarmContext(ringingAlarmId);
      if (context == null || context.mode == 'notification') return;

      debugPrint('Startup: restoring active alarm UI for $ringingAlarmId');
      activeAlarmIdNotifier.value = ringingAlarmId;
    } catch (e) {
      debugPrint("Error restoring active alarm on startup: $e");
    }
  }

  Future<void> restorePendingGroupAlarmOnStartup() async {
    // Leftover from previous kill state
  }

  Future<void> checkExpiredAutoStopAlarms() async {
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
          debugPrint("Startup: expired auto-stop alarm $alarmId — logging as missed");
          await handleRecoveredMissedAlarm(alarmId);
          await prefs.remove(key);
          await prefs.remove('auto_stop_medname_$alarmId');
        }
      }
    } catch (e) {
      debugPrint("Error checking expired auto-stop alarms: $e");
    }
  }

  Future<void> handleRecoveredMissedAlarm(int alarmId) async {
    final context = await AlarmContextResolver.instance.resolveAlarmContext(alarmId);
    if (context != null) {
      if (context.isSingle) {
        await AlarmActionEngine.instance.missSingleDose(context);
      } else {
        await AlarmActionEngine.instance.missGroupDoses(context);
      }
    }
  }

  Future<void> cleanupOrphanedAlarmState() async {
    await AlarmService.instance.cleanupOrphanedPrefs();
  }
}
