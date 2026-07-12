import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/family/medical_profile.dart';

class MedicalProfileService {
  final SupabaseClient _supabase;

  MedicalProfileService(this._supabase);

  static const String _offlineCacheKeyPrefix = 'medical_profile_';

  Future<MedicalProfile?> getProfile(String userId) async {
    try {
      final response = await _supabase
          .from('medical_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        final profile = MedicalProfile.fromMap(response);
        // Cache for offline access
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_offlineCacheKeyPrefix$userId', jsonEncode(profile.toMap()));
        return profile;
      }
    } catch (e) {
      // Fallback to offline cache
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('$_offlineCacheKeyPrefix$userId');
      if (cachedStr != null) {
        return MedicalProfile.fromMap(jsonDecode(cachedStr));
      }
    }
    return null;
  }

  Future<void> upsertProfile(Map<String, dynamic> input) async {
    await _supabase
        .from('medical_profiles')
        .upsert(input);
        
    // Invalidate/update cache
    if (input['user_id'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_offlineCacheKeyPrefix${input['user_id']}', jsonEncode(input));
    }
  }
}
