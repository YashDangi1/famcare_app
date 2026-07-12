class HealthRecord {
  final String? id;
  final String userId;
  final String category;
  final String title;
  final String fileUrl;
  final String? thumbUrl;
  final String? providerName;
  final DateTime? recordDate;
  final List<String> tags;
  final String? linkedAppointmentId;
  final String source;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  HealthRecord({
    this.id,
    required this.userId,
    required this.category,
    required this.title,
    required this.fileUrl,
    this.thumbUrl,
    this.providerName,
    this.recordDate,
    this.tags = const [],
    this.linkedAppointmentId,
    this.source = 'manual',
    this.createdAt,
    this.updatedAt,
  });

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    return HealthRecord(
      id: json['id'],
      userId: json['user_id'],
      category: json['category'],
      title: json['title'],
      fileUrl: json['file_url'],
      thumbUrl: json['thumb_url'],
      providerName: json['provider_name'],
      recordDate: json['record_date'] != null ? DateTime.parse(json['record_date']) : null,
      tags: List<String>.from(json['tags'] ?? []),
      linkedAppointmentId: json['linked_appointment_id'],
      source: json['source'] ?? 'manual',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']).toLocal() : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']).toLocal() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'category': category,
      'title': title,
      'file_url': fileUrl,
      if (thumbUrl != null) 'thumb_url': thumbUrl,
      if (providerName != null) 'provider_name': providerName,
      if (recordDate != null) 'record_date': recordDate!.toIso8601String().split('T')[0],
      'tags': tags,
      if (linkedAppointmentId != null) 'linked_appointment_id': linkedAppointmentId,
      'source': source,
    };
  }
}
