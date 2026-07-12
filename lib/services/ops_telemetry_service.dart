import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';

class OpsTelemetryService {
  static final OpsTelemetryService instance = OpsTelemetryService._internal();
  factory OpsTelemetryService() => instance;
  OpsTelemetryService._internal();

  final _supabase = Supabase.instance.client;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<void> logEvent(String eventName, {Map<String, dynamic>? payload}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      await _supabase.from('analytics_events').insert({
        'user_id': userId,
        'event_name': eventName,
        'payload': payload ?? {},
      });
      debugPrint('OpsTelemetryService: Logged event "$eventName"');
    } catch (e) {
      debugPrint('OpsTelemetryService: Failed to log event "$eventName": $e');
    }
  }

  Future<void> recordCrash(dynamic error, StackTrace? stackTrace) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      Map<String, dynamic> deviceData = {};

      try {
        if (Platform.isAndroid) {
          final info = await _deviceInfo.androidInfo;
          deviceData = {'model': info.model, 'version': info.version.release};
        } else if (Platform.isIOS) {
          final info = await _deviceInfo.iosInfo;
          deviceData = {'model': info.model, 'version': info.systemVersion};
        } else if (Platform.isWindows) {
          final info = await _deviceInfo.windowsInfo;
          deviceData = {'model': 'Windows', 'version': info.majorVersion.toString()};
        }
      } catch (e) {
         // Ignore device info errors during crash recording
      }

      await _supabase.from('crash_logs').insert({
        'user_id': userId,
        'error_message': error.toString(),
        'stack_trace': stackTrace?.toString(),
        'device_info': deviceData,
      });
      debugPrint('OpsTelemetryService: Crash log recorded successfully.');
    } catch (e) {
      debugPrint('OpsTelemetryService: Failed to record crash: $e');
    }
  }
}
