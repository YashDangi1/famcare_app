import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/medicine_model.dart';
import '../models/medicine_entity.dart';
import '../services/offline_sync_service.dart';

class MedicationRepository {
  final SupabaseClient _supabase;
  final Isar _isar;

  MedicationRepository(this._supabase, this._isar);

  Future<List<Medicine>> fetchLocalMedications(String userId) async {
    final entities = await _isar.medicineEntitys.filter().userIdEqualTo(userId).findAll();
    return entities.map((e) => Medicine.fromEntity(e)).toList();
  }

  Future<List<Medicine>> syncRemoteMedications(String userId) async {
    try {
      final data = await _supabase
          .from('medications')
          .select('*')
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      final remoteMeds = (data as List).map((m) => Medicine.fromJson(m)).toList();
      
      // Update local database
      await _isar.writeTxn(() async {
        // Clear old local records for this user that might have been deleted on another device
        await _isar.medicineEntitys.filter().userIdEqualTo(userId).deleteAll();
        
        // Save new records
        final entities = remoteMeds.map((m) => m.toEntity()).toList();
        await _isar.medicineEntitys.putAll(entities);
      });
      
      return remoteMeds;
    } catch (e) {
      // If offline, just return the local ones we already have
      return fetchLocalMedications(userId);
    }
  }

  Future<void> addMedication(Medicine medicine, String userId) async {
    // 1. Save locally first (optimistic)
    medicine = Medicine(
      id: medicine.id ?? 'local_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      name: medicine.name,
      dosage: medicine.dosage,
      frequency: medicine.frequency,
      time1: medicine.time1,
      time2: medicine.time2,
      time3: medicine.time3,
      alarmId1: medicine.alarmId1,
      alarmId2: medicine.alarmId2,
      alarmId3: medicine.alarmId3,
      startDate: medicine.startDate,
      durationDays: medicine.durationDays,
      qty: medicine.qty,
      counter: medicine.counter,
      isActive: medicine.isActive,
      isTaken: medicine.isTaken,
      imagePath: medicine.imagePath,
      createdAt: medicine.createdAt,
      slotTypes: medicine.slotTypes,
      customTimes: medicine.customTimes,
      scheduleType: medicine.scheduleType,
      everyXDays: medicine.everyXDays,
      specificDates: medicine.specificDates,
      notes: medicine.notes,
      isPaused: medicine.isPaused,
      lowStockAlerted: medicine.lowStockAlerted,
      form: medicine.form,
      color: medicine.color,
      strength: medicine.strength,
      strengthUnit: medicine.strengthUnit,
      takeAmount: medicine.takeAmount,
      foodInstruction: medicine.foodInstruction,
      isAsNeeded: medicine.isAsNeeded,
      refillReminderThreshold: medicine.refillReminderThreshold,
      condition: medicine.condition,
    );
    
    await _isar.writeTxn(() async {
      await _isar.medicineEntitys.put(medicine.toEntity());
    });

    // 2. Try to sync to Supabase
    try {
      final data = medicine.toJson();
      if (data['id'].toString().startsWith('local_')) {
        data.remove('id'); // Let Supabase generate the real UUID
      }
      
      final response = await _supabase.from('medications').insert(data).select().maybeSingle();
      
      // 3. Update local with real Supabase ID
      if (response != null) {
        final realMed = Medicine.fromJson(response);
        await _isar.writeTxn(() async {
          // delete the temporary local one
          await _isar.medicineEntitys.filter().supabaseIdEqualTo(medicine.id).deleteAll();
          // insert the real one
          await _isar.medicineEntitys.put(realMed.toEntity());
        });
      }
    } catch (e) {
      print('Warning: Supabase sync failed, queuing medication insert. $e');
      if (OfflineSyncService.isOfflineError(e)) {
        await OfflineSyncService.instance.enqueueAction(
          type: 'medications_insert',
          payload: medicine.toJson(),
        );
      }
    }
  }

  Future<void> updateMedication(Medicine medicine) async {
    // 1. Update locally
    await _isar.writeTxn(() async {
      await _isar.medicineEntitys.put(medicine.toEntity());
    });

    // 2. Try to sync remote
    try {
      if (medicine.id == null || medicine.id!.startsWith('local_')) return;
      await _supabase.from('medications').update(medicine.toJson()).eq('id', medicine.id!);
    } catch (e) {
      print('Warning: Supabase update failed, queuing medication update. $e');
      if (OfflineSyncService.isOfflineError(e)) {
        await OfflineSyncService.instance.enqueueAction(
          type: 'medications_update',
          payload: medicine.toJson(),
        );
      }
    }
  }

  Future<void> deleteMedication(String id) async {
    // 1. Delete locally
    await _isar.writeTxn(() async {
      await _isar.medicineEntitys.filter().supabaseIdEqualTo(id).deleteAll();
    });

    // 2. Try to delete remote
    try {
      if (id.startsWith('local_')) return;
      await _supabase.from('medications').delete().eq('id', id);
    } catch (e) {
      print('Warning: Supabase delete failed, queuing medication delete. $e');
      if (OfflineSyncService.isOfflineError(e)) {
        await OfflineSyncService.instance.enqueueAction(
          type: 'medications_delete',
          payload: {'id': id},
        );
      }
    }
  }
}
