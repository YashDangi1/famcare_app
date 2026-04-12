import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryService {
  static final _supabase = Supabase.instance.client;

static Future<void> logAction({required String actionType, required String description}) async {
  try {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Current user ka group_id nikaalo
    final member = await Supabase.instance.client
        .from('family_members')
        .select('group_id')
        .eq('user_id', user.id)
        .maybeSingle();

    // Insertion
    await Supabase.instance.client.from('family_history').insert({
      'user_id': user.id,
      'group_id': member?['group_id'],
      'action_type': actionType,
      'description': description, // <--- Ab ye database ke 'description' se match karega
    });
    
    debugPrint('✅ Activity logged: $actionType');
  } catch (e) {
    debugPrint('❌ Error logging activity: $e');
  }
}
}