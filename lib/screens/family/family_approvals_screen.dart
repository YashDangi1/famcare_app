import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/family/family_group_provider.dart';
import '../../utils/snackbar_utils.dart';

class FamilyApprovalsScreen extends ConsumerStatefulWidget {
  final String groupId;

  const FamilyApprovalsScreen({super.key, required this.groupId});

  @override
  ConsumerState<FamilyApprovalsScreen> createState() => _FamilyApprovalsScreenState();
}

class _FamilyApprovalsScreenState extends ConsumerState<FamilyApprovalsScreen> {
  List<Map<String, dynamic>> _pendingMembers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _isLoading = true);
    try {
      final members = await ref.read(familyServiceProvider).getMembers(widget.groupId);
      setState(() {
        _pendingMembers = members.where((m) => m['status'] == 'pending').toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackBar.showError(context, 'Failed to load pending requests: $e');
      }
    }
  }

  Future<void> _handleApprove(String userId) async {
    try {
      await ref.read(familyServiceProvider).approveMember(widget.groupId, userId);
      AppSnackBar.showSuccess(context, 'Member approved!');
      _loadPending();
      ref.refresh(familyDashboardProvider);
    } catch (e) {
      AppSnackBar.showError(context, 'Failed to approve member: $e');
    }
  }

  Future<void> _handleReject(String userId) async {
    try {
      await ref.read(familyServiceProvider).rejectMember(widget.groupId, userId);
      AppSnackBar.showSuccess(context, 'Member rejected.');
      _loadPending();
      ref.refresh(familyDashboardProvider);
    } catch (e) {
      AppSnackBar.showError(context, 'Failed to reject member: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Pending Approvals'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingMembers.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadPending,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendingMembers.length,
                    itemBuilder: (context, index) {
                      final member = _pendingMembers[index];
                      final profile = member['profiles'] ?? {};
                      final name = profile['full_name'] ?? 'Unknown User';
                      final userId = member['user_id'];

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey[200]!),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blue[50],
                                child: const Icon(LucideIcons.user, color: Colors.blue),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const Text('Requested to join', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(LucideIcons.xCircle, color: Colors.red),
                                    onPressed: () => _handleReject(userId),
                                  ),
                                  IconButton(
                                    icon: const Icon(LucideIcons.checkCircle, color: Colors.green),
                                    onPressed: () => _handleApprove(userId),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.checkCircle, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('No pending requests', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
        ],
      ),
    );
  }
}
