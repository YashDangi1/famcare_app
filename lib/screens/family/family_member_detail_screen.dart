import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../providers/family/family_group_provider.dart';
import '../../models/family/family_member_permission.dart';
import 'member_permissions_screen.dart';

class FamilyMemberDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> memberData;

  const FamilyMemberDetailScreen({super.key, required this.memberData});

  @override
  ConsumerState<FamilyMemberDetailScreen> createState() => _FamilyMemberDetailScreenState();
}

class _FamilyMemberDetailScreenState extends ConsumerState<FamilyMemberDetailScreen> {
  late String _role;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _role = widget.memberData['role'] ?? 'member';
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      final groupId = widget.memberData['group_id'];
      final userId = widget.memberData['user_id'];
      
      final service = ref.read(familyServiceProvider);
      
      // Update role if changed
      if (_role != widget.memberData['role']) {
        await service.updateMemberRole(groupId, userId, _role);
      }
      // Permissions are now saved in their own screen

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes saved successfully')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Member Details'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 24),
          const Text('Role', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _buildRoleSelector(),
          const SizedBox(height: 24),
          const Text('Permissions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
            title: const Text('Manage Advanced Permissions'),
            subtitle: const Text('View or edit all read/write access levels'),
            trailing: const Icon(LucideIcons.chevronRight),
            onTap: () async {
              // We need to know if current user is admin
              final myGroupAsync = await ref.read(familyMembershipProvider.future) as Map<String, dynamic>?;
              final isAdmin = myGroupAsync?['role'] == 'admin';

              Navigator.push(context, MaterialPageRoute(builder: (_) => MemberPermissionsScreen(
                member: widget.memberData,
                groupId: widget.memberData['group_id'],
                isAdmin: isAdmin,
              )));
            },
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveChanges,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Changes'),
          )
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final name = widget.memberData['profiles']?['full_name'] ?? 'Unknown User';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
      child: Row(
        children: [
          const CircleAvatar(radius: 30, child: Icon(LucideIcons.user, size: 30)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(_role.toUpperCase(), style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _role,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          items: const [
            DropdownMenuItem(value: 'admin', child: Text('Admin')),
            DropdownMenuItem(value: 'member', child: Text('Member')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _role = val);
          },
        ),
      ),
    );
  }
}
