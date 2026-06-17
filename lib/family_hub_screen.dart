import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'screens/health_landing_screen.dart';
import 'screens/activity_feed_screen.dart';
import 'screens/vitals_screen.dart';
import 'screens/health_dashboard_screen.dart';
import 'vault_screen.dart';
import 'history_service.dart';
import 'services/activity_service.dart';
import 'utils/snackbar_utils.dart';

class FamilyHubScreen extends StatefulWidget {
  const FamilyHubScreen({super.key});

  @override
  State<FamilyHubScreen> createState() => _FamilyHubScreenState();
}

class _FamilyHubScreenState extends State<FamilyHubScreen> {
  final _supabase = Supabase.instance.client;
  final _nameController = TextEditingController();
  final _joinController = TextEditingController();
  
  bool _isLoading = true;
  Map<String, dynamic>? _familyGroup;
  List<dynamic> _members = [];
  List<Map<String, dynamic>> _activities = [];
  String? _groupId;
  String? _myRole;
  String? _myStatus;

  @override
  void initState() {
    super.initState();
    _fetchFamilyData();
  }

  // --- Database Operations ---

  Future<void> _fetchFamilyData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Get my membership details
      final membership = await _supabase
          .from('family_members')
          .select('role, status, group_id, family_groups(*)')
          .eq('user_id', userId)
          .maybeSingle();

      if (membership != null) {
        _myRole = membership['role'];
        _myStatus = membership['status'];
        _groupId = membership['group_id']?.toString();
        _familyGroup = membership['family_groups'];

        // 2. Fetch all members of this group
        final membersData = await _supabase
            .from('family_members')
            .select('user_id, role, status, is_inform_contact, profiles(full_name)')
            .eq('group_id', membership['group_id']);
        
        // 3. Fetch recent activities
        final activityData = await _supabase
            .from('activity_feed')
            .select()
            .eq('group_id', membership['group_id'])
            .order('created_at', ascending: false)
            .limit(3);
            
        if (mounted) setState(() {
          _members = membersData;
          _activities = List<Map<String, dynamic>>.from(activityData);
        });
      } else {
        if (mounted) {
          setState(() {
            _familyGroup = null;
            _groupId = null;
            _myRole = null;
            _myStatus = null;
            _members = [];
            _activities = [];
          });
        }
      }
    } catch (e) {
      debugPrint('Fetch Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createFamily() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final userId = _supabase.auth.currentUser?.id;

    String handle = ''; 
    bool handleTaken = true; 
    int handleAttempts = 0; 
    while (handleTaken && handleAttempts < 5) { 
      handle = 'FAM-${Random().nextInt(900000) + 100000}'; 
      final existing = await _supabase 
          .from('family_groups') 
          .select('id') 
          .eq('handle', handle) 
          .maybeSingle(); 
      handleTaken = existing != null; 
      handleAttempts++; 
    } 
    if (handleTaken) throw Exception('Could not generate unique code. Try again.');

    try {
      // Create group
      final group = await _supabase.from('family_groups').insert({
        'name': name,
        'handle': handle,
        'created_by': userId,
      }).select().maybeSingle();
      if (group == null) {
        throw 'Failed to create family group — please retry';
      }

      // Creator is ADMIN and automatically APPROVED
      await _supabase.from('family_members').insert({
        'group_id': group['id'],
        'user_id': userId,
        'role': 'admin',
        'status': 'approved',
      });

      await HistoryService.logAction(actionType: 'JOIN', description: 'Created family: $name');
      _nameController.clear();
      _fetchFamilyData();
    } catch (e) {
      _showError('Create failed: $e');
    }
  }

  Future<void> _joinFamily() async {
    final code = _joinController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    try {
      final group = await _supabase.from('family_groups').select('id').eq('handle', code).maybeSingle();
      if (group == null) throw 'Invalid Invite Code';

      // Joiner is MEMBER and PENDING
      await _supabase.from('family_members').insert({
        'group_id': group['id'],
        'user_id': _supabase.auth.currentUser?.id,
        'role': 'member',
        'status': 'pending',
      });

      // Log activity for joining family
      try {
        await ActivityService.log(
          actionType: 'MEMBER_JOINED',
          description: 'Requested to join the family group',
        );
      } catch (e) {
        debugPrint('Log error: $e');
      }

      await HistoryService.logAction(actionType: 'JOIN', description: 'Requested to join family $code');
      _joinController.clear();
      _fetchFamilyData();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _makeAdmin(String memberUserId, String memberName) async {
    try {
      if (_groupId == null) throw 'Group not found';

      await _supabase
          .from('family_members')
          .update({'role': 'admin'})
          .eq('group_id', _groupId!)
          .eq('user_id', memberUserId);

      if (mounted) {
        AppSnackBar.showSuccess(context, 'Member promoted to admin');
      }
      await ActivityService.log(
        actionType: 'ROLE_CHANGED',
        description: 'Made $memberName an Admin',
        targetMemberId: memberUserId,
      );
      await _fetchFamilyData();
    } catch (e) {
      _showError('Failed to make admin: $e');
    }
  }

  Future<void> _removeMember(String memberUserId, String memberName) async {
    try {
      if (_groupId == null) throw 'Group not found';

      await _supabase
          .from('family_members')
          .delete()
          .eq('group_id', _groupId!)
          .eq('user_id', memberUserId);

      if (mounted) {
        AppSnackBar.showSuccess(context, 'Member removed');
      }
      await ActivityService.log(
        actionType: 'MEMBER_REMOVED',
        description: 'Removed $memberName from the family group',
        targetMemberId: memberUserId,
      );
      await _fetchFamilyData();
    } catch (e) {
      _showError('Failed to remove member: $e');
    }
  }

  Future<void> _toggleInformContact(String memberUserId, bool isActive) async {
    try {
      if (_groupId == null) throw 'Group not found';

      await _supabase
          .from('family_members')
          .update({'is_inform_contact': !isActive})
          .eq('group_id', _groupId!)
          .eq('user_id', memberUserId);

      if (mounted) {
        AppSnackBar.showSuccess(
          context,
          !isActive ? 'Added to inform list' : 'Removed from inform list',
        );
      }
      await _fetchFamilyData();
    } catch (e) {
      _showError('Failed to update inform list: $e');
    }
  }

  Future<void> _handleAdminAction(String targetId, String action) async {
    try {
      if (_groupId == null) throw 'Group not found';

      if (action == 'APPROVE') {
        await _supabase
            .from('family_members')
            .update({'status': 'approved'})
            .eq('group_id', _groupId!)
            .eq('user_id', targetId);
            
        // Log activity for member approved
        try {
          await ActivityService.log(
            actionType: 'MEMBER_JOINED',
            description: 'A new member was approved and joined the family',
            targetMemberId: targetId,
          );
        } catch (e) {
          debugPrint('Log error: $e');
        }

        if (mounted) AppSnackBar.showSuccess(context, 'Member approved');
      } else if (action == 'REJECT') {
        await _supabase
            .from('family_members')
            .delete()
            .eq('group_id', _groupId!)
            .eq('user_id', targetId);
        if (mounted) {
          AppSnackBar.showSuccess(context, 'Request rejected');
        }
      }
      _fetchFamilyData();
    } catch (e) {
      _showError('Action failed: $e');
    }
  }

  Future<void> _leaveGroup() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || _groupId == null) return;

    final confirmed = await _showConfirmationDialog(
      title: 'Leave Group?',
      message: 'Are you sure you want to leave this family group?',
      confirmText: 'Leave',
      confirmColor: Colors.red,
    );

    if (confirmed != true) return;

    try {
      await _supabase
          .from('family_members')
          .delete()
          .eq('group_id', _groupId!)
          .eq('user_id', userId);
      if (mounted) AppSnackBar.showSuccess(context, 'You left the group');
      _fetchFamilyData();
    } catch (e) {
      _showError('Leave failed: $e');
    }
  }

  Future<void> _deleteGroup() async {
    if (!_canDeleteGroup || _groupId == null) return;

    final confirmed = await _showConfirmationDialog(
      title: 'Delete Group?',
      message: 'This will permanently delete the family group and remove all members.',
      confirmText: 'Delete',
      confirmColor: Colors.red,
    );

    if (confirmed != true) return;

    try {
      await _supabase.from('family_members').delete().eq('group_id', _groupId!);
      await _supabase.from('family_groups').delete().eq('id', _groupId!);
      if (mounted) AppSnackBar.showSuccess(context, 'Family group deleted');
      _fetchFamilyData();
    } catch (e) {
      _showError('Delete failed: $e');
    }
  }

  Future<void> _confirmAdminAction({
    required String targetId,
    String? targetName,
    required String action,
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final confirmed = await _showConfirmationDialog(
      title: title,
      message: message,
      confirmText: confirmText,
      confirmColor: action == 'REMOVE' || action == 'REJECT' ? Colors.red : null,
    );

    if (confirmed == true) {
      if (action == 'REMOVE') {
        await _removeMember(targetId, targetName ?? 'Unknown');
      } else {
        await _handleAdminAction(targetId, action);
      }
    }
  }

  Future<bool?> _showConfirmationDialog({
    required String title,
    required String message,
    required String confirmText,
    Color? confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmText,
              style: TextStyle(color: confirmColor ?? const Color(0xFF0EA5E9)),
            ),
          ),
        ],
      ),
    );
  }

  void _showMemberViewOptions(String memberUserId, String memberName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  "View $memberName's Data",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(LucideIcons.heartPulse, color: Color(0xFF0EA5E9)),
                title: const Text('View Health'),
                subtitle: const Text('Dashboard, vitals, appointments, and records'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HealthLandingScreen(
                        targetUserId: memberUserId,
                        targetUserName: memberName,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String msg) {
    AppSnackBar.showError(context, msg);
  }

  // --- UI Layouts ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Family Hub', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.rss, color: Color(0xFF0EA5E9)),
            tooltip: 'Feed',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ActivityFeedScreen(),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : _familyGroup == null 
              ? _buildSetupView() 
              : (_myStatus == 'pending' ? _buildPendingView() : _buildMemberView()),
    );
  }

  // 1. Setup View: Create or Join
  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Icon(LucideIcons.users, size: 100, color: Color(0xFF0EA5E9)),
          const SizedBox(height: 20),
          Text('Your Family Health Hub', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const Text('Collaborate on health tracking with your loved ones.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),
          _buildActionCard(
            'Create a Family', 'Start a new group and be the admin', LucideIcons.plusCircle, Colors.blue,
            () => _showInputDialog('Create Family', 'Family Name', _nameController, _createFamily),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            'Join a Family', 'Enter an invite code to join yours', LucideIcons.userPlus, Colors.green,
            () => _showInputDialog('Join Family', 'Enter Code (e.g. FAM-123456)', _joinController, _joinFamily),
          ),
        ],
      ),
    );
  }

  // 2. Pending View: Waiting for Admin
// FamilyHubScreen ke andar ye widget ensure karo
Widget _buildPendingView() {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.clock, size: 80, color: Colors.orange),
          const SizedBox(height: 24),
          Text('Request Sent!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          // Yahan hum dikha rahe hain ki request "kis" family ko bheji gayi hai
          Text(
            'You have requested to join: \n"${_familyGroup?['name'] ?? 'Unknown'}"',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          const Text(
            'Waiting for Admin approval. Once approved, you can access family health records.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _fetchFamilyData, // Status refresh karne ke liye
            icon: const Icon(LucideIcons.refreshCw),
            label: const Text('Check Status'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white),
          ),
          if (_myRole != 'admin') ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _leaveGroup,
              child: const Text(
                'Leave Group',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
  // 3. Member View: Main Dashboard
  Widget _buildMemberView() {
    final pending = _members.where((m) => m['status'] == 'pending').toList();
    final approved = _members.where((m) => m['status'] == 'approved').toList();
    final isMeAdmin = _myRole == 'admin';

    return RefreshIndicator(
      onRefresh: _fetchFamilyData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildFamilyHeader(),
          const SizedBox(height: 16),
          if (isMeAdmin && pending.isNotEmpty) ...[
            const SizedBox(height: 30),
            const Text('Pending Requests', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
            const SizedBox(height: 12),
            ...pending.map((m) => _buildMemberTile(m, isRequest: true)),
          ],

          const SizedBox(height: 30),
          Text('Family Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...approved.map((m) => _buildMemberTile(m, isRequest: false)),

          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Family Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.checkCircle, color: Colors.green[700]),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All family members have taken their medications today.',
                    style: TextStyle(color: Colors.green[800], fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ActivityFeedScreen()),
                ),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_activities.isEmpty)
            const Text('No recent activity', style: TextStyle(color: Colors.grey))
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: _activities.map((a) {
                  final isLast = _activities.last == a;
                  return _buildActivityTile(a, isLast: isLast);
                }).toList(),
              ),
            ),

          const SizedBox(height: 28),
          if (!isMeAdmin)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _leaveGroup,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Leave Group', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          if (isMeAdmin && _canDeleteGroup)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _deleteGroup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Delete Group', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          if (isMeAdmin && !_canDeleteGroup)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Delete Group is available only when you are the sole admin.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildFamilyHeader() {
    final handle = _familyGroup?['handle'] ?? '...';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Text(_familyGroup?['name'] ?? 'Family', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: handle));
              AppSnackBar.showSuccess(context, "Invite code copied!");
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.copy, size: 14, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('CODE: $handle', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(dynamic m, {required bool isRequest}) {
    final isTargetAdmin = m['role'] == 'admin';
    final isItMe = m['user_id'] == _supabase.auth.currentUser?.id;
    final isMeAdmin = _myRole == 'admin';
    final memberName = m['profiles']?['full_name'] ?? 'Family Member';
    final roleLabel = isTargetAdmin ? '👑 Admin' : '👤 Member';
    final roleColor = isTargetAdmin ? Colors.orange : const Color(0xFF0EA5E9);
    final statusLabel = isRequest ? 'Pending' : 'Active';
    final statusColor = isRequest ? Colors.orange : Colors.green;
    final isInformContact = m['is_inform_contact'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.1),
                child: const Icon(LucideIcons.user, size: 20, color: Color(0xFF0EA5E9)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(memberName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildBadge(
                          roleLabel,
                          backgroundColor: roleColor.withOpacity(0.12),
                          textColor: roleColor,
                        ),
                        _buildBadge(
                          statusLabel,
                          backgroundColor: statusColor.withOpacity(0.12),
                          textColor: statusColor,
                        ),
                        if (isItMe)
                          _buildBadge(
                            'You',
                            backgroundColor: Colors.grey.withOpacity(0.12),
                            textColor: Colors.grey[700]!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isRequest ? 'This member is waiting for admin approval.' : 'Family access is active.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          if (isMeAdmin) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showMemberViewOptions(m['user_id'], memberName),
                  icon: const Icon(LucideIcons.eye, size: 16),
                  label: const Text('View'),
                ),
                if (!isRequest && !isItMe)
                  IconButton(
                    tooltip: 'Notify on missed dose',
                    onPressed: () => _toggleInformContact(
                      m['user_id'],
                      isInformContact,
                    ),
                    icon: Icon(
                      isInformContact
                          ? Icons.notifications
                          : Icons.notifications_none,
                      color: isInformContact ? Colors.amber[700] : Colors.grey,
                    ),
                  ),
                if (isRequest && !isItMe) ...[
                  ElevatedButton.icon(
                    onPressed: () => _handleAdminAction(m['user_id'], 'APPROVE'),
                    icon: const Icon(LucideIcons.check, size: 16),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _confirmAdminAction(
                      targetId: m['user_id'],
                      action: 'REJECT',
                      title: 'Reject Request?',
                      message: 'Remove this pending member request from the family group?',
                      confirmText: 'Reject',
                    ),
                    icon: const Icon(LucideIcons.x, size: 16),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ] else if (!isItMe) ...[
                  if (!isTargetAdmin)
                    ElevatedButton.icon(
                      onPressed: () => _makeAdmin(m['user_id'], memberName),
                      icon: const Icon(LucideIcons.shieldCheck, size: 16),
                      label: const Text('Make Admin'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _confirmAdminAction(
                      targetId: m['user_id'],
                      targetName: memberName,
                      action: 'REMOVE',
                      title: 'Remove Member?',
                      message: 'Are you sure you want to remove $memberName from the group?',
                      confirmText: 'Remove',
                    ),
                    icon: const Icon(LucideIcons.userMinus, size: 16),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool get _canDeleteGroup {
    if (_myRole != 'admin') return false;
    final adminCount = _members.where((m) => m['role'] == 'admin' && m['status'] == 'approved').length;
    return adminCount == 1;
  }

  Widget _buildBadge(
    String label, {
    required Color backgroundColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildActivityTile(Map<String, dynamic> activity, {bool isLast = false}) {
    final actionType = activity['action_type']?.toString();
    final actorName = activity['actor_name']?.toString().trim().isNotEmpty == true
        ? activity['actor_name'].toString().trim()
        : 'Family Member';
    final description = activity['description']?.toString() ?? 'Activity updated';
    
    IconData icon;
    Color color;
    
    switch (actionType) {
      case 'MEDICINE_TAKEN':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'MEDICINE_MISSED':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case 'ROLE_CHANGED':
        color = Colors.purple;
        icon = Icons.admin_panel_settings;
        break;
      case 'MEMBER_REMOVED':
        color = Colors.orange;
        icon = Icons.person_remove;
        break;
      default:
        color = const Color(0xFF0EA5E9);
        icon = Icons.info;
    }

    return Container(
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        title: Text(
          actorName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text(
          description,
          style: TextStyle(color: Colors.grey[700], fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)),
        child: Row(children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(sub, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ])),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ]),
      ),
    );
  }

  void _showInputDialog(String title, String hint, TextEditingController controller, VoidCallback onConfirm) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
      content: TextField(controller: controller, decoration: InputDecoration(hintText: hint, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(onPressed: () { Navigator.pop(ctx); onConfirm(); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white), child: Text(title.split(' ')[0])),
      ],
    ));
  }
}
