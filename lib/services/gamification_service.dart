import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class GamificationService {
  static final GamificationService instance = GamificationService._internal();
  factory GamificationService() => instance;
  GamificationService._internal();

  final _supabase = Supabase.instance.client;
  static const String _localKey = 'unlocked_achievements';

  /// Fetches unlocked achievements from Supabase and syncs with local storage
  Future<List<String>> getUnlockedAchievements() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> localUnlocked = prefs.getStringList(_localKey) ?? [];

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return localUnlocked;

      final response = await _supabase
          .from('user_achievements')
          .select('achievement_id')
          .eq('user_id', userId);

      final remoteUnlocked = (response as List).map((row) => row['achievement_id'] as String).toList();

      // Merge remote into local
      final merged = {...localUnlocked, ...remoteUnlocked}.toList();
      await prefs.setStringList(_localKey, merged);
      
      // If there are local achievements not in remote, sync them up
      final toSync = localUnlocked.where((id) => !remoteUnlocked.contains(id)).toList();
      for (final id in toSync) {
        await unlockAchievement(id); // push to remote
      }

      return merged;
    } catch (e) {
      debugPrint("Error fetching achievements from backend: $e");
      return localUnlocked; // fallback to local
    }
  }

  /// Unlocks an achievement by saving it locally and to Supabase
  Future<bool> unlockAchievement(String achievementId) async {
    bool success = true;
    final prefs = await SharedPreferences.getInstance();
    
    // Save locally first
    List<String> localUnlocked = prefs.getStringList(_localKey) ?? [];
    if (!localUnlocked.contains(achievementId)) {
      localUnlocked.add(achievementId);
      await prefs.setStringList(_localKey, localUnlocked);
    }

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase.from('user_achievements').upsert({
          'user_id': userId,
          'achievement_id': achievementId,
        }, onConflict: 'user_id, achievement_id');
      }
    } catch (e) {
      debugPrint("Error saving achievement to backend: $e");
      success = false;
    }

    return success;
  }
}
