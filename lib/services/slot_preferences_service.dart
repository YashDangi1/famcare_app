import 'package:supabase_flutter/supabase_flutter.dart';

class SlotPreferencesService {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getPreferences() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return _defaults();

    final result = await _supabase
        .from('user_slot_preferences')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    return result ?? _defaults();
  }

  Future<void> savePreferences(Map<String, dynamic> prefs) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _supabase.from('user_slot_preferences').upsert(
        {
          'user_id': userId,
          ...prefs,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id',
      );
    } catch (e) {
      if (e is PostgrestException && e.message.contains('retry_interval')) {
        final fallbackPrefs = Map<String, dynamic>.from(prefs)..remove('retry_interval');
        await _supabase.from('user_slot_preferences').upsert(
          {
            'user_id': userId,
            ...fallbackPrefs,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'user_id',
        );
      } else {
        rethrow;
      }
    }
  }

  Map<String, dynamic> _defaults() => {
    'morning_start': '08:00', 'morning_end': '09:30',
    'afternoon_start': '12:00', 'afternoon_end': '14:00',
    'evening_start': '16:00', 'evening_end': '18:00',
    'night_start': '21:00', 'night_end': '22:30',
    'retry_interval': 30,
  };
}
