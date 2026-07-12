import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/health/symptoms_service.dart';
import '../../models/health/symptom_entry.dart';

final symptomsServiceProvider = Provider((ref) => SymptomsService());

final symptomsProvider = StateNotifierProvider<SymptomsNotifier, AsyncValue<List<SymptomEntry>>>((ref) {
  final service = ref.watch(symptomsServiceProvider);
  return SymptomsNotifier(service);
});

class SymptomsNotifier extends StateNotifier<AsyncValue<List<SymptomEntry>>> {
  final SymptomsService _service;

  SymptomsNotifier(this._service) : super(const AsyncValue.loading());

  Future<void> fetchSymptoms(String? userId) async {
    try {
      state = const AsyncValue.loading();
      final symptoms = await _service.listSymptoms(userId: userId);
      if (mounted) {
        state = AsyncValue.data(symptoms);
      }
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> addSymptom(SymptomEntry symptom, String? targetUserId) async {
    try {
      final newSymptom = await _service.createSymptom(symptom);
      if (state.hasValue && state.value != null) {
        state = AsyncValue.data([newSymptom, ...state.value!]);
      } else {
        await fetchSymptoms(targetUserId);
      }
    } catch (e) {
      // Re-throw so UI can handle errors
      rethrow;
    }
  }

  Future<void> updateSymptom(SymptomEntry symptom, String? targetUserId) async {
    try {
      final updatedSymptom = await _service.updateSymptom(symptom);
      if (state.hasValue && state.value != null) {
        final currentList = state.value!;
        final index = currentList.indexWhere((s) => s.id == symptom.id);
        if (index != -1) {
          final newList = List<SymptomEntry>.from(currentList);
          newList[index] = updatedSymptom;
          state = AsyncValue.data(newList);
        } else {
          await fetchSymptoms(targetUserId);
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteSymptom(String id, String? targetUserId) async {
    try {
      await _service.deleteSymptom(id);
      if (state.hasValue && state.value != null) {
        state = AsyncValue.data(
          state.value!.where((s) => s.id != id).toList()
        );
      }
    } catch (e) {
      rethrow;
    }
  }
}
