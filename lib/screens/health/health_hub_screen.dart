import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'health_overview_tab.dart';
import 'symptoms_screen.dart';
import '../vitals_screen.dart';
import '../appointment_screen.dart';
import 'records_screen.dart';
import 'reports_screen.dart';
import '../../providers/family/family_group_provider.dart';

class HealthHubScreen extends ConsumerStatefulWidget {
  final String? targetUserId;
  final String? targetUserName;

  const HealthHubScreen({
    super.key,
    this.targetUserId,
    this.targetUserName,
  });

  @override
  ConsumerState<HealthHubScreen> createState() => _HealthHubScreenState();
}

class _HealthHubScreenState extends ConsumerState<HealthHubScreen> {
  int _selectedTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.targetUserName != null ? "${widget.targetUserName}'s Health" : "Health Hub"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSegmentTabs(),
          Expanded(child: _buildSelectedTab()),
        ],
      ),
    );
  }

  Widget _buildSegmentTabs() {
    bool canViewRecords = true;
    if (widget.targetUserId != null) {
      final myGroupAsync = ref.watch(familyMembershipProvider);
      myGroupAsync.whenData((myGroup) {
        if (myGroup != null) {
          final membersAsync = ref.watch(familyMembersProvider(myGroup['group_id'] as String));
          membersAsync.whenData((members) {
            try {
              final targetMember = members.firstWhere((m) => m['user_id'] == widget.targetUserId);
              canViewRecords = targetMember['can_view_records'] ?? true;
            } catch (_) {}
          });
        }
      });
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildTab(0, 'Overview'),
          _buildTab(1, 'Vitals'),
          _buildTab(2, 'Symptoms'),
          _buildTab(3, 'Appointments'),
          if (canViewRecords) _buildTab(4, 'Records'),
          _buildTab(5, 'Reports'),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0EA5E9) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTab() {
    switch (_selectedTabIndex) {
      case 0:
        return HealthOverviewTab(targetUserId: widget.targetUserId);
      case 1:
        return VitalsScreen(
            targetUserId: widget.targetUserId,
            targetUserName: widget.targetUserName);
      case 2:
        return SymptomsScreen(
            targetUserId: widget.targetUserId,
            targetUserName: widget.targetUserName);
      case 3:
        return AppointmentScreen(
            targetUserId: widget.targetUserId,
            targetUserName: widget.targetUserName);
      case 4:
        return RecordsScreen(
            targetUserId: widget.targetUserId,
            targetUserName: widget.targetUserName,
            hideAppBar: true);
      case 5:
        return ReportsScreen(
            targetUserId: widget.targetUserId,
            targetUserName: widget.targetUserName);
      default:
        return HealthOverviewTab(targetUserId: widget.targetUserId);
    }
  }

  Widget _buildPlaceholder(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '$title coming soon',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'We are building this feature.',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
