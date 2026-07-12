import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/family/family_task.dart';
import '../../services/family/family_task_service.dart';

final familyTaskServiceProvider = Provider((ref) {
  return FamilyTaskService(Supabase.instance.client);
});

final familyTasksProvider = FutureProvider.family<List<FamilyTask>, String>((ref, groupId) async {
  return ref.watch(familyTaskServiceProvider).listTasks(groupId, status: 'open'); // Default to open
});

final familyTaskCommentsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, taskId) async {
  return ref.watch(familyTaskServiceProvider).getTaskComments(taskId);
});
