class FamilyAlertRule {
  final String id;
  final String groupId;
  final String category;
  final bool enabled;
  final int level1DelayMinutes;
  final int level2DelayMinutes;
  final int level3DelayMinutes;
  final String? quietHoursStart; // Stored as "HH:MM:SS"
  final String? quietHoursEnd;
  final List<String> deliveryChannels;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  FamilyAlertRule({
    required this.id,
    required this.groupId,
    required this.category,
    required this.enabled,
    required this.level1DelayMinutes,
    required this.level2DelayMinutes,
    required this.level3DelayMinutes,
    this.quietHoursStart,
    this.quietHoursEnd,
    required this.deliveryChannels,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FamilyAlertRule.fromMap(Map<String, dynamic> map) {
    return FamilyAlertRule(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      category: map['category'] as String,
      enabled: map['enabled'] as bool? ?? true,
      level1DelayMinutes: map['level_1_delay_minutes'] as int? ?? 0,
      level2DelayMinutes: map['level_2_delay_minutes'] as int? ?? 15,
      level3DelayMinutes: map['level_3_delay_minutes'] as int? ?? 30,
      quietHoursStart: map['quiet_hours_start'] as String?,
      quietHoursEnd: map['quiet_hours_end'] as String?,
      deliveryChannels: List<String>.from(map['delivery_channels'] ?? ['in_app', 'push']),
      createdBy: map['created_by'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'category': category,
      'enabled': enabled,
      'level_1_delay_minutes': level1DelayMinutes,
      'level_2_delay_minutes': level2DelayMinutes,
      'level_3_delay_minutes': level3DelayMinutes,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
      'delivery_channels': deliveryChannels,
      'created_by': createdBy,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }
}
