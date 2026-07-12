import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/family/family_update.dart';

class FamilyUpdateService {
  final SupabaseClient _supabase;

  FamilyUpdateService(this._supabase);

  Future<List<FamilyUpdate>> listUpdates(String groupId, {String? patientUserId}) async {
    var query = _supabase
        .from('family_updates')
        .select('*, author:profiles!family_updates_author_user_id_fkey(full_name, avatar_url)')
        .eq('group_id', groupId);

    if (patientUserId != null) {
      query = query.eq('patient_user_id', patientUserId);
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List).map((map) {
      final update = FamilyUpdate.fromMap(map);
      // Inject author details into a new Map if we need to display it on UI
      // Since FamilyUpdate doesn't have an authorName field, we can dynamically add it to a UI layer or
      // return a wrapped object. For now, we will just return a map to the UI.
      // Wait, let's just return a list of maps for the UI so we get both FamilyUpdate and author data.
      return update;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> listUpdatesWithAuthor(String groupId, {String? patientUserId}) async {
    var query = _supabase
        .from('family_updates')
        .select('*, author:profiles!family_updates_author_user_id_fkey(full_name, avatar_url)')
        .eq('group_id', groupId);

    if (patientUserId != null) {
      query = query.eq('patient_user_id', patientUserId);
    }

    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<FamilyUpdate> createUpdate(Map<String, dynamic> input) async {
    final response = await _supabase
        .from('family_updates')
        .insert(input)
        .select()
        .single();
    return FamilyUpdate.fromMap(response);
  }

  Future<void> pinUpdate(String updateId, bool isPinned) async {
    await _supabase
        .from('family_updates')
        .update({'is_pinned': isPinned})
        .eq('id', updateId);
  }

  Future<void> convertUpdateToTask(String updateId) async {
    // Stub: Usually invokes a Supabase Edge Function to parse NLP and generate a task
  }
}
