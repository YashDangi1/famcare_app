import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'activity_service.dart';
import 'offline_sync_service.dart';

class VitalsService {
  final _supabase = Supabase.instance.client;

  Future<void> saveVitals({
    int? bpSystolic,
    int? bpDiastolic,
    int? heartRate,
    int? spo2,
    double? weight,
    double? temperature,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception("User not authenticated");

    final payload = {
      'user_id': user.id,
      'bp_systolic': bpSystolic,
      'bp_diastolic': bpDiastolic,
      'heart_rate': heartRate,
      'spo2': spo2,
      'weight': weight,
      'temperature': temperature,
      'measured_at': DateTime.now().toIso8601String(),
    };

    try {
      await _supabase.from('vitals').insert(payload);
    } catch (e) {
      if (OfflineSyncService.isOfflineError(e)) {
        await OfflineSyncService.instance.enqueueAction(
          type: 'vitals_insert',
          payload: payload,
        );
      } else {
        rethrow;
      }
    }

    // Log activity for new vitals
    try {
      String description = 'Logged a new vital reading';
      if (bpSystolic != null) description = 'Logged new Blood Pressure reading';
      else if (heartRate != null) description = 'Logged new Heart Rate reading';
      else if (spo2 != null) description = 'Logged new SpO2 reading';
      else if (weight != null) description = 'Logged new Weight reading';
      else if (temperature != null) description = 'Logged new Temperature reading';

      await ActivityService.log(
        actionType: 'VITALS_ADDED',
        description: description,
      );
    } catch (e) {
      debugPrint('Log error: $e');
    }
  }

  Future<Map<String, dynamic>?> getLatestVitals({String? userId}) async {
    final uid = userId ?? _supabase.auth.currentUser?.id;
    if (uid == null) return null;

    return await _supabase
        .from('vitals')
        .select()
        .eq('user_id', uid)
        .order('measured_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> getVitalsHistory({String? userId}) async {
    final uid = userId ?? _supabase.auth.currentUser?.id;
    if (uid == null) return [];

    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();

    return await _supabase
        .from('vitals')
        .select()
        .eq('user_id', uid)
        .gte('measured_at', sevenDaysAgo)
        .order('measured_at', ascending: false);
  }
}
