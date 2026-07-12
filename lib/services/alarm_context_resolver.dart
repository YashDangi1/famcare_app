import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/alarm_context.dart';

class AlarmContextResolver {
  static final AlarmContextResolver instance = AlarmContextResolver._internal();
  factory AlarmContextResolver() => instance;
  AlarmContextResolver._internal();

  Future<AlarmContext?> resolveAlarmContext(int alarmId) async {
    final singleContext = await resolveSingleAlarmContext(alarmId);
    if (singleContext != null) return singleContext;

    final groupContext = await resolveGroupAlarmContext(alarmId);
    if (groupContext != null) return groupContext;

    debugPrint("Failed to resolve AlarmContext for ID: $alarmId");
    return null;
  }

  Future<AlarmContext?> resolveSingleAlarmContext(int alarmId) async {
    final cache = await readSingleAlarmCache(alarmId);
    if (cache != null) {
      return AlarmContext(
        alarmId: alarmId,
        originalAlarmId: cache['original_alarm_id'] as int,
        isSnooze: cache['is_snooze'] as bool? ?? false,
        isRetry: false,
        alarmType: 'single',
        mode: cache['mode'] as String? ?? 'fullscreen',
        scheduledTime: DateTime.parse(cache['scheduled_time'] as String),
        slotKey: cache['slot_key'] as String?,
        slotIndex: cache['slot_index'] as int?,
        medicationIds: [cache['medication_id'] as String],
        medicineNames: [cache['medicine_name'] as String],
        dosages: [cache['dosage'] as String],
        imagePaths: [cache['image_path'] as String?],
        fromCache: true,
        fromDb: false,
      );
    }

    // Fallback to DB logic if cache is missing
    final dbMed = await findMedicationByOriginalAlarmId(alarmId);
    if (dbMed != null) {
      return AlarmContext(
        alarmId: alarmId,
        originalAlarmId: alarmId,
        isSnooze: false, // If from DB directly without cache, it's original
        isRetry: false,
        alarmType: 'single',
        mode: 'fullscreen',
        scheduledTime: DateTime.now(), // Fallback
        slotKey: null,
        slotIndex: deriveSlotIndex(dbMed, alarmId),
        medicationIds: [dbMed['id'] as String],
        medicineNames: [dbMed['name'] as String],
        dosages: [dbMed['dosage'] as String? ?? ''],
        imagePaths: [dbMed['image_path'] as String?],
        fromCache: false,
        fromDb: true,
      );
    }

    return null;
  }

  Future<AlarmContext?> resolveGroupAlarmContext(int alarmId) async {
    final cache = await readGroupAlarmCache(alarmId);
    if (cache != null) {
      return AlarmContext(
        alarmId: alarmId,
        originalAlarmId: cache['original_alarm_id'] as int,
        isSnooze: false,
        isRetry: cache['is_retry'] as bool? ?? false,
        alarmType: 'group',
        mode: cache['mode'] as String? ?? 'fullscreen',
        scheduledTime: DateTime.parse(cache['scheduled_time'] as String),
        slotKey: cache['slot_key'] as String?,
        slotIndex: slotIndexFromSlotKey(cache['slot_key'] as String?),
        medicationIds: List<String>.from(cache['medication_ids'] as List),
        medicineNames: List<String>.from(cache['medicine_names'] as List),
        dosages: cache['dosages'] != null ? List<String>.from(cache['dosages'] as List) : List.filled((cache['medicine_names'] as List).length, ''),
        imagePaths: List.filled((cache['medicine_names'] as List).length, null),
        fromCache: true,
        fromDb: false,
      );
    }
    return null;
  }

  Future<Map<String, dynamic>?> readSingleAlarmCache(int alarmId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('cached_med_$alarmId');
    if (data != null) {
      try {
        return jsonDecode(data) as Map<String, dynamic>;
      } catch (e) {
        debugPrint("Error parsing single cache: $e");
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> readGroupAlarmCache(int alarmId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('group_alarm_$alarmId');
    if (data != null) {
      try {
        return jsonDecode(data) as Map<String, dynamic>;
      } catch (e) {
        debugPrint("Error parsing group cache: $e");
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> findMedicationByOriginalAlarmId(int originalAlarmId) async {
    // C3: Fixed dead code — this loop was completely empty and always returned null.
    // Now we actually try to reconstruct which medication this alarm ID belongs to
    // by re-generating the slot-based alarm IDs and comparing them.
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final res = await supabase
          .from('medications')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true);

      // The alarm IDs are generated by AlarmService.generateSlotAlarmId(slotKey).
      // For single-medicine alarms from prescription_screen, the slotKey format is
      // 'custom_{medId}_0'. We regenerate and check for each active medication.
      for (final med in res) {
        final medId = med['id'] as String?;
        if (medId == null) continue;

        // Check custom time slots
        final customTimes = med['custom_times'];
        final times = customTimes is List ? customTimes : <dynamic>[];
        for (int i = 0; i < times.length; i++) {
          final slotKey = 'custom_${medId}_$i';
          final generatedId = _generateSlotAlarmId(slotKey);
          if (generatedId == originalAlarmId) {
            debugPrint("DB fallback: matched alarm $originalAlarmId to med $medId via slotKey=$slotKey");
            return med as Map<String, dynamic>;
          }
        }

        // Check standard slot types (morning, afternoon, evening, night)
        final slotTypes = med['slot_types'];
        final slots = slotTypes is List ? slotTypes : <dynamic>[];
        for (final slot in slots) {
          if (slot == 'custom') continue; // handled above
          final slotKey = slot.toString();
          final generatedId = _generateSlotAlarmId(slotKey);
          if (generatedId == originalAlarmId) {
            debugPrint("DB fallback: matched alarm $originalAlarmId to med $medId via slotKey=$slotKey");
            return med as Map<String, dynamic>;
          }
        }
      }

      debugPrint("DB fallback: no match found for alarm ID $originalAlarmId");
    } catch (e) {
      debugPrint("DB fallback resolution failed: $e");
    }
    return null;
  }

  /// Mirrors AlarmService.generateSlotAlarmId() to reconstruct alarm IDs from slot keys.
  int _generateSlotAlarmId(String slotKey, {bool isRetry = false}) {
    final hash = slotKey.hashCode.abs();
    final base = (hash % 400000) + 10000;
    return isRetry ? base + 400000 : base;
  }

  int deriveSlotIndex(Map<String, dynamic> med, int originalAlarmId) {
    return 1; // Default
  }

  int slotIndexFromSlotKey(String? slotKey) {
    if (slotKey == null) return 1;
    if (slotKey.startsWith('morning')) return 1;
    if (slotKey.startsWith('afternoon')) return 2;
    if (slotKey.startsWith('evening')) return 3;
    if (slotKey.startsWith('night')) return 4;
    return 5; // custom
  }
}
