import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/family/family_service.dart';

import '../../models/family/family_dashboard_data.dart';

final familyServiceProvider = Provider((ref) {
  return FamilyService(Supabase.instance.client);
});

final familyMembershipProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  return ref.watch(familyServiceProvider).getMyGroup();
});

final familyDashboardProvider = FutureProvider<FamilyDashboardData>((ref) async {
  return ref.watch(familyServiceProvider).getDashboard();
});

final familyMembersProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) async {
  return ref.watch(familyServiceProvider).getMembers(groupId);
});
