class FamilyAlert {
  final String id;
  final String groupId;
  final String patientUserId;
  final String recipientUserId;
  final String category;
  final String severity;
  final String? sourceTable;
  final String? sourceId;
  final String title;
  final String message;
  final int escalationLevel;
  final String status;
  final DateTime? acknowledgedAt;
  final String? acknowledgedBy;
  final DateTime? resolvedAt;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  FamilyAlert({
    required this.id,
    required this.groupId,
    required this.patientUserId,
    required this.recipientUserId,
    required this.category,
    required this.severity,
    this.sourceTable,
    this.sourceId,
    required this.title,
    required this.message,
    required this.escalationLevel,
    required this.status,
    this.acknowledgedAt,
    this.acknowledgedBy,
    this.resolvedAt,
    required this.metadata,
    required this.createdAt,
  });

  factory FamilyAlert.fromMap(Map<String, dynamic> map) {
    return FamilyAlert(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      patientUserId: map['patient_user_id'] as String,
      recipientUserId: map['recipient_user_id'] as String,
      category: map['category'] as String,
      severity: map['severity'] as String? ?? 'warning',
      sourceTable: map['source_table'] as String?,
      sourceId: map['source_id'] as String?,
      title: map['title'] as String,
      message: map['message'] as String,
      escalationLevel: map['escalation_level'] as int? ?? 1,
      status: map['status'] as String? ?? 'open',
      acknowledgedAt: map['acknowledged_at'] != null ? DateTime.parse(map['acknowledged_at'] as String).toLocal() : null,
      acknowledgedBy: map['acknowledged_by'] as String?,
      resolvedAt: map['resolved_at'] != null ? DateTime.parse(map['resolved_at'] as String).toLocal() : null,
      metadata: map['metadata'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'patient_user_id': patientUserId,
      'recipient_user_id': recipientUserId,
      'category': category,
      'severity': severity,
      'source_table': sourceTable,
      'source_id': sourceId,
      'title': title,
      'message': message,
      'escalation_level': escalationLevel,
      'status': status,
      'acknowledged_at': acknowledgedAt?.toUtc().toIso8601String(),
      'acknowledged_by': acknowledgedBy,
      'resolved_at': resolvedAt?.toUtc().toIso8601String(),
      'metadata': metadata,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}
