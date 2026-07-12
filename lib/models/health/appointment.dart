class Appointment {
  final String id;
  final String userId;
  final String doctorName;
  final DateTime appointmentDate;
  final String? reminderTime;
  
  // New Pro Fields
  final String? specialty;
  final String? clinicName;
  final String? clinicAddress;
  final String? visitReason;
  final String status;
  final List<String> linkedRecordIds;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Appointment({
    required this.id,
    required this.userId,
    required this.doctorName,
    required this.appointmentDate,
    this.reminderTime,
    this.specialty,
    this.clinicName,
    this.clinicAddress,
    this.visitReason,
    this.status = 'upcoming',
    this.linkedRecordIds = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'],
      userId: json['user_id'],
      doctorName: json['doctor_name'],
      appointmentDate: DateTime.parse(json['appointment_date']).toLocal(),
      reminderTime: json['reminder_time'],
      specialty: json['specialty'],
      clinicName: json['clinic_name'],
      clinicAddress: json['clinic_address'],
      visitReason: json['visit_reason'],
      status: json['status'] ?? 'upcoming',
      linkedRecordIds: List<String>.from(json['linked_record_ids'] ?? []),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']).toLocal() : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']).toLocal() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'doctor_name': doctorName,
      'appointment_date': appointmentDate.toUtc().toIso8601String(),
      if (reminderTime != null) 'reminder_time': reminderTime,
      if (specialty != null) 'specialty': specialty,
      if (clinicName != null) 'clinic_name': clinicName,
      if (clinicAddress != null) 'clinic_address': clinicAddress,
      if (visitReason != null) 'visit_reason': visitReason,
      'status': status,
      'linked_record_ids': linkedRecordIds,
    };
  }
}
