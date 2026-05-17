import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
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

    // Init local notifications for non-alarm use
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await notificationsPlugin.initialize(settings);

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

  /// Schedules a real device alarm that rings even when app is closed
  Future<int> scheduleAlarm({
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
        body: 'Time for your $dosage dose!',
        stopButton: 'Dismiss',
      ),
      warningNotificationOnKill: true,
      androidFullScreenIntent: true,
    );
    await Alarm.set(alarmSettings: alarmSettings);

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
    return id;
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
          body: 'Reminder: Time for your medication',
          stopButton: 'Dismiss',
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
}
