class FamilyEvent {
  final String id;
  final String groupId;
  final String patientUserId;
  final String createdBy;
  final String eventType;
  final String title;
  final String? description;
  final DateTime startAt;
  final DateTime? endAt;
  final bool isAllDay;
  final String? recurrenceRule;
  final String? linkedTaskId;
  final String? linkedAppointmentId;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  FamilyEvent({
    required this.id,
    required this.groupId,
    required this.patientUserId,
    required this.createdBy,
    required this.eventType,
    required this.title,
    this.description,
    required this.startAt,
    this.endAt,
    required this.isAllDay,
    this.recurrenceRule,
    this.linkedTaskId,
    this.linkedAppointmentId,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FamilyEvent.fromMap(Map<String, dynamic> map) {
    return FamilyEvent(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      patientUserId: map['patient_user_id'] as String,
      createdBy: map['created_by'] as String,
      eventType: map['event_type'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      startAt: DateTime.parse(map['start_at'] as String).toLocal(),
      endAt: map['end_at'] != null ? DateTime.parse(map['end_at'] as String).toLocal() : null,
      isAllDay: map['is_all_day'] as bool? ?? false,
      recurrenceRule: map['recurrence_rule'] as String?,
      linkedTaskId: map['linked_task_id'] as String?,
      linkedAppointmentId: map['linked_appointment_id'] as String?,
      metadata: map['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'patient_user_id': patientUserId,
      'created_by': createdBy,
      'event_type': eventType,
      'title': title,
      'description': description,
      'start_at': startAt.toUtc().toIso8601String(),
      'end_at': endAt?.toUtc().toIso8601String(),
      'is_all_day': isAllDay,
      'recurrence_rule': recurrenceRule,
      'linked_task_id': linkedTaskId,
      'linked_appointment_id': linkedAppointmentId,
      'metadata': metadata,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
