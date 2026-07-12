import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alarm_context.dart';
import 'alarm_service.dart';
import 'notification_service.dart';
import 'offline_sync_service.dart';
class DoseLogResult {
  final bool success;
  final bool inserted;
  final bool updated;
  final bool changedToTaken;
  final bool alreadyFinalized;

  const DoseLogResult({
    required this.success,
    this.inserted = false,
    this.updated = false,
    this.changedToTaken = false,
    this.alreadyFinalized = false,
  });

  bool get mutated => inserted || updated;
}

class AlarmActionEngine {
  static final AlarmActionEngine instance = AlarmActionEngine._internal();
  factory AlarmActionEngine() => instance;
  AlarmActionEngine._internal();

  final _supabase = Supabase.instance.client;

  // In-memory lock keyed by medication + scheduled_time to block local duplicate actions.
  final Map<String, bool> _activeLocks = {};

  List<String> _doseLockKeys(List<String> medicationIds, DateTime scheduledTime) {
    final timestamp = scheduledTime.toUtc().toIso8601String();
    return medicationIds.map((id) => '$id|$timestamp').toSet().toList()..sort();
  }

  Future<bool> _acquireActionLock(List<String> lockKeys) async {
    for (final key in lockKeys) {
      if (_activeLocks[key] == true) {
        debugPrint("ALARM ACTION LOCKED for key: $key - preventing duplicate.");
        return false;
      }
    }
    for (final key in lockKeys) {
      _activeLocks[key] = true;
    }
    return true;
  }

  void _releaseActionLock(List<String> lockKeys) {
    for (final key in lockKeys) {
      _activeLocks.remove(key);
    }
  }

  bool _isTerminalStatus(String status) => status != 'snoozed';

  bool _canPromoteStatus(String? existingStatus, String nextStatus) {
    if (existingStatus == null || existingStatus.isEmpty) return true;
    if (existingStatus == nextStatus) return false;
    if (_isTerminalStatus(existingStatus)) return false;
    return nextStatus != 'snoozed';
  }

  Future<void> takeSingleDose(AlarmContext context, {double? actualDose}) async {
    final lockKeys = _doseLockKeys(context.medicationIds, context.scheduledTime);
    if (!await _acquireActionLock(lockKeys)) return;
    try {
      final medicationId = context.medicationIds.first;
      final medicineName = context.medicineNames.first;
      final dosage = context.dosages.first;
      final logged = await takeDoseDirect(
        medicationId: medicationId,
        medicineName: medicineName,
        dosage: dosage,
        slotIndex: context.slotIndex ?? 1,
        scheduledTime: context.scheduledTime,
        overrideTakeAmt: actualDose,
      );
      if (!logged) return;

      await stopAlarmArtifacts(context);
      await cleanupAfterAction(context);
    } finally {
      _releaseActionLock(lockKeys);
    }
  }

  Future<void> snoozeSingleDose(AlarmContext context, int minutes) async {
    final lockKeys = _doseLockKeys(context.medicationIds, context.scheduledTime);
    if (!await _acquireActionLock(lockKeys)) return;
    try {
      final medicationId = context.medicationIds.first;
      final medicineName = context.medicineNames.first;
      final dosage = context.dosages.first;

      final snoozeAlarmId = await AlarmService.instance.scheduleSnoozeAlarm(
        originalId: context.originalAlarmId,
        medicineName: medicineName,
        originalTime: context.scheduledTime,
        snoozeDurationMinutes: minutes,
      );
      if (snoozeAlarmId == null) {
        throw Exception('Failed to schedule snooze alarm');
      }

      final result = await logDoseAction(
        medicationId: medicationId,
        medicineName: medicineName,
        dosage: dosage,
        status: 'snoozed',
        slotIndex: context.slotIndex ?? 1,
        scheduledTime: context.scheduledTime,
      );
      if (!result.success) {
        await AlarmService.instance.cancelAlarm(snoozeAlarmId);
        throw Exception('Failed to record snooze action');
      }

      await stopAlarmArtifacts(context);
      await cleanupAfterAction(context);
    } finally {
      _releaseActionLock(lockKeys);
    }
  }

  Future<void> skipSingleDose(AlarmContext context) async {
    final lockKeys = _doseLockKeys(context.medicationIds, context.scheduledTime);
    if (!await _acquireActionLock(lockKeys)) return;
    try {
      final medicationId = context.medicationIds.first;
      final medicineName = context.medicineNames.first;
      final dosage = context.dosages.first;

      final result = await logDoseAction(
        medicationId: medicationId,
        medicineName: medicineName,
        dosage: dosage,
        status: 'skipped',
        slotIndex: context.slotIndex ?? 1,
        scheduledTime: context.scheduledTime,
      );
      if (!result.success) return;

      await stopAlarmArtifacts(context);
      await cleanupAfterAction(context);
    } finally {
      _releaseActionLock(lockKeys);
    }
  }

  Future<void> missSingleDose(AlarmContext context) async {
    final lockKeys = _doseLockKeys(context.medicationIds, context.scheduledTime);
    if (!await _acquireActionLock(lockKeys)) return;
    try {
      final medicationId = context.medicationIds.first;
      final medicineName = context.medicineNames.first;
      final dosage = context.dosages.first;

      final result = await logDoseAction(
        medicationId: medicationId,
        medicineName: medicineName,
        dosage: dosage,
        status: 'missed',
        slotIndex: context.slotIndex ?? 1,
        scheduledTime: context.scheduledTime,
      );
      if (!result.success) return;

      await stopAlarmArtifacts(context);
      await cleanupAfterAction(context);
    } finally {
      _releaseActionLock(lockKeys);
    }
  }

  Future<void> takeGroupDoses(
    AlarmContext context,
    List<String> selectedMedicationIds, {
    bool takenEarlier = false,
  }) async {
    final lockKeys = _doseLockKeys(selectedMedicationIds, context.scheduledTime);
    if (!await _acquireActionLock(lockKeys)) return;
    try {
      for (int i = 0; i < context.medicationIds.length; i++) {
        final medId = context.medicationIds[i];
        if (selectedMedicationIds.contains(medId)) {
          try {
            await takeDoseDirect(
              medicationId: medId,
              medicineName: context.medicineNames[i],
              dosage: context.dosages[i],
              slotIndex: context.slotIndex ?? 1,
              scheduledTime: context.scheduledTime,
              takenEarlier: takenEarlier,
            );
          } catch (e) {
            debugPrint("Partial failure in takeGroupDoses: $e");
          }
        }
      }

      await stopAlarmArtifacts(context);
      await cleanupAfterAction(context);
    } finally {
      _releaseActionLock(lockKeys);
    }
  }

  Future<void> snoozeGroupDoses(
    AlarmContext context,
    List<String> remainingMedicationIds,
    int minutes,
  ) async {
    final lockKeys = _doseLockKeys(remainingMedicationIds, context.scheduledTime);
    if (!await _acquireActionLock(lockKeys)) return;
    try {
      final remainIds = <String>[];
      final remainNames = <String>[];
      final remainDosages = <String>[];

      for (int i = 0; i < context.medicationIds.length; i++) {
        final medId = context.medicationIds[i];
        if (remainingMedicationIds.contains(medId)) {
          remainIds.add(medId);
          remainNames.add(context.medicineNames[i]);
          remainDosages.add(context.dosages[i]);
        }
      }

      int? retryAlarmId;
      if (remainIds.isNotEmpty && context.slotKey != null) {
        final retryTime = DateTime.now().add(Duration(minutes: minutes));
        retryAlarmId = await AlarmService.instance.scheduleRetryAlarm(
          slot: context.slotKey!.split('_')[0],
          slotKey: context.slotKey!,
          retryTime: retryTime,
          originalScheduledTime: context.scheduledTime,
          remainingMedicationIds: remainIds,
          remainingMedicineNames: remainNames,
          remainingDosages: remainDosages,
        );
        if (retryAlarmId == null) {
          throw Exception('Failed to schedule retry alarm');
        }
      }

      for (int i = 0; i < context.medicationIds.length; i++) {
        final medId = context.medicationIds[i];
        if (remainingMedicationIds.contains(medId)) {
          try {
            final result = await logDoseAction(
              medicationId: medId,
              medicineName: context.medicineNames[i],
              dosage: context.dosages[i],
              status: 'snoozed',
              slotIndex: context.slotIndex ?? 1,
              scheduledTime: context.scheduledTime,
            );
            if (!result.success) {
               debugPrint('Partial failure: Failed to record snooze action for $medId');
            }
          } catch (e) {
            debugPrint('Partial failure in snoozeGroupDoses: $e');
          }
        }
      }

      await stopAlarmArtifacts(context);
      await cleanupAfterAction(context, removeRetryMarker: false);
    } finally {
      _releaseActionLock(lockKeys);
    }
  }

  Future<void> skipGroupDoses(
    AlarmContext context, {
    List<String>? medicationIds,
  }) async {
    final targetIds = medicationIds ?? context.medicationIds;
    final lockKeys = _doseLockKeys(targetIds, context.scheduledTime);
    if (!await _acquireActionLock(lockKeys)) return;
    try {
      for (int i = 0; i < context.medicationIds.length; i++) {
        final medId = context.medicationIds[i];
        if (targetIds.contains(medId)) {
          try {
            await logDoseAction(
              medicationId: medId,
              medicineName: context.medicineNames[i],
              dosage: context.dosages[i],
              status: 'skipped',
              slotIndex: context.slotIndex ?? 1,
              scheduledTime: context.scheduledTime,
            );
          } catch (e) {
            debugPrint("Partial failure in skipGroupDoses: $e");
          }
        }
      }

      await stopAlarmArtifacts(context);
      await cleanupAfterAction(context);
    } finally {
      _releaseActionLock(lockKeys);
    }
  }

  Future<void> missGroupDoses(
    AlarmContext context, {
    List<String>? medicationIds,
  }) async {
    final targetIds = medicationIds ?? context.medicationIds;
    final lockKeys = _doseLockKeys(targetIds, context.scheduledTime);
    if (!await _acquireActionLock(lockKeys)) return;
    try {
      for (int i = 0; i < context.medicationIds.length; i++) {
        final medId = context.medicationIds[i];
        if (targetIds.contains(medId)) {
          try {
            await logDoseAction(
              medicationId: medId,
              medicineName: context.medicineNames[i],
              dosage: context.dosages[i],
              status: 'missed',
              slotIndex: context.slotIndex ?? 1,
              scheduledTime: context.scheduledTime,
            );
          } catch (e) {
            debugPrint("Partial failure in missGroupDoses: $e");
          }
        }
      }

      await stopAlarmArtifacts(context);
      await cleanupAfterAction(context);
    } finally {
      _releaseActionLock(lockKeys);
    }
  }

  Future<bool> takeDoseDirect({
    required String medicationId,
    required String medicineName,
    required String dosage,
    required int slotIndex,
    required DateTime scheduledTime,
    bool takenEarlier = false,
    double? overrideTakeAmt,
    bool isPrn = false,
  }) async {
    final result = await logDoseAction(
      medicationId: medicationId,
      medicineName: medicineName,
      dosage: dosage,
      status: 'taken',
      slotIndex: slotIndex,
      scheduledTime: scheduledTime,
      takenEarlier: takenEarlier,
      actualDose: overrideTakeAmt,
      isPrn: isPrn,
    );
    if (!result.success) return false;
    if (result.changedToTaken) {
      double? parsedAmt = overrideTakeAmt;
      if (parsedAmt == null) {
        final match = RegExp(r'^([\d\.]+)').firstMatch(dosage);
        if (match != null) {
          parsedAmt = double.tryParse(match.group(1) ?? '');
        }
      }
      return decrementQtyAtomically(medicationId, overrideTakeAmt: parsedAmt);
    }
    return true;
  }

  Future<bool> skipDoseDirect({
    required String medicationId,
    required String medicineName,
    required String dosage,
    required int slotIndex,
    required DateTime scheduledTime,
  }) async {
    final result = await logDoseAction(
      medicationId: medicationId,
      medicineName: medicineName,
      dosage: dosage,
      status: 'skipped',
      slotIndex: slotIndex,
      scheduledTime: scheduledTime,
    );
    return result.success;
  }

  Future<DoseLogResult> logDoseAction({
    required String medicationId,
    required String medicineName,
    required String dosage,
    required String status,
    required int slotIndex,
    required DateTime scheduledTime,
    bool takenEarlier = false,
    double? actualDose,
    bool isPrn = false,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return const DoseLogResult(success: false);
      }

      final scheduledIso = scheduledTime.toIso8601String();
      
      // Handle PRN special case (don't dedup PRN logs based on time slot)
      if (!isPrn) {
        final rows = List<Map<String, dynamic>>.from(
          await _supabase
              .from('medicine_logs')
              .select('id,status,created_at')
              .eq('user_id', userId)
              .eq('medication_id', medicationId)
              .eq('scheduled_time', scheduledIso)
              .order('created_at', ascending: false),
        );

        Map<String, dynamic>? terminalRow;
        Map<String, dynamic>? snoozedRow;
        for (final row in rows) {
          final rowStatus = (row['status'] as String?) ?? '';
          if (_isTerminalStatus(rowStatus)) {
            terminalRow ??= row;
          } else if (rowStatus == 'snoozed') {
            snoozedRow ??= row;
          }
        }

        if (terminalRow != null) {
          return DoseLogResult(success: true, alreadyFinalized: true);
        }

        if (_canPromoteStatus((snoozedRow?['status'] as String?), status) && snoozedRow != null) {
          await _supabase.from('medicine_logs').update({
            'medicine_name': medicineName,
            'dosage': dosage,
            'status': status,
            'alarm_slot': slotIndex,
            'created_at': DateTime.now().toIso8601String(),
            if (actualDose != null) 'actual_dose': actualDose,
            'is_prn': isPrn,
            'administered_by': userId,
          }).eq('id', snoozedRow['id']);
          return DoseLogResult(success: true, updated: true, changedToTaken: status == 'taken');
        }

        if (snoozedRow != null && status == 'snoozed') {
          return const DoseLogResult(success: true, alreadyFinalized: true);
        }
      }

      // Insert new log
      final actionPayload = {
        'user_id': userId,
        'medication_id': medicationId,
        'medicine_name': medicineName,
        'dosage': dosage,
        'status': status,
        'alarm_slot': slotIndex,
        'scheduled_time': scheduledIso,
        'created_at': DateTime.now().toIso8601String(),
        if (actualDose != null) 'actual_dose': actualDose,
        'is_prn': isPrn,
        'administered_by': userId,
      };

      await _supabase.from('medicine_logs').insert(actionPayload);
      
      return DoseLogResult(
        success: true,
        inserted: true,
        changedToTaken: status == 'taken',
      );
    } catch (e) {
      if (OfflineSyncService.isOfflineError(e) || e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        debugPrint("Network offline, queuing dose action...");
        final actionPayload = {
          'user_id': _supabase.auth.currentUser?.id,
          'medication_id': medicationId,
          'medicine_name': medicineName,
          'dosage': dosage,
          'status': status,
          'alarm_slot': slotIndex,
          'scheduled_time': scheduledTime.toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          if (actualDose != null) 'actual_dose': actualDose,
          'is_prn': isPrn,
          'administered_by': _supabase.auth.currentUser?.id,
        };
        await OfflineSyncService.instance.enqueueAction(
          type: 'medicine_logs_insert',
          payload: actionPayload,
        );
        return DoseLogResult(
          success: true,
          inserted: true,
          changedToTaken: status == 'taken',
        );
      }
      debugPrint("Error logging dose action: $e");
      return const DoseLogResult(success: false);
    }
  }

  Future<bool> decrementQtyAtomically(String medicationId, {double? overrideTakeAmt}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      try {
        await _supabase.rpc('decrement_medicine_qty_v3', params: {
          'p_med_id': medicationId,
          'p_user_id': userId,
          if (overrideTakeAmt != null) 'p_override_take_amt': overrideTakeAmt,
        });
        return true;
      } catch (e) {
        debugPrint('RPC decrement fallback: $e');
        if (OfflineSyncService.isOfflineError(e) || e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
          debugPrint("Network offline during RPC, queuing decrement action...");
          await OfflineSyncService.instance.enqueueAction(
            type: 'medications_decrement_qty',
            payload: {
              'id': medicationId,
              'user_id': userId,
              if (overrideTakeAmt != null) 'decrement_by': overrideTakeAmt,
            },
          );
          return true; // Assume success locally so alarm stops
        }
      }

      for (int attempt = 0; attempt < 2; attempt++) {
        final res = await _supabase
            .from('medications')
            .select('qty, take_amount, refill_reminder_threshold, low_stock_alerted, name, frequency')
            .eq('id', medicationId)
            .maybeSingle();
        if (res == null) break;

        final currentQty = (res['qty'] as num?)?.toInt() ?? 0;
        final takeAmtRaw = res['take_amount']?.toString() ?? '1';
        final dbTakeAmt = double.tryParse(takeAmtRaw) ?? 1.0;
        final takeAmt = overrideTakeAmt ?? dbTakeAmt;
        
        final frequency = (res['frequency'] as num?)?.toInt() ?? 1;
        final threshold = (res['refill_reminder_threshold'] as num?)?.toInt() ?? (frequency * 3);
        final alreadyAlerted = res['low_stock_alerted'] == true;

        if (currentQty <= 0) {
          return true;
        }

        final newQty = (currentQty - takeAmt).clamp(0, 999999).toInt();
        final isActive = newQty > 0;
        final shouldAlert = newQty <= threshold && !alreadyAlerted;

        final updated = await _supabase
            .from('medications')
            .update({
              'qty': newQty,
              'is_active': isActive,
              if (shouldAlert) 'low_stock_alerted': true,
            })
            .eq('id', medicationId)
            .eq('qty', currentQty)
            .select('id')
            .maybeSingle();
            
        if (updated != null) {
          if (shouldAlert) {
            final medName = res['name'] as String? ?? 'Medicine';
            // Show Local Notification
            await NotificationService.instance.showLocalNotification(
              title: 'Low Stock Alert',
              body: '$medName has only $newQty left. Please refill soon!',
            );
            // Send WhatsApp Alert to Caregiver
            await NotificationService.instance.sendLowStockAlert(medName, newQty);
          }
          return true;
        }
      }
      return true;
    } catch (e) {
      if (OfflineSyncService.isOfflineError(e) || e.toString().contains('SocketException') || e.toString().contains('TimeoutException')) {
        debugPrint("Network offline during fallback, queuing decrement action...");
        await OfflineSyncService.instance.enqueueAction(
          type: 'medications_decrement_qty',
          payload: {
            'id': medicationId,
            'user_id': _supabase.auth.currentUser?.id,
            if (overrideTakeAmt != null) 'decrement_by': overrideTakeAmt,
          },
        );
        return true;
      }
      debugPrint("Error decrementing qty: $e");
      return false;
    }
  }

  Future<void> stopAlarmArtifacts(AlarmContext context) async {
    await AlarmService.instance.cancelAlarm(context.alarmId);
    // C6: Also cancel the action notification in case we're in notification mode.
    // Without this, after auto-stop timer fires (missed), the notification stays
    // permanently in the notification bar with no way to dismiss it.
    try {
      await AlarmService.instance.notificationsPlugin.cancel(context.alarmId);
    } catch (e) {
      debugPrint("Error cancelling notification for alarm ${context.alarmId}: $e");
    }
  }

  Future<void> cleanupAfterAction(
    AlarmContext context, {
    bool removeRetryMarker = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auto_stop_expiry_${context.alarmId}');
    final ringingAlarmId = prefs.getInt('ringing_alarm_id');
    if (ringingAlarmId == context.alarmId) {
      await prefs.remove('ringing_alarm_id');
    }

    if (context.isSingle) {
      await prefs.remove('cached_med_${context.alarmId}');
      if (context.isSnooze) {
         await prefs.remove('cached_med_${context.originalAlarmId}');
      }
    } else {
      await prefs.remove('group_alarm_${context.alarmId}');
      if (context.slotKey != null) {
        await prefs.remove('active_group_alarm_${context.slotKey}');
        if (removeRetryMarker) {
          await prefs.remove('active_retry_alarm_${context.slotKey}');
        }
      }
    }
  }
}
