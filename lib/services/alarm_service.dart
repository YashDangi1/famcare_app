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

  /// Offset added to an alarm's original ID to create its snooze ID.
  /// Any alarm with id > kSnoozeOffset is a snooze.
  static const int kSnoozeOffset = 900000;

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
      await prefs.setString('cached_med_$id', jsonEncode({
        'id': '',
        'name': medicineName,
        'dosage': dosage,
        'qty': 0,
        'image_path': imagePath,
      }));
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

    final snoozeId = originalId + kSnoozeOffset;

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

  /// Schedules one alarm for an entire slot group of medicines.
  /// Returns the alarm ID, or null if scheduling failed.
  Future<int?> scheduleGroupSlotAlarm({
    required String slot,
    required String slotKey,
    required DateTime alarmTime,
    required List<String> medicineNames,
    required String medicationIdsJson,
  }) async {
    final alarmId = await _nextSlotAlarmId();

    final title = _slotDisplayName(slotKey.split('_')[0]);
    final body = medicineNames.length == 1
        ? medicineNames.first
        : '${medicineNames.take(3).join(', ')}'
            '${medicineNames.length > 3 ? ' +${medicineNames.length - 3} more' : ''}';

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
        androidFullScreenIntent: true,
      ),
    );

    if (!success) return null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('group_alarm_$alarmId', jsonEncode({
      'slot': slot,
      'slot_key': slotKey,
      'alarm_time': alarmTime.toIso8601String(),
      'medicine_names': medicineNames,
      'medication_ids': jsonDecode(medicationIdsJson),
      'is_retry': false,
    }));

    debugPrint('Group alarm set: ID=$alarmId slot=$slotKey at $alarmTime');
    return alarmId;
  }

  /// Schedules a retry alarm for remaining unticked medicines in a slot.
  Future<int?> scheduleRetryAlarm({
    required String slot,
    required String slotKey,
    required DateTime retryTime,
    required List<String> remainingMedicineNames,
    required String remainingMedicationIdsJson,
  }) async {
    final alarmId = await _nextSlotAlarmId();

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
        androidFullScreenIntent: true,
      ),
    );

    if (!success) return null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('group_alarm_$alarmId', jsonEncode({
      'slot': slot,
      'slot_key': slotKey,
      'alarm_time': retryTime.toIso8601String(),
      'medicine_names': remainingMedicineNames,
      'medication_ids': jsonDecode(remainingMedicationIdsJson),
      'is_retry': true,
    }));

    debugPrint('Retry alarm set: ID=$alarmId slot=$slotKey at $retryTime');
    return alarmId;
  }

  /// Cancels the active group alarm and retry alarm for a slot key.
  Future<void> cancelSlotAlarms(String slotKey) async {
    final prefs = await SharedPreferences.getInstance();
    final groupId = prefs.getInt('active_group_alarm_$slotKey');
    final retryId = prefs.getInt('active_retry_alarm_$slotKey');

    if (groupId != null) {
      await Alarm.stop(groupId);
      await prefs.remove('active_group_alarm_$slotKey');
      await prefs.remove('group_alarm_$groupId');
    }
    if (retryId != null) {
      await Alarm.stop(retryId);
      await prefs.remove('active_retry_alarm_$slotKey');
      await prefs.remove('group_alarm_$retryId');
    }
  }

  /// Generates a unique alarm ID using a monotonic counter stored in SharedPreferences.
  /// Avoids hashCode collisions and is deterministic across isolates.
  static const int _maxSlotAlarmId = 800000;

static Future<int> _nextSlotAlarmId() async {
  final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt('alarm_id_counter') ?? 1000;
    if (current >= _maxSlotAlarmId) {
      current = 1000;
      await prefs.setInt('alarm_id_counter', 1000);
      debugPrint('⚠️ Alarm ID counter reset to avoid snooze ID collision');
    }
    final next = current + 1;
  await prefs.setInt('alarm_id_counter', next);
  return next;
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
