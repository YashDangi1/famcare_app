import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:alarm/alarm.dart';
import 'package:permission_handler/permission_handler.dart';

class AlarmService {
  // Singleton pattern
  static final AlarmService instance = AlarmService._internal();
  factory AlarmService() => instance;
  AlarmService._internal();

  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Alarm.init() already called in main.dart — don't call again here
    tz.initializeTimeZones();

    // ringStream listener is already set up in main.dart (early listener)
    // Don't subscribe again — it's a single-subscription stream

    // Request permissions
    await _requestPermissions();

    // Note: notificationsPlugin.initialize() is called in main.dart
    // with the action button callback — don't initialize here

    // Log active alarms
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

  /// Schedules a real device alarm that rings even when app is closed.
  /// Returns true if alarm was successfully set, false otherwise.
  Future<bool> scheduleAlarm({
    required int id,
    required String medicineName,
    required String dosage,
    required String imagePath,
    required DateTime time,
  }) async {
    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: time,
      assetAudioPath: 'assets/alarm.mp3',
      loopAudio: true,
      vibrate: true,
      volumeSettings: VolumeSettings.fade(
        volume: 1.0,
        volumeEnforced: true,
        fadeDuration: Duration(seconds: 3),
      ),
      notificationSettings: NotificationSettings(
        title: medicineName,
        body: dosage,
        stopButton: null,  // Removes Dismiss button completely
      ),
      warningNotificationOnKill: true,
      androidFullScreenIntent: true,
    );

    final success = await Alarm.set(alarmSettings: alarmSettings);
    debugPrint("Alarm.set() returned: $success for ID=$id at $time ($medicineName)");

    if (!success) {
      debugPrint("WARNING: Alarm.set() returned false for ID=$id — alarm will NOT ring!");
      return false;
    }

    // Save medicine data for instant alarm screen — no DB needed
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString('cached_med_$id');
      if (existing == null) {
        await prefs.setString('cached_med_$id', jsonEncode({
          'id': '',
          'name': medicineName,
          'dosage': dosage,
          'qty': 0,
          'image_path': imagePath,
        }));
      }
    } catch (e) {
      debugPrint("Error caching alarm med data: $e");
    }

    debugPrint("Alarm set: ID=$id at $time for $medicineName");
    return true;
  }

  /// Cancels a single alarm
  Future<void> cancelAlarm(int id) async {
    await Alarm.stop(id);
    debugPrint("Alarm cancelled: ID=$id");
  }

  /// Cancels multiple alarms
  Future<void> cancelAlarmsForMedicine(List<int?> alarmIds) async {
    for (final id in alarmIds) {
      if (id != null) {
        await Alarm.stop(id);
      }
    }
  }

  /// Schedules a 30-minute snooze alarm from the original scheduled time
  Future<void> scheduleSnoozeAlarm({
    required int originalId,
    required String medicineName,
    required DateTime originalTime,
  }) async {
    final fromOriginal = originalTime.add(const Duration(minutes: 30));
    final fromNow = DateTime.now().add(const Duration(minutes: 5));
    final snoozeTime =
        fromOriginal.isAfter(fromNow) ? fromOriginal : fromNow;

    final snoozeId = originalId + 10000;

    await Alarm.set(
      alarmSettings: AlarmSettings(
        id: snoozeId,
        dateTime: snoozeTime,
        assetAudioPath: 'assets/alarm.mp3',
        loopAudio: true,
        vibrate: true,
        volumeSettings: VolumeSettings.fade(
          volume: 1.0,
          volumeEnforced: true,
          fadeDuration: Duration(seconds: 3),
        ),
        notificationSettings: NotificationSettings(
          title: '$medicineName (Snooze)',
          body: 'Time for your medication',
          stopButton: null,  // Removes Dismiss button completely
        ),
        warningNotificationOnKill: true,
        androidFullScreenIntent: true,
      ),
    );

    // Cache snooze data for instant AlarmScreen
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_med_$snoozeId', jsonEncode({
        'id': '',
        'name': medicineName,
        'dosage': 'Snooze',
        'qty': 0,
        'image_path': '',
      }));
    } catch (e) {
      debugPrint("Error caching snooze med data: $e");
    }

    debugPrint("Snooze alarm set: ID=$snoozeId at $snoozeTime");
  }

  /// Returns the end DateTime for a slot on a given date
  DateTime getSlotEndTime(String slot, DateTime date, Map<String, dynamic> prefs) {
    final endStr = prefs['${slot}_end'] ?? _defaultSlotEnd(slot);
    final parts = endStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// 6A — Calculates alarm time for a given slot.
  /// For 'custom' slots, uses the customTime directly.
  /// For standard slots, uses the slot start time from preferences.
  DateTime getAlarmTimeForSlot(
    String slot,
    TimeOfDay? customTime,
    DateTime date,
    Map<String, dynamic> prefs,
  ) {
    if (slot == 'custom' && customTime != null) {
      return DateTime(date.year, date.month, date.day,
          customTime.hour, customTime.minute);
    }

    final startStr = prefs['${slot}_start'] ?? _defaultSlotStart24(slot);
    final parts = startStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  /// 6C — Schedules slot-based alarms with retry logic.
  /// First alarm at slot_start + 20% of range duration,
  /// then repeats every 8 minutes until slot_end.
  Future<List<int>> scheduleSlotAlarms({
    required String medicationId,
    required String medicineName,
    required String dosage,
    required String? imagePath,
    required String slot,
    required DateTime date,
    required Map<String, dynamic> prefs,
    TimeOfDay? customTime,
    String? customTimeStr,
  }) async {
    final List<int> scheduledIds = [];
    final now = DateTime.now();

    // FIX 1: Cancel previously scheduled slot alarms for this medicine+slot
    try {
      final prefsInst = await SharedPreferences.getInstance();
      final cacheKey = 'slot_alarm_ids_${medicationId}_$slot';
      final cachedIds = prefsInst.getStringList(cacheKey) ?? [];
      for (final idStr in cachedIds) {
        final id = int.tryParse(idStr);
        if (id != null) {
          await Alarm.stop(id);
          debugPrint("  Cancelled old slot alarm ID=$id");
        }
      }
    } catch (e) {
      debugPrint("  Old slot alarm cleanup error: $e");
    }

    final slotStart = getAlarmTimeForSlot(slot, customTime, date, prefs);
    final slotEnd = getSlotEndTime(slot, date, prefs);

    debugPrint("=== SCHEDULE SLOT ALARMS ===");
    debugPrint("Medicine: $medicineName | Slot: $slot | Date: $date");
    debugPrint("Slot start: $slotStart | Slot end: $slotEnd | Now: $now");

    final rangeMins = slotEnd.difference(slotStart).inMinutes;
    debugPrint("Range: $rangeMins minutes");
    if (rangeMins <= 0) {
      debugPrint("SKIP: range <= 0 — no alarms scheduled");
      return scheduledIds;
    }

    // First alarm at slot_start + 20% of range
    final firstAlarmOffset = (rangeMins * 0.2).round();
    DateTime alarmTime = slotStart.add(Duration(minutes: firstAlarmOffset));
    debugPrint("First alarm target: $alarmTime (slot_start + ${firstAlarmOffset}min)");

    int loopCount = 0;
    while (alarmTime.isBefore(slotEnd)) {
      loopCount++;
      final isFuture = alarmTime.isAfter(now.subtract(const Duration(minutes: 1)));
      debugPrint("  Loop #$loopCount: alarmTime=$alarmTime isFuture=$isFuture");

      // Don't schedule past alarms
      if (isFuture) {
        final alarmId = await _nextSlotAlarmId();
        debugPrint("  -> Scheduling alarm ID=$alarmId at $alarmTime");

        try {
          final success = await scheduleAlarm(
            id: alarmId,
            medicineName: medicineName,
            dosage: dosage,
            imagePath: imagePath ?? '',
            time: alarmTime,
          );

          if (success) {
            // Cache slot info for alarm screen — ALWAYS overwrite
            try {
              final prefsInst = await SharedPreferences.getInstance();
              final cacheKey = 'cached_med_$alarmId';
              await prefsInst.setString(cacheKey, jsonEncode({
                'id': medicationId,
                'name': medicineName,
                'dosage': dosage,
                'qty': 0,
                'image_path': imagePath ?? '',
                'slot': slot,
                'slot_index': _slotIndex(slot),
                'scheduled_time': alarmTime.toIso8601String(),
              }));
              debugPrint("  -> Cache written for $cacheKey");
            } catch (e) {
              debugPrint("  -> Cache write FAILED: $e");
            }

            scheduledIds.add(alarmId);
          } else {
            debugPrint("  -> Alarm.set() returned false for ID=$alarmId — skipping");
          }
        } catch (e) {
          debugPrint("  -> scheduleAlarm EXCEPTION for ID=$alarmId: $e");
        }
      }

      alarmTime = alarmTime.add(const Duration(minutes: 8));
    }

    // FIX 1: Save new slot alarm IDs for future cancellation
    try {
      final prefsInst = await SharedPreferences.getInstance();
      final cacheKey = 'slot_alarm_ids_${medicationId}_$slot';
      await prefsInst.setStringList(cacheKey, scheduledIds.map((id) => id.toString()).toList());
      debugPrint("  Saved ${scheduledIds.length} slot alarm IDs for $cacheKey");
    } catch (e) {
      debugPrint("  Save slot alarm IDs error: $e");
    }

    // Verify alarms are actually registered
    try {
      final activeAlarms = await Alarm.getAlarms();
      final ourAlarms = activeAlarms.where((a) => scheduledIds.contains(a.id)).toList();
      debugPrint("=== RESULT: ${scheduledIds.length} requested, ${ourAlarms.length} confirmed active ===");
      for (final a in ourAlarms) {
        debugPrint("  Active alarm: ID=${a.id} at ${a.dateTime}");
      }
    } catch (e) {
      debugPrint("=== RESULT: ${scheduledIds.length} alarms scheduled (verify failed: $e) ===");
    }
    return scheduledIds;
  }

  /// Generates a unique alarm ID using a monotonic counter stored in SharedPreferences.
  /// Avoids hashCode collisions and is deterministic across isolates.
  static Future<int> _nextSlotAlarmId() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('alarm_id_counter') ?? 1000;
    final next = current + 1;
    await prefs.setInt('alarm_id_counter', next);
    return next;
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

  static String _defaultSlotStart24(String slot) {
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

  /// Helper for non-alarm notifications if needed
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    await notificationsPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm_channel',
          'Alarm Notifications',
          channelDescription: 'Critical medicine alarm notifications',
          importance: Importance.max,
          priority: Priority.max,
          fullScreenIntent: true,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          playSound: true,
          enableVibration: true,
        ),
      ),
    );
  }

  /// Show notification with action buttons for notification-only mode
  Future<void> showActionNotification({
    required int alarmId,
    required String medicineName,
    required String dosage,
    required DateTime scheduledTime,
  }) async {
    // Store scheduledTime for snooze calculation (read back in _handleNotificationTakeLater)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('alarm_scheduled_time_$alarmId', scheduledTime.toIso8601String());
    } catch (_) {}
    final androidDetails = AndroidNotificationDetails(
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
      playSound: false, // alarm sound already playing from native side
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'took_it_$alarmId',
          'I Took It',
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'take_later_$alarmId',
          'Take Later',
          cancelNotification: true,
        ),
      ],
    );

    final details = NotificationDetails(android: androidDetails);

    // Use SAME ID as alarm package — our notification replaces theirs
    await notificationsPlugin.show(
      alarmId,
      'Medicine Reminder',
      '$medicineName — $dosage',
      details,
      payload: 'alarm_action_$alarmId',
    );
  }

  /// 9A — Schedules a daily summary notification at 10:00 PM.
  /// Call this from _initDashboard() with today's summary content.
  /// Uses zonedSchedule with matchDateTimeComponents for daily repeat.
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
        999999, // Fixed ID for daily summary
        'Daily Medicine Summary',
        body,
        tz.TZDateTime.from(summaryTime, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at same time
      );

      debugPrint('Daily summary scheduled for $summaryTime: $body');
    } catch (e) {
      debugPrint('scheduleDailySummary error: $e');
    }
  }
}
