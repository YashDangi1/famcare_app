class FamilyDashboardData {
  final String? groupId;
  final String? groupName;
  final int pendingRequests;
  final int openTasks;
  final int urgentAlerts;
  final Map<String, dynamic> todaySummary;
  final List<dynamic> topTasks;
  final List<dynamic> recentUpdates;
  final List<dynamic> upcomingEvents;
  final bool emergencyProfileReady;

  FamilyDashboardData({
    this.groupId,
    this.groupName,
    this.pendingRequests = 0,
    this.openTasks = 0,
    this.urgentAlerts = 0,
    this.todaySummary = const {},
    this.topTasks = const [],
    this.recentUpdates = const [],
    this.upcomingEvents = const [],
    this.emergencyProfileReady = false,
  });

  factory FamilyDashboardData.fromMap(Map<String, dynamic> map) {
    if (map['group_id'] == null && map['group'] == null) {
      return FamilyDashboardData();
    }
    
    // Canonical backend keys from rpc_get_family_dashboard:
    // group_id, group_name, my_role, pending_requests, open_tasks, urgent_alerts,
    // today_summary (meds_due, meds_taken, tasks_due_today, appointments_today),
    // top_tasks (assignee_name), recent_updates, upcoming_events (start_at), emergency_profile_ready

    Map<String, dynamic> parseMap(dynamic val) {
      if (val == null) return {};
      if (val is Map) return Map<String, dynamic>.from(val);
      return {};
    }

    List<dynamic> parseList(dynamic val) {
      if (val == null) return [];
      if (val is List) return List<dynamic>.from(val);
      return [];
    }
    
    return FamilyDashboardData(
      groupId: map['group_id']?.toString(),
      groupName: map['group_name']?.toString(),
      pendingRequests: (map['pending_requests'] as num?)?.toInt() ?? 0,
      openTasks: (map['open_tasks'] as num?)?.toInt() ?? 0,
      urgentAlerts: (map['urgent_alerts'] as num?)?.toInt() ?? 0,
      todaySummary: parseMap(map['today_summary']),
      topTasks: parseList(map['top_tasks'] ?? map['top_open_tasks']),
      recentUpdates: parseList(map['recent_updates']),
      upcomingEvents: parseList(map['upcoming_events']),
      emergencyProfileReady: map['emergency_profile_ready'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'group_id': groupId,
      'group_name': groupName,
      'pending_requests': pendingRequests,
      'open_tasks': openTasks,
      'urgent_alerts': urgentAlerts,
      'today_summary': todaySummary,
      'top_tasks': topTasks,
      'recent_updates': recentUpdates,
      'upcoming_events': upcomingEvents,
      'emergency_profile_ready': emergencyProfileReady,
    };
  }
}
