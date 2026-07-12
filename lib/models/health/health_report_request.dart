class HealthReportRequest {
  final String userId;
  final String reportType; // doctor_visit, vitals_summary, symptom_summary, full_health_summary
  final DateTime? dateRangeStart;
  final DateTime? dateRangeEnd;

  HealthReportRequest({
    required this.userId,
    required this.reportType,
    this.dateRangeStart,
    this.dateRangeEnd,
  });

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'report_type': reportType,
      if (dateRangeStart != null) 'date_range_start': dateRangeStart!.toIso8601String().split('T')[0],
      if (dateRangeEnd != null) 'date_range_end': dateRangeEnd!.toIso8601String().split('T')[0],
    };
  }
}

class HealthReportPreview {
  final String reportType;
  final String htmlContent;
  final Map<String, dynamic> rawData;

  HealthReportPreview({
    required this.reportType,
    required this.htmlContent,
    required this.rawData,
  });
}
