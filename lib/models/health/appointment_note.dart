class AppointmentNote {
  final String? id;
  final String appointmentId;
  final String? preVisitQuestions;
  final String? visitSummary;
  final String? followUpPlan;
  final String? nextSteps;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AppointmentNote({
    this.id,
    required this.appointmentId,
    this.preVisitQuestions,
    this.visitSummary,
    this.followUpPlan,
    this.nextSteps,
    this.createdAt,
    this.updatedAt,
  });

  factory AppointmentNote.fromJson(Map<String, dynamic> json) {
    return AppointmentNote(
      id: json['id'],
      appointmentId: json['appointment_id'],
      preVisitQuestions: json['pre_visit_questions'],
      visitSummary: json['visit_summary'],
      followUpPlan: json['follow_up_plan'],
      nextSteps: json['next_steps'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']).toLocal() : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']).toLocal() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'appointment_id': appointmentId,
      if (preVisitQuestions != null) 'pre_visit_questions': preVisitQuestions,
      if (visitSummary != null) 'visit_summary': visitSummary,
      if (followUpPlan != null) 'follow_up_plan': followUpPlan,
      if (nextSteps != null) 'next_steps': nextSteps,
    };
  }
}
