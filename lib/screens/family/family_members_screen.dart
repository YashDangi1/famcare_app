import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'family_member_detail_screen.dart';
import '../../providers/family/family_group_provider.dart';
import '../../services/family/family_service.dart';

class FamilyMembersScreen extends ConsumerStatefulWidget {
  final String groupId;
  const FamilyMembersScreen({super.key, required this.groupId});

  @override
  ConsumerState<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends ConsumerState<FamilyMembersScreen> {
  Future<void> _approveMember(String userId) async {
    try {
      await ref.read(familyServiceProvider).approveMember(widget.groupId, userId);
      // ignore: unused_result
      ref.refresh(familyMembersProvider(widget.groupId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _rejectMember(String userId) async {
    try {
      await ref.read(familyServiceProvider).rejectMember(widget.groupId, userId);
      // ignore: unused_result
      ref.refresh(familyMembersProvider(widget.groupId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(familyMembersProvider(widget.groupId));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Family Members'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: membersAsync.when(
        data: (members) {
          final pending = members.where((m) => m['status'] == 'pending').toList();
          final approved = members.where((m) => m['status'] == 'approved').toList();

          return RefreshIndicator(
            onRefresh: () async {
              // ignore: unused_result
              ref.refresh(familyMembersProvider(widget.groupId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildInviteCard(context),
                if (pending.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text('Pending Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...pending.map((m) => _buildPendingTile(m)),
                ],
                const SizedBox(height: 24),
                const Text('Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...approved.map((m) => _buildMemberTile(context, m)),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildInviteCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0EA5E9).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.userPlus, color: Color(0xFF0EA5E9)),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Invite Family Member', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9))),
                Text('Share your group code', style: TextStyle(color: Colors.blueGrey)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.share, color: Color(0xFF0EA5E9)),
            onPressed: () {
              Share.share('Join my family group on FamCare!\n\nInvite Code:\n${widget.groupId}\n\nPaste this code in the app to join.');
            },
          )
        ],
      ),
    );
  }

  Widget _buildPendingTile(Map<String, dynamic> m) {
    final name = m['profiles']?['full_name'] ?? 'Unknown User';
    return Card(
      elevation: 0,
      color: Colors.orange[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.orange[200]!)),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(backgroundColor: Colors.white, child: Icon(LucideIcons.user, color: Colors.orange)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Pending Approval'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(LucideIcons.x, color: Colors.red), onPressed: () => _rejectMember(m['user_id'])),
            IconButton(icon: const Icon(LucideIcons.check, color: Colors.green), onPressed: () => _approveMember(m['user_id'])),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(BuildContext context, Map<String, dynamic> m) {
    final name = m['profiles']?['full_name'] ?? 'Unknown User';
    final role = m['role'] ?? 'member';
    final isAdmin = role == 'admin';
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAdmin ? Colors.orange[50] : Colors.blue[50],
          child: Icon(LucideIcons.user, color: isAdmin ? Colors.orange : Colors.blue),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(role.toUpperCase()),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FamilyMemberDetailScreen(memberData: m),
            ),
          ).then((_) {
            // ignore: unused_result
            ref.refresh(familyMembersProvider(widget.groupId));
          });
        },
      ),
    );
  }
}
