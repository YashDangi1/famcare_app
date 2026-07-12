import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../providers/family/family_updates_provider.dart';
import '../../services/family/family_update_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyUpdatesScreen extends ConsumerStatefulWidget {
  final String groupId;
  const FamilyUpdatesScreen({super.key, required this.groupId});

  @override
  ConsumerState<FamilyUpdatesScreen> createState() => _FamilyUpdatesScreenState();
}

class _FamilyUpdatesScreenState extends ConsumerState<FamilyUpdatesScreen> {
  @override
  Widget build(BuildContext context) {
    final updatesAsync = ref.watch(familyUpdatesProvider(widget.groupId));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Updates Timeline'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: updatesAsync.when(
        data: (updates) {
          if (updates.isEmpty) {
            return const Center(child: Text('No updates yet.', style: TextStyle(color: Colors.grey)));
          }

          return RefreshIndicator(
            onRefresh: () async {
              // ignore: unused_result
              ref.refresh(familyUpdatesProvider(widget.groupId));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: updates.length,
              itemBuilder: (context, index) {
                return _buildUpdateCard(updates[index]);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateUpdateSheet,
        backgroundColor: Colors.purple,
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
    );
  }

  Widget _buildUpdateCard(Map<String, dynamic> update) {
    final authorName = update['author']?['full_name'] ?? 'Unknown';
    final createdAt = DateTime.parse(update['created_at']).toLocal();
    final updateType = update['update_type'] as String;
    final content = update['content'] as String;
    final severity = update['severity'] as String;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(radius: 16, child: Icon(LucideIcons.user, size: 16)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(authorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(DateFormat('MMM d, h:mm a').format(createdAt), style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _getSeverityColor(severity).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(updateType.toUpperCase(), style: TextStyle(color: _getSeverityColor(severity), fontSize: 10, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const SizedBox(height: 16),
            Text(content, style: const TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }

  Color _getSeverityColor(String severity) {
    if (severity == 'critical') return Colors.red;
    if (severity == 'warning') return Colors.orange;
    return Colors.blue;
  }

  void _showCreateUpdateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CreateUpdateSheet(
        groupId: widget.groupId,
        onCreated: () {
          // ignore: unused_result
          ref.refresh(familyUpdatesProvider(widget.groupId));
        },
      )
    );
  }
}

class _CreateUpdateSheet extends ConsumerStatefulWidget {
  final String groupId;
  final VoidCallback onCreated;

  const _CreateUpdateSheet({required this.groupId, required this.onCreated});

  @override
  ConsumerState<_CreateUpdateSheet> createState() => _CreateUpdateSheetState();
}

class _CreateUpdateSheetState extends ConsumerState<_CreateUpdateSheet> {
  final _contentController = TextEditingController();
  String _updateType = 'general';
  String _severity = 'info';
  bool _isLoading = false;

  Future<void> _create() async {
    if (_contentController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final input = {
        'group_id': widget.groupId,
        'patient_user_id': Supabase.instance.client.auth.currentUser!.id, // Self as patient for now
        'author_user_id': Supabase.instance.client.auth.currentUser!.id,
        'update_type': _updateType,
        'severity': _severity,
        'content': _contentController.text.trim(),
      };
      await ref.read(familyUpdateServiceProvider).createUpdate(input);
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Share Update', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _contentController,
            decoration: const InputDecoration(labelText: 'What happened?', border: OutlineInputBorder()),
            maxLines: 4,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _updateType,
                  decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'general', child: Text('General')),
                    DropdownMenuItem(value: 'symptom', child: Text('Symptom')),
                    DropdownMenuItem(value: 'vitals_note', child: Text('Vitals Note')),
                  ],
                  onChanged: (v) => setState(() => _updateType = v!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _severity,
                  decoration: const InputDecoration(labelText: 'Severity', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'info', child: Text('Info')),
                    DropdownMenuItem(value: 'warning', child: Text('Warning')),
                    DropdownMenuItem(value: 'critical', child: Text('Critical')),
                  ],
                  onChanged: (v) => setState(() => _severity = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _create,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Post Update'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
