import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/medicine_model.dart';
import '../repositories/medication_repository.dart';
import 'isar_provider.dart';

// Provider for the repository
final medicationRepositoryProvider = Provider<MedicationRepository>((ref) {
  final isar = ref.watch(isarProvider);
  return MedicationRepository(Supabase.instance.client, isar);
});

// Provider for the list of medications
final medicationsProvider = StateNotifierProvider<MedicationNotifier, AsyncValue<List<Medicine>>>((ref) {
  final repository = ref.watch(medicationRepositoryProvider);
  return MedicationNotifier(repository);
});

class MedicationNotifier extends StateNotifier<AsyncValue<List<Medicine>>> {
  final MedicationRepository _repository;

  MedicationNotifier(this._repository) : super(const AsyncValue.loading());

  Future<void> fetchMedications(String userId, {bool showLoading = true}) async {
    try {
      if (showLoading) {
        state = const AsyncValue.loading();
      }
      
      // 1. Fetch instantly from local Isar cache
      final localMeds = await _repository.fetchLocalMedications(userId);
      state = AsyncValue.data(localMeds);
      
      // 2. Sync with remote Supabase in the background
      final remoteMeds = await _repository.syncRemoteMedications(userId);
      
      // 3. Update UI if remote had changes
      if (mounted) {
        state = AsyncValue.data(remoteMeds);
      }
    } catch (e, st) {
      if (!state.hasValue) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> addMedication(Medicine medicine, String userId) async {
    try {
      if (state.hasValue) {
        final currentMeds = state.value!;
        state = AsyncValue.data([...currentMeds, medicine]);
      }
      await _repository.addMedication(medicine, userId);
      fetchMedications(userId, showLoading: false);
    } catch (e) {
      fetchMedications(userId, showLoading: false);
      throw Exception('Failed to add medication: $e');
    }
  }

  Future<void> updateMedication(Medicine medicine, String userId) async {
    try {
      if (state.hasValue) {
        final currentMeds = state.value!;
        state = AsyncValue.data([
          for (final m in currentMeds)
            if (m.id == medicine.id) medicine else m
        ]);
      }
      await _repository.updateMedication(medicine);
      fetchMedications(userId, showLoading: false);
    } catch (e) {
      fetchMedications(userId, showLoading: false);
      throw Exception('Failed to update medication: $e');
    }
  }

  Future<void> deleteMedication(String id, String userId) async {
    try {
      if (state.hasValue) {
        final currentMeds = state.value!;
        state = AsyncValue.data(currentMeds.where((m) => m.id != id).toList());
      }
      await _repository.deleteMedication(id);
      fetchMedications(userId, showLoading: false);
    } catch (e) {
      fetchMedications(userId, showLoading: false);
      throw Exception('Failed to delete medication: $e');
    }
  }
}
