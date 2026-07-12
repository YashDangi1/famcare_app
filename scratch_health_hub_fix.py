import os

file_path = r"c:\Projects\famcare_app\lib\screens\health\health_hub_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

content = "".join(lines)

if "family_group_provider.dart" not in content:
    content = content.replace("import 'reports_screen.dart';", "import 'reports_screen.dart';\nimport '../../providers/family/family_group_provider.dart';")

old_tabs = """  Widget _buildSegmentTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildTab(0, 'Overview'),
          _buildTab(1, 'Vitals'),
          _buildTab(2, 'Symptoms'),
          _buildTab(3, 'Appointments'),
          _buildTab(4, 'Records'),
          _buildTab(5, 'Reports'),
        ],
      ),
    );
  }"""

new_tabs = """  Widget _buildSegmentTabs() {
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
  }"""

content = content.replace(old_tabs, new_tabs)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
