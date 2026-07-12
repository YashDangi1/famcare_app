import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:alarm/alarm.dart';
import 'package:permission_handler/permission_handler.dart';

class AlarmService {
  static final AlarmService instance = AlarmService._internal();
  factory AlarmService() => instance;
  AlarmService._internal();

  static const int kSnoozeOffset = 900000;

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    await _requestPermissions();

    final alarms = await Alarm.getAlarms();
    debugPrint("Active alarms on startup: ${alarms.length}");
    for (final a in alarms) {
      debugPrint(
          "  ID:${a.id} -> ${a.dateTime} (${a.dateTime.isAfter(DateTime.now()) ? 'FUTURE' : 'PAST'})");
    }
  }

  Future<void> _requestPermissions() async {
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
    if (await Permission.systemAlertWindow.isDenied) {
      await Permission.systemAlertWindow.request();
    }
  }

  Future<bool> _shouldUseFullScreenIntent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('alarm_style_fullscreen') ?? true;
  }

  Future<bool> scheduleAlarm({
    required int id,
    required String medicationId,
    required String medicineName,
    required String dosage,
    required int qty,
    required String? imagePath,
    required DateTime time,
    required int slotIndex,
    String? slotKey,
  }) async {
    final useFullScreenIntent = await _shouldUseFullScreenIntent();
    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: time,
      assetAudioPath: 'assets/alarm.mp3',
      loopAudio: true,
      vibrate: true,
      volumeSettings: VolumeSettings.fade(
        volume: 1.0,
        volumeEnforced: true,
        fadeDuration: const Duration(seconds: 3),
      ),
      notificationSettings: NotificationSettings(
        title: medicineName,
        body: dosage,
        stopButton: null,
      ),
      warningNotificationOnKill: true,
      androidFullScreenIntent: useFullScreenIntent,
    );

    final success = await Alarm.set(alarmSettings: alarmSettings);

    if (!success) {
      debugPrint("WARNING: Alarm.set() returned false for ID=$id. Falling back to local notification.");
      await _fallbackToLocalNotification(
        id: id,
        title: medicineName,
        body: dosage,
        time: time,
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_med_$id', jsonEncode({
        'alarm_id': id,
        'original_alarm_id': id,
        'type': 'single',
        'medication_id': medicationId,
        'medicine_name': medicineName,
        'dosage': dosage,
        'qty': qty,
        'image_path': imagePath,
        'scheduled_time': time.toIso8601String(),
        'slot_index': slotIndex,
        'slot_key': slotKey,
        'is_snooze': false,
        'mode': useFullScreenIntent ? 'fullscreen' : 'notification',
      }));
    } catch (e) {
      debugPrint("Error caching alarm med data: $e");
    }

    // C11: Return actual result — true if alarm was set, false if we fell back to local notification
    return success;
  }

  Future<void> cancelAlarm(int id) async {
    await Alarm.stop(id);
    await notificationsPlugin.cancel(id);
  }

  Future<void> cancelAlarmsForMedicine(List<int?> alarmIds) async {
    for (final id in alarmIds) {
      if (id != null) {
        await Alarm.stop(id);
        await notificationsPlugin.cancel(id);
      }
    }
  }

  Future<int?> scheduleSnoozeAlarm({
    required int originalId,
    required String medicineName,
    required DateTime originalTime,
    int snoozeDurationMinutes = 30,
  }) async {
    final useFullScreenIntent = await _shouldUseFullScreenIntent();
    final fromNow = DateTime.now().add(Duration(minutes: snoozeDurationMinutes));
    final snoozeTime = fromNow;

    final snoozeId = originalId + kSnoozeOffset;

    final success = await Alarm.set(
      alarmSettings: AlarmSettings(
        id: snoozeId,
        dateTime: snoozeTime,
        assetAudioPath: 'assets/alarm.mp3',
        loopAudio: true,
        vibrate: true,
        volumeSettings: VolumeSettings.fade(
          volume: 1.0,
          volumeEnforced: true,
          fadeDuration: const Duration(seconds: 3),
        ),
        notificationSettings: NotificationSettings(
          title: medicineName,
          body: 'Snoozed Reminder',
          stopButton: null,
        ),
        warningNotificationOnKill: true,
        androidFullScreenIntent: useFullScreenIntent,
      ),
    );
    if (!success) return null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final originalCache = prefs.getString('cached_med_$originalId');
      if (originalCache != null) {
        final Map<String, dynamic> data = jsonDecode(originalCache);
        data['alarm_id'] = snoozeId;
        data['is_snooze'] = true;
        // MUST keep original scheduled_time intact
        await prefs.setString('cached_med_$snoozeId', jsonEncode(data));
      }
    } catch (e) {
      debugPrint("Error caching snooze med data: $e");
    }

    return snoozeId;
  }

  Future<int?> scheduleGroupSlotAlarm({
    required String slot,
    required String slotKey,
    required DateTime alarmTime,
    required List<String> medicationIds,
    required List<String> medicineNames,
    required List<String> dosages,
  }) async {
    final useFullScreenIntent = await _shouldUseFullScreenIntent();
    final alarmId = generateSlotAlarmId(slotKey);

    final title = _slotDisplayName(slotKey.split('_')[0]);
    final body = medicineNames.length == 1
        ? medicineNames.first
        : '${medicineNames.take(3).join(', ')}${medicineNames.length > 3 ? ' +${medicineNames.length - 3} more' : ''}';

    final success = await Alarm.set(
      alarmSettings: AlarmSettings(
        id: alarmId,
        dateTime: alarmTime,
        assetAudioPath: 'assets/alarm.mp3',
        loopAudio: true,
        vibrate: true,
        volumeSettings: VolumeSettings.fade(
          volume: 1.0,
          volumeEnforced: true,
          fadeDuration: const Duration(seconds: 3),
        ),
        notificationSettings: NotificationSettings(
          title: title,
          body: body,
          stopButton: null,
        ),
        warningNotificationOnKill: true,
        androidFullScreenIntent: useFullScreenIntent,
      ),
    );

    if (!success) return null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('group_alarm_$alarmId', jsonEncode({
      'alarm_id': alarmId,
      'original_alarm_id': alarmId,
      'type': 'group',
      'slot_key': slotKey,
      'slot_label': slot,
      'scheduled_time': alarmTime.toIso8601String(),
      'medication_ids': medicationIds,
      'medicine_names': medicineNames,
      'dosages': dosages,
      'is_retry': false,
      'mode': useFullScreenIntent ? 'fullscreen' : 'notification',
    }));
    await prefs.setInt('active_group_alarm_$slotKey', alarmId);

    return alarmId;
  }

  Future<int?> scheduleRetryAlarm({
    required String slot,
    required String slotKey,
    required DateTime retryTime,
    required DateTime originalScheduledTime,
    required List<String> remainingMedicationIds,
    required List<String> remainingMedicineNames,
    required List<String> remainingDosages,
  }) async {
    final useFullScreenIntent = await _shouldUseFullScreenIntent();
    final alarmId = generateSlotAlarmId(slotKey, isRetry: true);

    final title = '${_slotDisplayName(slotKey.split('_')[0])} - Reminder';
    final body = remainingMedicineNames.length == 1
        ? remainingMedicineNames.first
        : '${remainingMedicineNames.length} medicines pending';

    final success = await Alarm.set(
      alarmSettings: AlarmSettings(
        id: alarmId,
        dateTime: retryTime,
        assetAudioPath: 'assets/alarm.mp3',
        loopAudio: true,
        vibrate: true,
        volumeSettings: VolumeSettings.fade(
          volume: 1.0,
          volumeEnforced: true,
          fadeDuration: const Duration(seconds: 3),
        ),
        notificationSettings: NotificationSettings(
          title: title,
          body: body,
          stopButton: null,
        ),
        warningNotificationOnKill: true,
        androidFullScreenIntent: useFullScreenIntent,
      ),
    );

    if (!success) return null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('group_alarm_$alarmId', jsonEncode({
      'alarm_id': alarmId,
      'original_alarm_id': generateSlotAlarmId(slotKey),
      'type': 'group',
      'slot_key': slotKey,
      'slot_label': slot,
      'scheduled_time': originalScheduledTime.toIso8601String(),
      'medication_ids': remainingMedicationIds,
      'medicine_names': remainingMedicineNames,
      'dosages': remainingDosages,
      'is_retry': true,
      'mode': useFullScreenIntent ? 'fullscreen' : 'notification',
    }));
    await prefs.setInt('active_retry_alarm_$slotKey', alarmId);

    return alarmId;
  }

  Future<void> cancelSlotAlarms(String slotKey) async {
    final prefs = await SharedPreferences.getInstance();
    final groupId = prefs.getInt('active_group_alarm_$slotKey') ?? generateSlotAlarmId(slotKey);
    final retryId = prefs.getInt('active_retry_alarm_$slotKey') ?? generateSlotAlarmId(slotKey, isRetry: true);

    await Alarm.stop(groupId);
    await notificationsPlugin.cancel(groupId);
    await prefs.remove('active_group_alarm_$slotKey');
    await prefs.remove('group_alarm_$groupId');

    await Alarm.stop(retryId);
    await notificationsPlugin.cancel(retryId);
    await prefs.remove('active_retry_alarm_$slotKey');
    await prefs.remove('group_alarm_$retryId');
  }

  static int generateSlotAlarmId(String slotKey, {bool isRetry = false}) {
    final hash = slotKey.hashCode.abs();
    final base = (hash % 400000) + 10000;
    return isRetry ? base + 400000 : base;
  }

  String _slotDisplayName(String slot) {
    switch (slot) {
      case 'morning':
        return 'Morning Medicines';
      case 'afternoon':
        return 'Afternoon Medicines';
      case 'evening':
        return 'Evening Medicines';
      case 'night':
        return 'Night Medicines';
      default:
        return 'Medicine Reminder';
    }
  }

  Future<void> showActionNotification({
    required int alarmId,
    required String medicineName,
    required String dosage,
    required DateTime scheduledTime,
  }) async {
    final androidDetails = const AndroidNotificationDetails(
      'alarm_actions_channel',
      'Alarm Actions',
      channelDescription: 'Medicine alarm with action buttons',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: false,
      ongoing: true,
      autoCancel: false,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      playSound: false,
      actions: <AndroidNotificationAction>[
        // C1: showsUserInterface: true — brings the app to foreground so Supabase
        // is already initialized in the main isolate. Without this, actions run in
        // a background isolate where Supabase init silently fails.
        AndroidNotificationAction(
          'took_it',
          'I Took It',
          cancelNotification: true,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'snooze',
          'Snooze 30 Min',
          cancelNotification: true,
          showsUserInterface: true,
        ),
        AndroidNotificationAction(
          'skip',
          'Skip Dose',
          cancelNotification: true,
          showsUserInterface: true,
        ),
      ],
    );

    final details = NotificationDetails(android: androidDetails);

    await notificationsPlugin.show(
      alarmId,
      'Medicine Reminder',
      '$medicineName — $dosage',
      details,
      payload: 'alarm_action_$alarmId',
    );
  }

  Future<void> cleanupOrphanedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final alarms = await Alarm.getAlarms();
    final activeIds = alarms.map((a) => a.id).toSet();
    final pendingAutoStopIds = prefs
        .getKeys()
        .where((key) => key.startsWith('auto_stop_expiry_'))
        .map((key) => int.tryParse(key.replaceFirst('auto_stop_expiry_', '')))
        .whereType<int>()
        .toSet();
    
    final keys = prefs.getKeys().toList();
    for (final key in keys) {
      if (key.startsWith('cached_med_')) {
        final idStr = key.replaceFirst('cached_med_', '');
        final id = int.tryParse(idStr);
        if (id != null &&
            !activeIds.contains(id) &&
            !pendingAutoStopIds.contains(id)) {
          await prefs.remove(key);
        }
      } else if (key.startsWith('group_alarm_')) {
        final idStr = key.replaceFirst('group_alarm_', '');
        final id = int.tryParse(idStr);
        if (id != null &&
            !activeIds.contains(id) &&
            !pendingAutoStopIds.contains(id)) {
          await prefs.remove(key);
        }
      }
    }
  }

  Future<void> _fallbackToLocalNotification({
    required int id,
    required String title,
    required String body,
    required DateTime time,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'famcare_fallback_alarms',
      'Fallback Alarms',
      channelDescription: 'Used when full-screen alarms cannot be scheduled',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    
    if (time.isBefore(DateTime.now())) {
       time = time.add(const Duration(seconds: 5));
    }
    
    try {
      await notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(time, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
      debugPrint("Fallback notification scheduled (exact) for ID=$id at $time");
    } catch (e1) {
      // C12: Log the first failure, don't silently swallow it
      debugPrint("WARNING: Exact fallback notification failed for ID=$id: $e1 — trying inexact");
      try {
        await notificationsPlugin.zonedSchedule(
          id,
          title,
          body,
          tz.TZDateTime.from(time, tz.local),
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
        debugPrint("Fallback notification scheduled (inexact) for ID=$id at $time");
      } catch (e2) {
        // C12: Both attempts failed — log clearly so it can be diagnosed
        debugPrint("ERROR: Both fallback notification attempts failed for ID=$id. Exact: $e1, Inexact: $e2");
      }
    }
  }

  Future<void> scheduleDailySummary({
    required int taken,
    required int total,
  }) async {
    try {
      final now = DateTime.now();
      var summaryTime = DateTime(now.year, now.month, now.day, 22, 0);
      if (summaryTime.isBefore(now)) {
        summaryTime = summaryTime.add(const Duration(days: 1));
      }

      final missed = total - taken;
      final String body;
      if (total == 0) {
        body = 'Aaj koi medicine schedule nahi thi.';
      } else if (taken >= total) {
        body = 'Shabash! Aaj aapne sabhi $total medicines li. Streak jaari rakho!';
      } else {
        body = 'Aaj aapne $taken/$total medicines li. $missed miss hui.';
      }

      const androidDetails = AndroidNotificationDetails(
        'famcare_daily_summary',
        'Daily Summary',
        channelDescription: 'Nightly medicine summary',
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails);

      await notificationsPlugin.zonedSchedule(
        999999,
        'Daily Medicine Summary',
        body,
        tz.TZDateTime.from(summaryTime, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {}
  }
}
