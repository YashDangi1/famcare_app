import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/family/family_event.dart';
import '../../services/family/family_event_service.dart';

final familyEventServiceProvider = Provider((ref) {
  return FamilyEventService(Supabase.instance.client);
});

typedef FamilyEventParams = ({String groupId, String patientUserId, DateTime from, DateTime to});

final familyEventsProvider = FutureProvider.family<List<FamilyEvent>, FamilyEventParams>((ref, params) async {
  final service = ref.watch(familyEventServiceProvider);
  final supabase = Supabase.instance.client;

  // 1. Fetch Events
  final events = await service.listEvents(params.groupId, params.from, params.to);

  // 2. Fetch Tasks (that have a due_at within this month)
  final tasksRes = await supabase
      .from('family_tasks')
      .select()
      .eq('group_id', params.groupId)
      .gte('due_at', params.from.toUtc().toIso8601String())
      .lte('due_at', params.to.toUtc().toIso8601String());

  final tasksAsEvents = (tasksRes as List).map((t) {
    return FamilyEvent(
      id: t['id'],
      groupId: t['group_id'],
      patientUserId: t['patient_user_id'] ?? '',
      createdBy: t['created_by'],
      eventType: 'task_due',
      title: 'Task: ${t['title']}',
      description: t['description'],
      startAt: DateTime.parse(t['due_at']).toLocal(),
      isAllDay: false,
      metadata: {'status': t['status'], 'priority': t['priority']},
      createdAt: DateTime.parse(t['created_at']),
      updatedAt: DateTime.parse(t['updated_at']),
    );
  }).toList();

  // 3. Fetch Appointments
  final apptsRes = await supabase
      .from('appointments')
      .select()
      .eq('user_id', params.patientUserId)
      .gte('appointment_date', params.from.toUtc().toIso8601String())
      .lte('appointment_date', params.to.toUtc().toIso8601String());

  final apptsAsEvents = (apptsRes as List).map((a) {
    return FamilyEvent(
      id: a['id'],
      groupId: params.groupId,
      patientUserId: params.patientUserId,
      createdBy: a['user_id'],
      eventType: 'appointment',
      title: 'Doctor: ${a['doctor_name']}',
      description: a['reason'],
      startAt: DateTime.parse(a['appointment_date']).toLocal(),
      isAllDay: false,
      metadata: {'status': a['status']},
      createdAt: DateTime.parse(a['created_at']),
      updatedAt: DateTime.parse(a['updated_at']),
    );
  }).toList();
  
  return [...events, ...tasksAsEvents, ...apptsAsEvents];
});
