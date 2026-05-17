import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class ActivityService {
  static Future<void> log({
    required String actionType,
    required String description,
    String? targetMemberId,
  }) async {
    try {
      final client = Supabase.instance.client;
      final currentUser = client.auth.currentUser;
      if (currentUser == null) {
        debugPrint('ActivityLog: No user logged in');
        return;
      }

      // 1. Get group_id safely
      final memberRes = await client
          .from('family_members')
          .select('group_id')
          .eq('user_id', currentUser.id)
          .maybeSingle();

      if (memberRes == null) {
        debugPrint('ActivityLog: User not in any family group — skipping activity log');
        return;
      }
      final groupId = memberRes['group_id'];

      // 2. Get user's full name safely
      String userName = 'Family Member';
      final profileRes = await client
          .from('profiles')
          .select('full_name')
          .eq('id', currentUser.id)
          .maybeSingle();
      if (profileRes != null && profileRes['full_name'] != null) {
        userName = profileRes['full_name'];
      }

      // 3. Insert into activity_feed
      await client.from('activity_feed').insert({
        'group_id': groupId,
        'actor_user_id': currentUser.id,
        'actor_name': userName,
        'action_type': actionType,
        'description': description,
        'target_member_id': targetMemberId,
      });

      debugPrint('ActivityLog Success: $actionType - $description');
    } catch (e) {
      debugPrint('ActivityLog Error: $e');
    }
  }
}
