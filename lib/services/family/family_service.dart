import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/family/family_member_permission.dart';

import '../../models/family/family_dashboard_data.dart';

class FamilyService {
  final SupabaseClient _supabase;

  FamilyService(this._supabase);

  Future<FamilyDashboardData> getDashboard() async {
    try {
      final response = await _supabase.rpc('rpc_get_family_dashboard');
      if (response == null) return FamilyDashboardData();
      return FamilyDashboardData.fromMap(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      throw Exception('Failed to load dashboard data: $e');
    }
  }

  Future<Map<String, dynamic>?> getMyGroup() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final membership = await _supabase
        .from('family_members')
        .select('*, family_groups(*)')
        .eq('user_id', userId)
        .eq('status', 'approved')
        .maybeSingle();
        
    return membership;
  }

  Future<Map<String, dynamic>> createGroup(String groupName) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    // Insert group
    final groupRes = await _supabase
        .from('family_groups')
        .insert({'name': groupName})
        .select()
        .single();
    
    final groupId = groupRes['id'];

    // Add current user as admin (approved)
    await _supabase.from('family_members').insert({
      'group_id': groupId,
      'user_id': userId,
      'role': 'admin',
      'status': 'approved'
    });

    return groupRes;
  }

  Future<void> joinGroup(String groupId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not logged in');

    await _supabase.from('family_members').insert({
      'group_id': groupId,
      'user_id': userId,
      'role': 'member',
      'status': 'pending'
    });
  }

  Future<List<Map<String, dynamic>>> getMembers(String groupId) async {
    final response = await _supabase
        .from('family_members')
        .select('*, profiles(full_name, avatar_url)')
        .eq('group_id', groupId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> approveMember(String groupId, String userId) async {
    await _supabase
        .from('family_members')
        .update({'status': 'approved'})
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  Future<void> rejectMember(String groupId, String userId) async {
    await _supabase
        .from('family_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  Future<void> updateMemberRole(String groupId, String userId, String role) async {
    await _supabase
        .from('family_members')
        .update({'role': role})
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  Future<void> updateMemberPermissions(String groupId, String userId, FamilyMemberPermissionInput input) async {
    final updates = input.toMap();
    if (updates.isEmpty) return;

    await _supabase
        .from('family_members')
        .update(updates)
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }
}
