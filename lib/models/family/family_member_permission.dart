class FamilyMemberPermissionInput {
  final bool? isPrimaryCaregiver;
  final bool? isEmergencyContact;
  final int? emergencyPriority;
  final bool? canViewMeds;
  final bool? canEditMeds;
  final bool? canViewVitals;
  final bool? canLogVitals;
  final bool? canViewAppointments;
  final bool? canManageAppointments;
  final bool? canViewRecords;
  final bool? canUploadRecords;
  final bool? canManageTasks;
  final bool? canViewEmergency;
  final bool? canEditEmergency;
  final bool? notifyMissedDose;
  final bool? notifyLowStock;
  final bool? notifyAppointments;
  final bool? notifyVitals;
  final bool? notifyTasks;
  
  FamilyMemberPermissionInput({
    this.isPrimaryCaregiver,
    this.isEmergencyContact,
    this.emergencyPriority,
    this.canViewMeds,
    this.canEditMeds,
    this.canViewVitals,
    this.canLogVitals,
    this.canViewAppointments,
    this.canManageAppointments,
    this.canViewRecords,
    this.canUploadRecords,
    this.canManageTasks,
    this.canViewEmergency,
    this.canEditEmergency,
    this.notifyMissedDose,
    this.notifyLowStock,
    this.notifyAppointments,
    this.notifyVitals,
    this.notifyTasks,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (isPrimaryCaregiver != null) map['is_primary_caregiver'] = isPrimaryCaregiver;
    if (isEmergencyContact != null) map['is_emergency_contact'] = isEmergencyContact;
    if (emergencyPriority != null) map['emergency_priority'] = emergencyPriority;
    if (canViewMeds != null) map['can_view_meds'] = canViewMeds;
    if (canEditMeds != null) map['can_edit_meds'] = canEditMeds;
    if (canViewVitals != null) map['can_view_vitals'] = canViewVitals;
    if (canLogVitals != null) map['can_log_vitals'] = canLogVitals;
    if (canViewAppointments != null) map['can_view_appointments'] = canViewAppointments;
    if (canManageAppointments != null) map['can_manage_appointments'] = canManageAppointments;
    if (canViewRecords != null) map['can_view_records'] = canViewRecords;
    if (canUploadRecords != null) map['can_upload_records'] = canUploadRecords;
    if (canManageTasks != null) map['can_manage_tasks'] = canManageTasks;
    if (canViewEmergency != null) map['can_view_emergency'] = canViewEmergency;
    if (canEditEmergency != null) map['can_edit_emergency'] = canEditEmergency;
    if (notifyMissedDose != null) map['notify_missed_dose'] = notifyMissedDose;
    if (notifyLowStock != null) map['notify_low_stock'] = notifyLowStock;
    if (notifyAppointments != null) map['notify_appointments'] = notifyAppointments;
    if (notifyVitals != null) map['notify_vitals'] = notifyVitals;
    if (notifyTasks != null) map['notify_tasks'] = notifyTasks;
    return map;
  }
}
