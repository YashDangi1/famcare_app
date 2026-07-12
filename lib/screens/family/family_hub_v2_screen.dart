import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/family/family_group_provider.dart';
import '../../models/family/family_dashboard_data.dart';
import 'family_member_detail_screen.dart';
import 'family_settings_screen.dart';
import 'family_members_screen.dart';
import 'family_tasks_screen.dart';
import 'family_updates_screen.dart';
import 'family_alerts_screen.dart';
import '../safety/emergency_center_screen.dart';
import '../safety/medical_id_screen.dart';
import 'family_calendar_screen.dart';
import 'family_approvals_screen.dart';
import 'family_setup_screen.dart';
import '../../widgets/error_retry_view.dart';
import 'weekly_summary_screen.dart';
import 'package:intl/intl.dart';

class FamilyHubV2Screen extends ConsumerStatefulWidget {
  const FamilyHubV2Screen({super.key});

  @override
  ConsumerState<FamilyHubV2Screen> createState() => _FamilyHubV2ScreenState();
}

class _FamilyHubV2ScreenState extends ConsumerState<FamilyHubV2Screen> {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _alertChannel;

  @override
  void initState() {
    super.initState();
    _setupRealtimeAlerts();
  }

  void _setupRealtimeAlerts() {
    _alertChannel = _supabase
        .channel('public:family_alerts')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'family_alerts',
          callback: (payload) {
            final newAlert = payload.newRecord;
            if (newAlert['severity'] == 'critical' && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('⚠️ URGENT ALERT: ${newAlert['title']}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                  action: SnackBarAction(
                    label: 'VIEW',
                    textColor: Colors.white,
                    onPressed: () {
                      // Navigate or refresh
                      ref.refresh(familyDashboardProvider);
                    },
                  ),
                ),
              );
            }
            ref.refresh(familyDashboardProvider); // Refresh dashboard on any new alert
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _supabase.removeChannel(_alertChannel!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(familyDashboardProvider);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Family Hub', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.alertCircle, color: Colors.red),
            tooltip: 'Emergency Center',
            onPressed: () async {
              final data = ref.read(familyDashboardProvider).value;
              final groupId = data?.groupId;
              if (groupId != null) {
                final res = await Supabase.instance.client.from('family_members').select('user_id').eq('group_id', groupId).eq('role', 'patient').maybeSingle();
                final patientId = res?['user_id'] as String? ?? Supabase.instance.client.auth.currentUser!.id;
                if (context.mounted) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => EmergencyCenterScreen(targetUserId: patientId)));
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.barChart2, color: Color(0xFF0EA5E9)),
            tooltip: 'Weekly Summary',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklySummaryScreen()));
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.settings, color: Color(0xFF0EA5E9)),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilySettingsScreen()));
            },
          ),
        ],
      ),
      body: dashboardAsync.when(
        data: (data) {
          if (data.groupId == null) {
            return FamilySetupScreen(
              onSetupComplete: () {
                // ignore: unused_result
                ref.refresh(familyDashboardProvider);
              },
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              // ignore: unused_result
              ref.refresh(familyDashboardProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildFamilyHeaderCard(data),
                const SizedBox(height: 16),
                _buildQuickActionsRow(data),
                const SizedBox(height: 16),
                _buildTodayCareSummaryStrip(data),
                const SizedBox(height: 24),
                if (data.pendingRequests > 0) ...[
                  _buildPendingApprovalsCard(data.pendingRequests, data.groupId),
                  const SizedBox(height: 24),
                ],
                _buildUrgentAlertsSection(data),
                if (!data.emergencyProfileReady) ...[
                  const SizedBox(height: 16),
                  _buildEmergencyProfileWarning(data),
                ],
                const SizedBox(height: 24),
                _buildOpenTasksPreviewCard(data),
                const SizedBox(height: 24),
                _buildUpcomingEventsCard(data),
                const SizedBox(height: 24),
                _buildRecentUpdatesSection(data),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorRetryView(
          errorMessage: 'Failed to load family dashboard.\nPlease check your connection.',
          onRetry: () => ref.refresh(familyDashboardProvider),
        ),
      ),
    );
  }

  Widget _buildFamilyHeaderCard(FamilyDashboardData data) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('My Family Group', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          Text(data.groupName ?? 'The Smiths Care Team', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildHeaderStat('${data.openTasks}', 'Tasks'),
              const SizedBox(width: 24),
              _buildHeaderStat('${data.urgentAlerts}', 'Alerts'),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildQuickActionsRow(FamilyDashboardData data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildQuickActionButton(LucideIcons.plusCircle, 'Tasks', Colors.orange, () {
          final groupId = data.groupId;
          if (groupId != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => FamilyTasksScreen(groupId: groupId)));
          }
        }),
        _buildQuickActionButton(LucideIcons.calendarPlus, 'Calendar', Colors.green, () async {
          final groupId = data.groupId;
          if (groupId != null) {
            final res = await Supabase.instance.client.from('family_members').select('user_id').eq('group_id', groupId).eq('role', 'patient').maybeSingle();
            final patientId = res?['user_id'] as String? ?? Supabase.instance.client.auth.currentUser!.id;
            if (context.mounted) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => FamilyCalendarScreen(groupId: groupId, patientUserId: patientId)));
            }
          }
        }),
        _buildQuickActionButton(LucideIcons.messageSquare, 'Update', Colors.purple, () {
          final groupId = data.groupId;
          if (groupId != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => FamilyUpdatesScreen(groupId: groupId)));
          }
        }),
        _buildQuickActionButton(LucideIcons.users, 'Members', Colors.blue, () {
          final groupId = data.groupId;
          if (groupId != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => FamilyMembersScreen(groupId: groupId)));
          }
        }),
      ],
    );
  }

  Widget _buildQuickActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTodayCareSummaryStrip(FamilyDashboardData data) {
    final todaySummary = data.todaySummary;
    final medsDue = todaySummary['meds_due'] ?? 0;
    final medsTaken = todaySummary['meds_taken'] ?? 0;
    final tasksDue = todaySummary['tasks_due_today'] ?? 0;
    
    String message = 'All on track for today! $medsTaken/$medsDue meds taken.';
    if (tasksDue > 0) {
      message += ' $tasksDue task(s) remaining.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.checkCircle, color: Colors.green[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.green[800], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingApprovalsCard(int count, String? groupId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange[200]!)),
      child: Row(
        children: [
          Icon(LucideIcons.userPlus, color: Colors.orange[800]),
          const SizedBox(width: 12),
          Expanded(child: Text('$count Pending Member Request(s)', style: TextStyle(color: Colors.orange[900], fontWeight: FontWeight.bold))),
          TextButton(
            onPressed: () {
              if (groupId != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => FamilyApprovalsScreen(groupId: groupId)));
              }
            },
            child: const Text('Review'),
          )
        ],
      ),
    );
  }

  Widget _buildUrgentAlertsSection(FamilyDashboardData data) {
    final alertsCount = data.urgentAlerts;
    if (alertsCount == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Urgent Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red[200]!)),
          child: Row(
            children: [
              const Icon(LucideIcons.alertTriangle, color: Colors.red),
              const SizedBox(width: 12),
              Expanded(child: Text('$alertsCount critical alert(s) require attention.', style: TextStyle(color: Colors.red[900]))),
              ElevatedButton(
                onPressed: () {
                  final groupId = data.groupId;
                  if (groupId != null) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => FamilyAlertsScreen(groupId: groupId)));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text('View'),
              )
            ],
          ),
        )
      ],
    );
  }

  Widget _buildOpenTasksPreviewCard(FamilyDashboardData data) {
    final topTasks = data.topTasks;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Upcoming Tasks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(onPressed: () {
              final groupId = data.groupId;
              if (groupId != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => FamilyTasksScreen(groupId: groupId)));
              }
            }, child: const Text('See All'))
          ],
        ),
        const SizedBox(height: 8),
        if (topTasks.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
            child: const Center(child: Text('No open tasks today.', style: TextStyle(color: Colors.grey))),
          )
        else
          ...topTasks.map((t) => Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(LucideIcons.checkCircle, color: t['status'] == 'done' ? Colors.green : Colors.grey),
              title: Text(t['title'] ?? 'Task', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(t['assignee_name'] != null ? 'Assigned to ${t['assignee_name']}' : 'Unassigned', style: const TextStyle(fontSize: 12)),
            ),
          )),
      ],
    );
  }

  Widget _buildRecentUpdatesSection(FamilyDashboardData data) {
    final updates = data.recentUpdates;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Updates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(onPressed: () {
              final groupId = data.groupId;
              if (groupId != null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => FamilyUpdatesScreen(groupId: groupId)));
              }
            }, child: const Text('Timeline'))
          ],
        ),
        const SizedBox(height: 8),
        if (updates.isEmpty)
          const Text('No recent updates.', style: TextStyle(color: Colors.grey))
        else
          ...updates.map((u) => Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: Colors.blue[50], child: const Icon(LucideIcons.messageCircle, color: Colors.blue)),
              title: Text(u['content'] ?? 'Update', style: const TextStyle(fontSize: 14)),
              subtitle: Text('Today', style: const TextStyle(fontSize: 12)),
            ),
          ))
      ],
    );
  }

  Widget _buildEmergencyProfileWarning(FamilyDashboardData data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.amber[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber[200]!)),
      child: Row(
        children: [
          Icon(LucideIcons.shieldAlert, color: Colors.amber[800]),
          const SizedBox(width: 12),
          Expanded(child: Text('Emergency Profile is incomplete.', style: TextStyle(color: Colors.amber[900], fontWeight: FontWeight.bold))),
          TextButton(
            onPressed: () async {
              final groupId = data.groupId;
              if (groupId != null) {
                try {
                  final res = await Supabase.instance.client.from('family_members').select('user_id').eq('group_id', groupId).eq('role', 'patient').maybeSingle();
                  final patientId = res?['user_id'] as String? ?? Supabase.instance.client.auth.currentUser!.id;
                  if (context.mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => MedicalIdScreen(targetUserId: patientId)));
                  }
                } catch (e) {
                  debugPrint('Lookup error: $e');
                }
              }
            },
            child: const Text('Setup'),
          )
        ],
      ),
    );
  }

  Widget _buildUpcomingEventsCard(FamilyDashboardData data) {
    final events = data.upcomingEvents;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Upcoming Events', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            TextButton(onPressed: () async {
              final groupId = data.groupId;
              if (groupId != null) {
                try {
                  final res = await Supabase.instance.client.from('family_members').select('user_id').eq('group_id', groupId).eq('role', 'patient').maybeSingle();
                  final patientId = res?['user_id'] as String? ?? Supabase.instance.client.auth.currentUser!.id;
                  if (context.mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => FamilyCalendarScreen(groupId: groupId, patientUserId: patientId)));
                  }
                } catch(e) {
                  debugPrint('Lookup error: $e');
                }
              }
            }, child: const Text('Calendar'))
          ],
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
            child: const Center(child: Text('No upcoming events.', style: TextStyle(color: Colors.grey))),
          )
        else
          ...events.map((e) {
             final startAt = e['start_at'] ?? e['start_time'];
             String formattedDate = 'TBD';
             try {
                if (startAt != null) {
                   formattedDate = DateFormat('MMM d, h:mm a').format(DateTime.parse(startAt).toLocal());
                }
             } catch(_) {}
             return Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(LucideIcons.calendar, color: Colors.blue),
                title: Text(e['title'] ?? 'Event', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(formattedDate, style: const TextStyle(fontSize: 12)),
              ),
            );
          }),
      ],
    );
  }
}
