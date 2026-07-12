import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/health/symptom_entry.dart';
import '../activity_service.dart';
import 'package:flutter/foundation.dart';

class SymptomsService {
  final _supabase = Supabase.instance.client;

  Future<List<SymptomEntry>> listSymptoms({String? userId, String? type, DateTime? from, DateTime? to}) async {
    final uid = userId ?? _supabase.auth.currentUser?.id;
    if (uid == null) return [];

    var query = _supabase.from('symptoms').select().eq('user_id', uid);

    if (type != null && type.isNotEmpty) {
      query = query.eq('symptom_type', type);
    }
    if (from != null) {
      query = query.gte('started_at', from.toUtc().toIso8601String());
    }
    if (to != null) {
      query = query.lte('started_at', to.toUtc().toIso8601String());
    }

    final response = await query.order('started_at', ascending: false);
    return (response as List).map((json) => SymptomEntry.fromJson(json)).toList();
  }

  Future<SymptomEntry> createSymptom(SymptomEntry symptom) async {
    final json = symptom.toJson();
    // Use maybeSingle instead of single
    final response = await _supabase.from('symptoms').insert(json).select().maybeSingle();

    if (response == null) {
      throw Exception('Failed to insert symptom');
    }

    final createdSymptom = SymptomEntry.fromJson(response);

    try {
      await ActivityService.log(
        actionType: 'SYMPTOM_LOGGED',
        description: 'Logged a symptom: ${createdSymptom.symptomType} (Severity: ${createdSymptom.severity}/5)',
      );
    } catch (e) {
      debugPrint('Log activity error: $e');
    }

    return createdSymptom;
  }

  Future<SymptomEntry> updateSymptom(SymptomEntry symptom) async {
    if (symptom.id == null) {
      throw Exception('Cannot update symptom without an ID');
    }

    final json = symptom.toJson();
    json.remove('id'); // Remove id from payload
    json['updated_at'] = DateTime.now().toUtc().toIso8601String();

    final response = await _supabase.from('symptoms').update(json).eq('id', symptom.id!).select().maybeSingle();
    
    if (response == null) {
      throw Exception('Failed to update symptom');
    }

    return SymptomEntry.fromJson(response);
  }

  Future<void> deleteSymptom(String id) async {
    await _supabase.from('symptoms').delete().eq('id', id);
  }
}
