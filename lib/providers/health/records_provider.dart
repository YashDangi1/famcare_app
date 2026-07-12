import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../services/health/records_service.dart';
import '../../models/health/health_record.dart';

final recordsServiceProvider = Provider((ref) => RecordsService());

final recordsProvider = StateNotifierProvider<RecordsNotifier, AsyncValue<List<HealthRecord>>>((ref) {
  final service = ref.watch(recordsServiceProvider);
  return RecordsNotifier(service);
});

class RecordsNotifier extends StateNotifier<AsyncValue<List<HealthRecord>>> {
  final RecordsService _service;

  RecordsNotifier(this._service) : super(const AsyncValue.loading());

  Future<void> fetchRecords({String? userId, String? category}) async {
    try {
      state = const AsyncValue.loading();
      final records = await _service.listRecords(userId: userId, category: category);
      if (mounted) {
        state = AsyncValue.data(records);
      }
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> uploadRecord(HealthRecord record, File file, {String? targetUserId, String? currentCategory}) async {
    try {
      final newRecord = await _service.uploadRecord(record, file);
      
      if (state.hasValue && state.value != null) {
        // If the new record matches the current filter (or if we're showing all), add it to state
        bool matchesCategory = currentCategory == null || currentCategory == 'All' || 
             newRecord.category == currentCategory.toLowerCase().replaceAll(' ', '_');
             
        if (matchesCategory) {
          state = AsyncValue.data([newRecord, ...state.value!]);
        }
      } else {
        await fetchRecords(userId: targetUserId, category: currentCategory);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateRecord(HealthRecord record, {String? targetUserId, String? currentCategory}) async {
    try {
      final updatedRecord = await _service.updateRecord(record);
      if (state.hasValue && state.value != null) {
        final currentList = state.value!;
        final index = currentList.indexWhere((r) => r.id == record.id);
        
        bool matchesCategory = currentCategory == null || currentCategory == 'All' || 
             updatedRecord.category == currentCategory.toLowerCase().replaceAll(' ', '_');

        if (index != -1) {
          final newList = List<HealthRecord>.from(currentList);
          if (matchesCategory) {
            newList[index] = updatedRecord;
          } else {
            newList.removeAt(index);
          }
          state = AsyncValue.data(newList);
        } else {
          await fetchRecords(userId: targetUserId, category: currentCategory);
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteRecord(String id, {String? targetUserId, String? currentCategory}) async {
    try {
      await _service.deleteRecord(id);
      if (state.hasValue && state.value != null) {
        state = AsyncValue.data(
          state.value!.where((r) => r.id != id).toList()
        );
      }
    } catch (e) {
      rethrow;
    }
  }
}
