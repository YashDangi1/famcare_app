import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter/services.dart';
import 'activity_feed_screen.dart';
import 'history_service.dart';
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
      
      // 1. Get my membership details
      final membership = await _supabase
          .from('family_members')
          .select('role, status, group_id, family_groups(*)')
          .eq('user_id', userId!)
          .maybeSingle();

      if (membership != null) {
        _myRole = membership['role'];
        _myStatus = membership['status'];
        _familyGroup = membership['family_groups'];

        // 2. Fetch all members of this group
        final membersData = await _supabase
            .from('family_members')
            .select('user_id, role, status, profiles(full_name)')
            .eq('group_id', membership['group_id']);
        
        if (mounted) setState(() => _members = membersData);
      } else {
        if (mounted) setState(() => _familyGroup = null);
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
    final handle = 'FAM-${Random().nextInt(900000) + 100000}';

    try {
      // Create group
      final group = await _supabase.from('family_groups').insert({
        'name': name,
        'handle': handle,
        'created_by': userId,
      }).select().single();

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
        'user_id': _supabase.auth.currentUser!.id,
        'role': 'member',
        'status': 'pending',
      });

      await HistoryService.logAction(actionType: 'JOIN', description: 'Requested to join family $code');
      _joinController.clear();
      _fetchFamilyData();
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _handleAdminAction(String targetId, String action) async {
    try {
      if (action == 'APPROVE') {
        await _supabase.from('family_members').update({'status': 'approved'}).eq('user_id', targetId);
      } else if (action == 'MAKE_ADMIN') {
        await _supabase.from('family_members').update({'role': 'admin'}).eq('user_id', targetId);
      } else if (action == 'REMOVE' || action == 'REJECT') {
        await _supabase.from('family_members').delete().eq('user_id', targetId);
      }
      _fetchFamilyData();
    } catch (e) {
      _showError('Action failed: $e');
    }
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
        title: Text('Family Hub', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true, backgroundColor: Colors.white, elevation: 0,
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
            'You have requested to join: \n"${_familyGroup?['name']}"',
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
          _buildActivityFeedButton(),
          
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

  Widget _buildActivityFeedButton() {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) => const ActivityFeedScreen())),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(LucideIcons.activity, color: Color(0xFF0EA5E9)),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Family Activity Feed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('See latest health updates from family', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(dynamic m, {required bool isRequest}) {
    final isTargetAdmin = m['role'] == 'admin';
    final isItMe = m['user_id'] == _supabase.auth.currentUser?.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.1), child: const Icon(LucideIcons.user, size: 20, color: Color(0xFF0EA5E9))),
        title: Text(m['profiles']?['full_name'] ?? 'Family Member', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: isRequest 
            ? const Text('Wants to join', style: TextStyle(color: Colors.orange, fontSize: 12))
            : Text(isTargetAdmin ? 'ADMIN' : 'MEMBER', style: TextStyle(color: isTargetAdmin ? Colors.orange : Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
        trailing: isRequest
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(icon: const Icon(LucideIcons.checkCircle, color: Colors.green), onPressed: () => _handleAdminAction(m['user_id'], 'APPROVE')),
                IconButton(icon: const Icon(LucideIcons.xCircle, color: Colors.red), onPressed: () => _handleAdminAction(m['user_id'], 'REJECT')),
              ])
            : (_myRole == 'admin' && !isItMe) 
                ? PopupMenuButton<String>(
                    onSelected: (val) => _handleAdminAction(m['user_id'], val),
                    itemBuilder: (ctx) => [
                      if (!isTargetAdmin) const PopupMenuItem(value: 'MAKE_ADMIN', child: Text('Make Admin')),
                      const PopupMenuItem(value: 'REMOVE', child: Text('Remove Member', style: TextStyle(color: Colors.red))),
                    ],
                  )
                : null,
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