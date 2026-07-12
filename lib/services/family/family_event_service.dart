import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/family/family_event.dart';

class FamilyEventService {
  final SupabaseClient _supabase;

  FamilyEventService(this._supabase);

  Future<List<FamilyEvent>> listEvents(String groupId, DateTime from, DateTime to) async {
    final response = await _supabase.rpc('rpc_get_family_calendar', params: {
      'p_group_id': groupId,
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
    });

    return (response as List).map((e) => FamilyEvent.fromMap(e)).toList();
  }

  Future<FamilyEvent> upsertEvent(Map<String, dynamic> input) async {
    final response = await _supabase
        .from('family_events')
        .upsert(input)
        .select()
        .single();
    
    return FamilyEvent.fromMap(response);
  }

  Future<void> deleteEvent(String eventId) async {
    await _supabase.from('family_events').delete().eq('id', eventId);
  }
}
