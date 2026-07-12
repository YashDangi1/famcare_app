import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyNotificationsScreen extends StatefulWidget {
  const FamilyNotificationsScreen({super.key});

  @override
  State<FamilyNotificationsScreen> createState() => _FamilyNotificationsScreenState();
}

class _FamilyNotificationsScreenState extends State<FamilyNotificationsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  bool _notifyMissedDose = true;
  bool _notifyLowStock = true;
  bool _notifyAppointments = true;
  bool _notifyVitals = false;
  bool _notifyTasks = true;

  String? _groupId;
  int _escalationDelay = 15;
  String _quietHours = '22:00:00-07:00:00'; // Default 10 PM - 7 AM

  @override
  void initState() {
    super.initState();
    _fetchPreferences();
  }

  Future<void> _fetchPreferences() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Fetch personal notification preferences and group id
      final data = await _supabase
          .from('family_members')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _notifyMissedDose = data['notify_missed_dose'] ?? true;
          _notifyLowStock = data['notify_low_stock'] ?? true;
          _notifyAppointments = data['notify_appointments'] ?? true;
          _notifyVitals = data['notify_vitals'] ?? false;
          _notifyTasks = data['notify_tasks'] ?? true;
          _groupId = data['group_id'] as String?;
        });
        
        // 2. If user has a group, fetch group escalation rules
        if (_groupId != null) {
          final rulesData = await _supabase
              .from('family_alert_rules')
              .select()
              .eq('group_id', _groupId as Object)
              .eq('category', 'missed_dose')
              .maybeSingle();
              
          if (rulesData != null && mounted) {
            setState(() {
              _escalationDelay = rulesData['level_2_delay_minutes'] as int? ?? 15;
              final qStart = rulesData['quiet_hours_start'] as String?;
              final qEnd = rulesData['quiet_hours_end'] as String?;
              if (qStart != null && qEnd != null) {
                _quietHours = '$qStart-$qEnd';
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Fetch notification prefs error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePreference(String field, bool value) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase
          .from('family_members')
          .update({field: value})
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Update notification pref error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
    }
  }

  Future<void> _updateAlertRules(int delay, String quietHoursRaw) async {
    if (_groupId == null) return;
    try {
      final parts = quietHoursRaw.split('-');
      if (parts.length != 2) return;
      
      final qStart = parts[0];
      final qEnd = parts[1];

      await _supabase.from('family_alert_rules').upsert({
        'group_id': _groupId,
        'category': 'missed_dose',
        'level_2_delay_minutes': delay,
        'quiet_hours_start': qStart,
        'quiet_hours_end': qEnd,
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        setState(() {
          _escalationDelay = delay;
          _quietHours = quietHoursRaw;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escalation rules updated')));
      }
    } catch (e) {
      debugPrint('Update alert rules error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update rules: $e')));
    }
  }

  Widget _buildSwitchTile({required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged}) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      value: value,
      activeColor: const Color(0xFF0EA5E9),
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Family Notifications', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Choose which alerts you want to receive from your family group.', style: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(height: 8),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                _buildSwitchTile(
                  title: 'Missed Medicines',
                  subtitle: 'Get notified if a family member misses their dose',
                  value: _notifyMissedDose,
                  onChanged: (val) {
                    setState(() => _notifyMissedDose = val);
                    _updatePreference('notify_missed_dose', val);
                  },
                ),
                const Divider(height: 1),
                _buildSwitchTile(
                  title: 'Low Stock Alerts',
                  subtitle: 'When medication is running out (≤ 5 doses)',
                  value: _notifyLowStock,
                  onChanged: (val) {
                    setState(() => _notifyLowStock = val);
                    _updatePreference('notify_low_stock', val);
                  },
                ),
                const Divider(height: 1),
                _buildSwitchTile(
                  title: 'Appointments',
                  subtitle: 'Upcoming doctor visits and changes',
                  value: _notifyAppointments,
                  onChanged: (val) {
                    setState(() => _notifyAppointments = val);
                    _updatePreference('notify_appointments', val);
                  },
                ),
                const Divider(height: 1),
                _buildSwitchTile(
                  title: 'Abnormal Vitals',
                  subtitle: 'When vital readings fall outside safe ranges',
                  value: _notifyVitals,
                  onChanged: (val) {
                    setState(() => _notifyVitals = val);
                    _updatePreference('notify_vitals', val);
                  },
                ),
                const Divider(height: 1),
                _buildSwitchTile(
                  title: 'Tasks & Updates',
                  subtitle: 'When tasks are assigned or completed',
                  value: _notifyTasks,
                  onChanged: (val) {
                    setState(() => _notifyTasks = val);
                    _updatePreference('notify_tasks', val);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Group Escalation Rules (Admins Only)', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          Container(
            decoration: BoxDecoration(color: Colors.white, border: Border.symmetric(horizontal: BorderSide(color: Colors.grey.shade200))),
            child: Column(
              children: [
                ListTile(
                  title: const Text('Escalation Delay', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Wait $_escalationDelay mins before escalating alerts'),
                  trailing: const Icon(LucideIcons.chevronRight, color: Colors.grey),
                  onTap: () {
                    final nextDelay = _escalationDelay == 15 ? 30 : (_escalationDelay == 30 ? 60 : 15);
                    _updateAlertRules(nextDelay, _quietHours);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Quiet Hours', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${_quietHours.split('-').first.substring(0,5)} to ${_quietHours.split('-').last.substring(0,5)} (Critical only)'),
                  trailing: const Icon(LucideIcons.moon, color: Colors.indigo),
                  onTap: () {
                    final nextQuiet = _quietHours.startsWith('22') ? '23:00:00-08:00:00' : '22:00:00-07:00:00';
                    _updateAlertRules(_escalationDelay, nextQuiet);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
