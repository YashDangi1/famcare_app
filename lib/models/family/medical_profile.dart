class MedicalProfile {
  final String userId;
  final String? bloodGroup;
  final List<String> allergies;
  final List<String> conditions;
  final String? chronicNotes;
  final String? doctorName;
  final String? doctorPhone;
  final String? hospitalName;
  final List<Map<String, dynamic>> emergencyContacts;
  final Map<String, dynamic> insuranceInfo;
  final String? currentMedSummary;
  final String? updatedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  MedicalProfile({
    required this.userId,
    this.bloodGroup,
    required this.allergies,
    required this.conditions,
    this.chronicNotes,
    this.doctorName,
    this.doctorPhone,
    this.hospitalName,
    required this.emergencyContacts,
    required this.insuranceInfo,
    this.currentMedSummary,
    this.updatedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MedicalProfile.fromMap(Map<String, dynamic> map) {
    return MedicalProfile(
      userId: map['user_id'] as String,
      bloodGroup: map['blood_group'] as String?,
      allergies: List<String>.from(map['allergies'] ?? []),
      conditions: List<String>.from(map['conditions'] ?? []),
      chronicNotes: map['chronic_notes'] as String?,
      doctorName: map['doctor_name'] as String?,
      doctorPhone: map['doctor_phone'] as String?,
      hospitalName: map['hospital_name'] as String?,
      emergencyContacts: List<Map<String, dynamic>>.from(map['emergency_contacts'] ?? []),
      insuranceInfo: map['insurance_info'] as Map<String, dynamic>? ?? {},
      currentMedSummary: map['current_med_summary'] as String?,
      updatedBy: map['updated_by'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'blood_group': bloodGroup,
      'allergies': allergies,
      'conditions': conditions,
      'chronic_notes': chronicNotes,
      'doctor_name': doctorName,
      'doctor_phone': doctorPhone,
      'hospital_name': hospitalName,
      'emergency_contacts': emergencyContacts,
      'insurance_info': insuranceInfo,
      'current_med_summary': currentMedSummary,
      'updated_by': updatedBy,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
