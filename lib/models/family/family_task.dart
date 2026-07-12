class FamilyTask {
  final String id;
  final String groupId;
  final String patientUserId;
  final String createdBy;
  final String? assignedTo;
  final String? completedBy;
  final String taskType;
  final String title;
  final String? description;
  final String priority;
  final String status;
  final String? linkedMedicationId;
  final String? linkedAppointmentId;
  final String? linkedRecordId;
  final DateTime? dueAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int escalationLevel;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  FamilyTask({
    required this.id,
    required this.groupId,
    required this.patientUserId,
    required this.createdBy,
    this.assignedTo,
    this.completedBy,
    required this.taskType,
    required this.title,
    this.description,
    required this.priority,
    required this.status,
    this.linkedMedicationId,
    this.linkedAppointmentId,
    this.linkedRecordId,
    this.dueAt,
    this.startedAt,
    this.completedAt,
    required this.escalationLevel,
    required this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FamilyTask.fromMap(Map<String, dynamic> map) {
    return FamilyTask(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      patientUserId: map['patient_user_id'] as String,
      createdBy: map['created_by'] as String,
      assignedTo: map['assigned_to'] as String?,
      completedBy: map['completed_by'] as String?,
      taskType: map['task_type'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      priority: map['priority'] as String,
      status: map['status'] as String,
      linkedMedicationId: map['linked_medication_id'] as String?,
      linkedAppointmentId: map['linked_appointment_id'] as String?,
      linkedRecordId: map['linked_record_id'] as String?,
      dueAt: map['due_at'] != null ? DateTime.parse(map['due_at'] as String).toLocal() : null,
      startedAt: map['started_at'] != null ? DateTime.parse(map['started_at'] as String).toLocal() : null,
      completedAt: map['completed_at'] != null ? DateTime.parse(map['completed_at'] as String).toLocal() : null,
      escalationLevel: map['escalation_level'] as int? ?? 0,
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
      'assigned_to': assignedTo,
      'completed_by': completedBy,
      'task_type': taskType,
      'title': title,
      'description': description,
      'priority': priority,
      'status': status,
      'linked_medication_id': linkedMedicationId,
      'linked_appointment_id': linkedAppointmentId,
      'linked_record_id': linkedRecordId,
      'due_at': dueAt?.toUtc().toIso8601String(),
      'started_at': startedAt?.toUtc().toIso8601String(),
      'completed_at': completedAt?.toUtc().toIso8601String(),
      'escalation_level': escalationLevel,
      'metadata': metadata,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
