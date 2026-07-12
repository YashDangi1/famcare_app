import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/family/family_update_service.dart';

final familyUpdateServiceProvider = Provider((ref) {
  return FamilyUpdateService(Supabase.instance.client);
});

final familyUpdatesProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) async {
  return ref.watch(familyUpdateServiceProvider).listUpdatesWithAuthor(groupId);
});
