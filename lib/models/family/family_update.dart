class FamilyUpdate {
  final String id;
  final String groupId;
  final String patientUserId;
  final String authorUserId;
  final String updateType;
  final String severity;
  final String content;
  final String? imageUrl;
  final String? linkedTaskId;
  final String? linkedAppointmentId;
  final String? linkedMedicineLogId;
  final String? linkedVitalId;
  final bool isPinned;
  final DateTime createdAt;

  FamilyUpdate({
    required this.id,
    required this.groupId,
    required this.patientUserId,
    required this.authorUserId,
    required this.updateType,
    required this.severity,
    required this.content,
    this.imageUrl,
    this.linkedTaskId,
    this.linkedAppointmentId,
    this.linkedMedicineLogId,
    this.linkedVitalId,
    required this.isPinned,
    required this.createdAt,
  });

  factory FamilyUpdate.fromMap(Map<String, dynamic> map) {
    return FamilyUpdate(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      patientUserId: map['patient_user_id'] as String,
      authorUserId: map['author_user_id'] as String,
      updateType: map['update_type'] as String,
      severity: map['severity'] as String? ?? 'info',
      content: map['content'] as String,
      imageUrl: map['image_url'] as String?,
      linkedTaskId: map['linked_task_id'] as String?,
      linkedAppointmentId: map['linked_appointment_id'] as String?,
      linkedMedicineLogId: map['linked_medicine_log_id'] as String?,
      linkedVitalId: map['linked_vital_id'] as String?,
      isPinned: map['is_pinned'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'patient_user_id': patientUserId,
      'author_user_id': authorUserId,
      'update_type': updateType,
      'severity': severity,
      'content': content,
      'image_url': imageUrl,
      'linked_task_id': linkedTaskId,
      'linked_appointment_id': linkedAppointmentId,
      'linked_medicine_log_id': linkedMedicineLogId,
      'linked_vital_id': linkedVitalId,
      'is_pinned': isPinned,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
