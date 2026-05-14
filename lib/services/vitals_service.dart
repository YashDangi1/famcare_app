import 'package:supabase_flutter/supabase_flutter.dart';

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

    await _supabase.from('vitals').insert({
      'user_id': user.id,
      'bp_systolic': bpSystolic,
      'bp_diastolic': bpDiastolic,
      'heart_rate': heartRate,
      'spo2': spo2,
      'weight': weight,
      'temperature': temperature,
      'measured_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getLatestVitals() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    return await _supabase
        .from('vitals')
        .select()
        .eq('user_id', user.id)
        .order('measured_at', ascending: false)
        .limit(1)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> getVitalsHistory() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();

    return await _supabase
        .from('vitals')
        .select()
        .eq('user_id', user.id)
        .gte('measured_at', sevenDaysAgo)
        .order('measured_at', ascending: false);
  }
}
