import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/family/family_task.dart';

class FamilyTaskService {
  final SupabaseClient _supabase;

  FamilyTaskService(this._supabase);

  Future<List<FamilyTask>> listTasks(String groupId, {String? status, String? patientUserId}) async {
    var query = _supabase
        .from('family_tasks')
        .select('*, assignee:profiles!family_tasks_assigned_to_fkey(full_name), creator:profiles!family_tasks_created_by_fkey(full_name)')
        .eq('group_id', groupId);

    if (status != null) {
      query = query.eq('status', status);
    }
    if (patientUserId != null) {
      query = query.eq('patient_user_id', patientUserId);
    }

    final response = await query.order('due_at', ascending: true).order('created_at', ascending: false);
    return (response as List).map((map) {
      final task = FamilyTask.fromMap(map);
      // We can inject the nested assignee/creator names into metadata if needed,
      // or we just return the task. For UI simplicity, let's store them in metadata.
      final newMetadata = Map<String, dynamic>.from(task.metadata);
      newMetadata['assignee_name'] = map['assignee']?['full_name'];
      newMetadata['creator_name'] = map['creator']?['full_name'];
      
      return FamilyTask(
        id: task.id,
        groupId: task.groupId,
        patientUserId: task.patientUserId,
        createdBy: task.createdBy,
        assignedTo: task.assignedTo,
        completedBy: task.completedBy,
        taskType: task.taskType,
        title: task.title,
        description: task.description,
        priority: task.priority,
        status: task.status,
        linkedMedicationId: task.linkedMedicationId,
        linkedAppointmentId: task.linkedAppointmentId,
        linkedRecordId: task.linkedRecordId,
        dueAt: task.dueAt,
        startedAt: task.startedAt,
        completedAt: task.completedAt,
        escalationLevel: task.escalationLevel,
        metadata: newMetadata,
        createdAt: task.createdAt,
        updatedAt: task.updatedAt,
      );
    }).toList();
  }

  Future<FamilyTask> createTask(Map<String, dynamic> input) async {
    final response = await _supabase
        .from('family_tasks')
        .insert(input)
        .select()
        .single();
    return FamilyTask.fromMap(response);
  }

  Future<FamilyTask> getTask(String taskId) async {
    final response = await _supabase
        .from('family_tasks')
        .select('*, assignee:profiles!family_tasks_assigned_to_fkey(full_name), creator:profiles!family_tasks_created_by_fkey(full_name)')
        .eq('id', taskId)
        .single();

    final task = FamilyTask.fromMap(response);
    final newMetadata = Map<String, dynamic>.from(task.metadata);
    newMetadata['assignee_name'] = response['assignee']?['full_name'];
    newMetadata['creator_name'] = response['creator']?['full_name'];

    return FamilyTask(
      id: task.id,
      groupId: task.groupId,
      patientUserId: task.patientUserId,
      createdBy: task.createdBy,
      assignedTo: task.assignedTo,
      completedBy: task.completedBy,
      taskType: task.taskType,
      title: task.title,
      description: task.description,
      priority: task.priority,
      status: task.status,
      linkedMedicationId: task.linkedMedicationId,
      linkedAppointmentId: task.linkedAppointmentId,
      linkedRecordId: task.linkedRecordId,
      dueAt: task.dueAt,
      startedAt: task.startedAt,
      completedAt: task.completedAt,
      escalationLevel: task.escalationLevel,
      metadata: newMetadata,
      createdAt: task.createdAt,
      updatedAt: task.updatedAt,
    );
  }

  Future<FamilyTask> updateTask(String taskId, Map<String, dynamic> input) async {
    final response = await _supabase
        .from('family_tasks')
        .update(input)
        .eq('id', taskId)
        .select()
        .single();
    return FamilyTask.fromMap(response);
  }

  Future<FamilyTask> completeTask(String taskId, {String? comment}) async {
    try {
      final response = await _supabase.rpc('rpc_complete_family_task', params: {
        'p_task_id': taskId,
        'p_comment': comment,
      });
      return FamilyTask.fromMap(response);
    } catch (e) {
      throw Exception('Failed to complete task: $e');
    }
  }

  Future<FamilyTask> updateTaskStatus(String taskId, String status) async {
    try {
      final response = await _supabase.rpc('rpc_update_task_status', params: {
        'p_task_id': taskId,
        'p_status': status,
      });
      return FamilyTask.fromMap(response);
    } catch (e) {
      throw Exception('Failed to update task status: $e');
    }
  }

  Future<FamilyTask> assignTask(String taskId, String assigneeId, {DateTime? dueAt, String? comment}) async {
    try {
      final response = await _supabase.rpc('rpc_assign_family_task', params: {
        'p_task_id': taskId,
        'p_assigned_to': assigneeId,
        'p_due_at': dueAt?.toIso8601String(),
        'p_comment': comment,
      });
      return FamilyTask.fromMap(response);
    } catch (e) {
      throw Exception('Failed to assign task: $e');
    }
  }

  Future<FamilyTask> reassignTask(String taskId, String assigneeId, {String? comment}) async {
    try {
      final response = await _supabase.rpc('rpc_reassign_family_task', params: {
        'p_task_id': taskId,
        'p_assigned_to': assigneeId,
        'p_comment': comment,
      });
      return FamilyTask.fromMap(response);
    } catch (e) {
      throw Exception('Failed to reassign task: $e');
    }
  }

  Future<void> addComment(String taskId, String comment, {String? attachmentUrl}) async {
    await _supabase.from('family_task_comments').insert({
      'task_id': taskId,
      'author_user_id': _supabase.auth.currentUser!.id,
      'comment': comment,
      'attachment_url': attachmentUrl,
    });
  }

  Future<List<Map<String, dynamic>>> getTaskComments(String taskId) async {
    final response = await _supabase
        .from('family_task_comments')
        .select('*, author:profiles!family_task_comments_author_user_id_fkey(full_name, avatar_url)')
        .eq('task_id', taskId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }
}
