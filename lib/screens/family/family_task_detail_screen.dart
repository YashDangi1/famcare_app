import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../models/family/family_task.dart';
import '../../providers/family/family_tasks_provider.dart';
import '../../services/family/family_task_service.dart';
import '../../providers/family/family_group_provider.dart';

class FamilyTaskDetailScreen extends ConsumerStatefulWidget {
  final FamilyTask task;
  const FamilyTaskDetailScreen({super.key, required this.task});

  @override
  ConsumerState<FamilyTaskDetailScreen> createState() => _FamilyTaskDetailScreenState();
}

class _FamilyTaskDetailScreenState extends ConsumerState<FamilyTaskDetailScreen> {
  final _commentController = TextEditingController();
  bool _isCompleting = false;
  bool _isCommenting = false;
  late FamilyTask _currentTask;

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isCompleting = true);
    try {
      if (newStatus == 'done') {
        await ref.read(familyTaskServiceProvider).completeTask(_currentTask.id);
      } else {
        await ref.read(familyTaskServiceProvider).updateTaskStatus(_currentTask.id, newStatus);
      }
      final refetched = await ref.read(familyTaskServiceProvider).getTask(_currentTask.id);
      setState(() => _currentTask = refetched);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task status updated!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  Future<void> _reassignTask() async {
    try {
      final members = await ref.read(familyServiceProvider).getMembers(_currentTask.groupId);
      final approvedMembers = members.where((m) => m['status'] == 'approved').toList();

      if (!mounted) return;
      
      showModalBottomSheet(
        context: context,
        builder: (ctx) {
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(title: Text('Reassign Task', style: TextStyle(fontWeight: FontWeight.bold))),
                ...approvedMembers.map((m) {
                  return ListTile(
                    leading: const Icon(LucideIcons.user),
                    title: Text(m['profiles']?['full_name'] ?? 'Unknown'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      try {
                        await ref.read(familyTaskServiceProvider).assignTask(_currentTask.id, m['user_id']);
                        final refetched = await ref.read(familyTaskServiceProvider).getTask(_currentTask.id);
                        setState(() {
                          _currentTask = refetched;
                        });
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task reassigned!')));
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    },
                  );
                }),
              ],
            ),
          );
        }
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading members: $e')));
    }
  }

  Future<void> _completeTask() async {
    setState(() => _isCompleting = true);
    try {
      final updated = await ref.read(familyTaskServiceProvider).completeTask(_currentTask.id);
      if (mounted) {
        setState(() => _currentTask = updated);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task marked as done!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isCompleting = false);
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    setState(() => _isCommenting = true);
    try {
      await ref.read(familyTaskServiceProvider).addComment(_currentTask.id, _commentController.text.trim());
      _commentController.clear();
      // ignore: unused_result
      ref.refresh(familyTaskCommentsProvider(_currentTask.id));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isCommenting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(familyTaskCommentsProvider(_currentTask.id));
    final assigneeName = _currentTask.metadata['assignee_name'] ?? 'Unassigned';
    final creatorName = _currentTask.metadata['creator_name'] ?? 'Unknown';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Task Details'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.userPlus),
            onPressed: _reassignTask,
            tooltip: 'Reassign Task',
          ),
          PopupMenuButton<String>(
            onSelected: _updateStatus,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'open', child: Text('Mark as Open')),
              const PopupMenuItem(value: 'in_progress', child: Text('Mark In Progress')),
              const PopupMenuItem(value: 'escalated', child: Text('Escalate')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildTaskHeader(creatorName, assigneeName),
                const SizedBox(height: 24),
                if (_currentTask.status != 'done')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isCompleting ? null : _completeTask,
                      icon: _isCompleting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(LucideIcons.checkCircle),
                      label: const Text('Mark as Done'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                const Text('Comments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                commentsAsync.when(
                  data: (comments) {
                    if (comments.isEmpty) return const Text('No comments yet.', style: TextStyle(color: Colors.grey));
                    return Column(
                      children: comments.map((c) => _buildCommentTile(c)).toList(),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
                )
              ],
            ),
          ),
          _buildCommentComposer(),
        ],
      ),
    );
  }

  Widget _buildTaskHeader(String creatorName, String assigneeName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                child: Text(_currentTask.taskType.toUpperCase(), style: TextStyle(color: Colors.blue[700], fontSize: 10, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              Text(_currentTask.status.toUpperCase(), style: TextStyle(color: _currentTask.status == 'done' ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 16),
          Text(_currentTask.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          if (_currentTask.description != null && _currentTask.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(_currentTask.description!, style: TextStyle(color: Colors.grey[700])),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoCol('Created by', creatorName, LucideIcons.user),
              _buildInfoCol('Assigned to', assigneeName, LucideIcons.userCheck),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoCol('Due Date', _currentTask.dueAt != null ? DateFormat('MMM d, yyyy').format(_currentTask.dueAt!) : 'None', LucideIcons.calendar),
              _buildInfoCol('Priority', _currentTask.priority.toUpperCase(), LucideIcons.alertCircle),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildInfoCol(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icon, size: 14, color: Colors.blueGrey),
            const SizedBox(width: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        )
      ],
    );
  }

  Widget _buildCommentTile(Map<String, dynamic> comment) {
    final authorName = comment['author']?['full_name'] ?? 'Unknown';
    final createdAt = DateTime.parse(comment['created_at']).toLocal();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(radius: 16, child: Icon(LucideIcons.user, size: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(DateFormat('MMM d, h:mm a').format(createdAt), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(comment['comment']),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCommentComposer() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isCommenting ? null : _addComment,
            icon: _isCommenting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(LucideIcons.send, color: Colors.blue),
          )
        ],
      ),
    );
  }
}
