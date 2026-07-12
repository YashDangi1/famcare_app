import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../providers/family/family_tasks_provider.dart';
import '../../providers/family/family_group_provider.dart';
import '../../models/family/family_task.dart';
import 'family_task_detail_screen.dart';
import '../../services/family/family_task_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyTasksScreen extends ConsumerStatefulWidget {
  final String groupId;
  const FamilyTasksScreen({super.key, required this.groupId});

  @override
  ConsumerState<FamilyTasksScreen> createState() => _FamilyTasksScreenState();
}

class _FamilyTasksScreenState extends ConsumerState<FamilyTasksScreen> {
  String _filter = 'open'; // 'open', 'done', 'overdue'

  @override
  Widget build(BuildContext context) {
    // We can't use familyTasksProvider directly with filter easily unless we pass filter to it.
    // Let's refetch tasks via service directly or update the provider to accept filter.
    // For simplicity here, we'll watch a custom future or just use the provider if it supports filtering.
    // Let's use a FutureBuilder for custom queries.
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Family Tasks'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: FutureBuilder<List<FamilyTask>>(
              future: ref.read(familyTaskServiceProvider).listTasks(widget.groupId, status: _filter == 'overdue' ? 'open' : _filter),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                
                var tasks = snapshot.data ?? [];
                if (_filter == 'overdue') {
                  tasks = tasks.where((t) => t.dueAt != null && t.dueAt!.isBefore(DateTime.now())).toList();
                }

                if (tasks.isEmpty) {
                  return const Center(child: Text('No tasks found.', style: TextStyle(color: Colors.grey)));
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() {}); // Trigger FutureBuilder rebuild
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return _buildTaskCard(task);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateTaskSheet,
        backgroundColor: Colors.blue,
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildChip('Open', 'open', Colors.blue),
          const SizedBox(width: 8),
          _buildChip('Overdue', 'overdue', Colors.red),
          const SizedBox(width: 8),
          _buildChip('Done', 'done', Colors.green),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value, Color color) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: isSelected ? color : Colors.black87),
    );
  }

  Widget _buildTaskCard(FamilyTask task) {
    final assigneeName = task.metadata['assignee_name'] ?? 'Unassigned';
    final isOverdue = task.dueAt != null && task.dueAt!.isBefore(DateTime.now()) && task.status != 'done';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isOverdue ? Colors.red[200]! : Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => FamilyTaskDetailScreen(task: task))).then((_) => setState((){}));
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(task.priority).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      task.priority.toUpperCase(),
                      style: TextStyle(color: _getPriorityColor(task.priority), fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (isOverdue)
                    const Text('OVERDUE', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Text(task.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              if (task.description != null && task.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(task.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(LucideIcons.user, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(assigneeName, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  const Spacer(),
                  if (task.dueAt != null) ...[
                    const Icon(LucideIcons.calendar, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(DateFormat('MMM d, h:mm a').format(task.dueAt!), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ]
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'critical': return Colors.red;
      case 'high': return Colors.orange;
      case 'low': return Colors.green;
      default: return Colors.blue;
    }
  }

  void _showCreateTaskSheet() {
    // Basic Task creation sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return _CreateTaskSheet(groupId: widget.groupId, onCreated: () => setState(() {}));
      }
    );
  }
}

class _CreateTaskSheet extends ConsumerStatefulWidget {
  final String groupId;
  final VoidCallback onCreated;
  const _CreateTaskSheet({required this.groupId, required this.onCreated});

  @override
  ConsumerState<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends ConsumerState<_CreateTaskSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _priority = 'medium';
  String _taskType = 'custom';
  bool _isLoading = false;
  
  List<Map<String, dynamic>> _members = [];
  String? _selectedAssigneeId;
  String? _selectedPatientId;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final members = await ref.read(familyServiceProvider).getMembers(widget.groupId);
      setState(() {
        _members = members.where((m) => m['status'] == 'approved').toList();
        final currentUserId = Supabase.instance.client.auth.currentUser!.id;
        _selectedAssigneeId = _members.any((m) => m['user_id'] == currentUserId) ? currentUserId : null;
        
        final patients = _members.where((m) => m['role'] == 'patient').toList();
        if (patients.isNotEmpty) {
          _selectedPatientId = patients.first['user_id'];
        } else {
          _selectedPatientId = currentUserId;
        }
      });
    } catch (e) {
      debugPrint('Failed to load members: $e');
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );
      if (time != null && mounted) {
        setState(() {
          _dueDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  Future<void> _create() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final input = {
        'group_id': widget.groupId,
        'patient_user_id': _selectedPatientId ?? Supabase.instance.client.auth.currentUser!.id,
        'created_by': Supabase.instance.client.auth.currentUser!.id,
        'assigned_to': _selectedAssigneeId,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'priority': _priority,
        'task_type': _taskType,
        'status': 'open',
        if (_dueDate != null) 'due_at': _dueDate!.toUtc().toIso8601String(),
      };
      await ref.read(familyTaskServiceProvider).createTask(input);
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
          const Text('Create Task', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Task Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _priority,
                  decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Low')),
                    DropdownMenuItem(value: 'medium', child: Text('Medium')),
                    DropdownMenuItem(value: 'high', child: Text('High')),
                    DropdownMenuItem(value: 'critical', child: Text('Critical')),
                  ],
                  onChanged: (v) => setState(() => _priority = v!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _taskType,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'custom', child: Text('Custom')),
                    DropdownMenuItem(value: 'refill', child: Text('Refill')),
                    DropdownMenuItem(value: 'appointment_support', child: Text('Appointment')),
                  ],
                  onChanged: (v) => setState(() => _taskType = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedAssigneeId,
                  decoration: const InputDecoration(labelText: 'Assign To', border: OutlineInputBorder()),
                  items: _members.map((m) {
                    final name = m['profiles']?['full_name'] ?? 'Unknown';
                    return DropdownMenuItem<String>(value: m['user_id'], child: Text(name));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedAssigneeId = v),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedPatientId,
                  decoration: const InputDecoration(labelText: 'Patient', border: OutlineInputBorder()),
                  items: _members.where((m) => m['role'] == 'patient').map((m) {
                    final name = m['profiles']?['full_name'] ?? 'Unknown';
                    return DropdownMenuItem<String>(value: m['user_id'], child: Text(name));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedPatientId = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(4),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Due Date', border: OutlineInputBorder()),
              child: Text(_dueDate == null ? 'Select Date & Time' : DateFormat('MMM d, yyyy h:mm a').format(_dueDate!)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _create,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _isLoading ? const CircularProgressIndicator() : const Text('Create Task'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
