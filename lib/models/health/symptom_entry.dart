class SymptomEntry {
  final String? id;
  final String userId;
  final String symptomType;
  final int severity;
  final DateTime startedAt;
  final int? durationMinutes;
  final String? notes;
  final String? possibleTrigger;
  final String? linkedMedicationId;
  final String? linkedVitalId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SymptomEntry({
    this.id,
    required this.userId,
    required this.symptomType,
    required this.severity,
    required this.startedAt,
    this.durationMinutes,
    this.notes,
    this.possibleTrigger,
    this.linkedMedicationId,
    this.linkedVitalId,
    this.createdAt,
    this.updatedAt,
  });

  factory SymptomEntry.fromJson(Map<String, dynamic> json) {
    return SymptomEntry(
      id: json['id'],
      userId: json['user_id'],
      symptomType: json['symptom_type'],
      severity: json['severity'],
      startedAt: DateTime.parse(json['started_at']).toLocal(),
      durationMinutes: json['duration_minutes'],
      notes: json['notes'],
      possibleTrigger: json['possible_trigger'],
      linkedMedicationId: json['linked_medication_id'],
      linkedVitalId: json['linked_vital_id'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']).toLocal() : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']).toLocal() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'symptom_type': symptomType,
      'severity': severity,
      'started_at': startedAt.toUtc().toIso8601String(),
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (notes != null) 'notes': notes,
      if (possibleTrigger != null) 'possible_trigger': possibleTrigger,
      if (linkedMedicationId != null) 'linked_medication_id': linkedMedicationId,
      if (linkedVitalId != null) 'linked_vital_id': linkedVitalId,
    };
  }
}
