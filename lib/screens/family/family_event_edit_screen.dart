import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../providers/family/family_events_provider.dart';
import '../../models/family/family_event.dart';

class FamilyEventEditScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String patientUserId;
  final DateTime initialDate;

  const FamilyEventEditScreen({super.key, required this.groupId, required this.patientUserId, required this.initialDate});

  @override
  ConsumerState<FamilyEventEditScreen> createState() => _FamilyEventEditScreenState();
}

class _FamilyEventEditScreenState extends ConsumerState<FamilyEventEditScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _eventType = 'appointment';
  bool _isAllDay = false;
  late DateTime _startAt;
  late DateTime _endAt;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startAt = widget.initialDate;
    _endAt = widget.initialDate.add(const Duration(hours: 1));
  }

  Future<void> _selectDateTime(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startAt : _endAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStart ? _startAt : _endAt),
      );
      if (time != null) {
        setState(() {
          final dt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          if (isStart) _startAt = dt;
          else _endAt = dt;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final service = ref.read(familyEventServiceProvider);
      await service.upsertEvent({
        'group_id': widget.groupId,
        'patient_user_id': widget.patientUserId,
        'created_by': Supabase.instance.client.auth.currentUser!.id,
        'event_type': _eventType,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'start_at': _startAt.toUtc().toIso8601String(),
        'end_at': _endAt.toUtc().toIso8601String(),
        'is_all_day': _isAllDay,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Event')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _eventType,
            decoration: const InputDecoration(labelText: 'Event Type', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'appointment', child: Text('Appointment')),
              DropdownMenuItem(value: 'task_due', child: Text('Task Deadline')),
              DropdownMenuItem(value: 'care_visit', child: Text('Care Visit')),
              DropdownMenuItem(value: 'med_support_window', child: Text('Med Support')),
              DropdownMenuItem(value: 'routine', child: Text('Routine')),
              DropdownMenuItem(value: 'custom', child: Text('Custom')),
            ],
            onChanged: (val) => setState(() => _eventType = val!),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('All Day'),
            value: _isAllDay,
            onChanged: (val) => setState(() => _isAllDay = val),
            contentPadding: EdgeInsets.zero,
          ),
          ListTile(
            title: const Text('Start'),
            subtitle: Text(DateFormat('MMM dd, yyyy - jm').format(_startAt)),
            trailing: const Icon(Icons.calendar_today),
            onTap: () => _selectDateTime(true),
            contentPadding: EdgeInsets.zero,
          ),
          if (!_isAllDay)
            ListTile(
              title: const Text('End'),
              subtitle: Text(DateFormat('MMM dd, yyyy - jm').format(_endAt)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _selectDateTime(false),
              contentPadding: EdgeInsets.zero,
            ),
          const SizedBox(height: 16),
          TextField(controller: _descController, maxLines: 3, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Event'),
            ),
          )
        ],
      ),
    );
  }
}
