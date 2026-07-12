import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../models/health/appointment.dart';
import '../../models/health/appointment_note.dart';
import '../../providers/health/appointments_provider.dart';
import '../../providers/family/family_group_provider.dart';
import '../../providers/family/family_tasks_provider.dart';
import 'appointment_prep_report_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppointmentDetailScreen extends ConsumerStatefulWidget {
  final Appointment appointment;
  final bool isReadOnly;

  const AppointmentDetailScreen({
    super.key,
    required this.appointment,
    this.isReadOnly = false,
  });

  @override
  ConsumerState<AppointmentDetailScreen> createState() => _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends ConsumerState<AppointmentDetailScreen> {
  AppointmentNote? _note;
  bool _isLoadingNote = true;
  bool _isSaving = false;
  String? _assignedCompanionId;
  String? _assignedCompanionName;

  final _preVisitController = TextEditingController();
  final _visitSummaryController = TextEditingController();
  final _followUpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchNote();
    _fetchCompanion();
  }

  Future<void> _fetchCompanion() async {
    try {
      final myGroup = await ref.read(familyMembershipProvider.future) as Map<String, dynamic>?;
      if (myGroup == null) return;
      
      final tasks = await ref.read(familyTaskServiceProvider).listTasks(myGroup['group_id']);
      final companionTask = tasks.where((t) => t.linkedAppointmentId == widget.appointment.id && t.taskType == 'appointment_companion').firstOrNull;
      
      if (companionTask != null && mounted) {
        setState(() {
          _assignedCompanionId = companionTask.assignedTo;
          _assignedCompanionName = companionTask.metadata['assignee_name'];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchNote() async {
    try {
      final note = await ref.read(appointmentsProvider.notifier).getAppointmentNote(widget.appointment.id);
      if (mounted) {
        setState(() {
          _note = note;
          _isLoadingNote = false;
          if (note != null) {
            _preVisitController.text = note.preVisitQuestions ?? '';
            _visitSummaryController.text = note.visitSummary ?? '';
            _followUpController.text = note.followUpPlan ?? '';
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingNote = false);
    }
  }

  Future<void> _saveNote() async {
    setState(() => _isSaving = true);
    try {
      final updatedNote = AppointmentNote(
        id: _note?.id,
        appointmentId: widget.appointment.id,
        preVisitQuestions: _preVisitController.text.trim().isEmpty ? null : _preVisitController.text.trim(),
        visitSummary: _visitSummaryController.text.trim().isEmpty ? null : _visitSummaryController.text.trim(),
        followUpPlan: _followUpController.text.trim().isEmpty ? null : _followUpController.text.trim(),
      );
      
      final savedNote = await ref.read(appointmentsProvider.notifier).upsertAppointmentNote(updatedNote);
      
      if (mounted) {
        setState(() => _note = savedNote);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notes saved successfully')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save notes: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _markCompleted() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Completed'),
        content: const Text('Are you sure you want to mark this appointment as completed?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Complete')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(appointmentsProvider.notifier).markAppointmentCompleted(widget.appointment.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Appointment completed!')));
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _assignCompanion() async {
    final myGroup = await ref.read(familyMembershipProvider.future) as Map<String, dynamic>?;
    if (myGroup == null) return;
    
    final members = await ref.read(familyMembersProvider(myGroup['group_id']).future);
    
    if (!mounted) return;
    final selectedMember = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Assign Companion', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...members.map((m) {
                final name = m['profiles']?['full_name'] ?? 'Unknown';
                return ListTile(
                  leading: const CircleAvatar(child: Icon(LucideIcons.user)),
                  title: Text(name),
                  subtitle: Text(m['role']),
                  onTap: () => Navigator.pop(ctx, m),
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      }
    );

    if (selectedMember != null) {
      setState(() => _isSaving = true);
      try {
        final userId = selectedMember['user_id'];
        final name = selectedMember['profiles']?['full_name'] ?? 'Unknown';
        
        await ref.read(familyTaskServiceProvider).createTask({
          'group_id': myGroup['group_id'],
          'patient_user_id': widget.appointment.userId,
          'created_by': Supabase.instance.client.auth.currentUser!.id,
          'assigned_to': userId,
          'task_type': 'appointment_companion',
          'title': 'Accompany to Appointment',
          'description': 'Accompany to Dr. ${widget.appointment.doctorName}',
          'priority': 'medium',
          'due_at': widget.appointment.appointmentDate.toIso8601String(),
          'linked_appointment_id': widget.appointment.id,
        });

        if (mounted) {
          setState(() {
            _assignedCompanionId = userId;
            _assignedCompanionName = name;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Companion assigned!')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _preVisitController.dispose();
    _visitSummaryController.dispose();
    _followUpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUpcoming = widget.appointment.status == 'upcoming';
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(widget.appointment.appointmentDate);
    final timeStr = DateFormat('hh:mm a').format(widget.appointment.appointmentDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Appointment Details', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF334155)),
        actions: [
          if (!widget.isReadOnly)
            IconButton(
              icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(LucideIcons.save),
              onPressed: _isSaving ? null : _saveNote,
              tooltip: 'Save Notes',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isUpcoming ? const Color(0xFF0EA5E9).withOpacity(0.1) : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isUpcoming ? LucideIcons.stethoscope : LucideIcons.checkCircle2, 
                      color: isUpcoming ? const Color(0xFF0EA5E9) : Colors.green, 
                      size: 32
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.appointment.doctorName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        if (widget.appointment.specialty != null) ...[
                          const SizedBox(height: 4),
                          Text(widget.appointment.specialty!, style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(LucideIcons.calendar, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Text(dateStr, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(LucideIcons.clock, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Text(timeStr, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Prep Report CTA
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AppointmentPrepReportScreen(
                    appointment: widget.appointment,
                    note: _note,
                  )));
                },
                icon: const Icon(LucideIcons.fileText),
                label: const Text('View Visit Prep Report', style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0EA5E9),
                  side: const BorderSide(color: Color(0xFF0EA5E9)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (widget.appointment.visitReason != null) ...[
              _buildSectionTitle('Reason for Visit', LucideIcons.info),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(widget.appointment.visitReason!, style: TextStyle(color: Colors.grey.shade700)),
              ),
              const SizedBox(height: 24),
            ],

            _buildSectionTitle('Companion', LucideIcons.users),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _assignedCompanionName != null ? Colors.blue.shade50 : Colors.grey.shade100,
                  child: Icon(LucideIcons.user, color: _assignedCompanionName != null ? Colors.blue : Colors.grey),
                ),
                title: Text(_assignedCompanionName ?? 'No companion assigned', style: TextStyle(color: _assignedCompanionName != null ? Colors.black : Colors.grey)),
                trailing: (!widget.isReadOnly && isUpcoming) ? TextButton(
                  onPressed: _assignCompanion,
                  child: Text(_assignedCompanionName == null ? 'Assign' : 'Change'),
                ) : null,
              ),
            ),
            const SizedBox(height: 24),

            if (_isLoadingNote)
              const Center(child: CircularProgressIndicator())
            else ...[
              _buildSectionTitle('Pre-Visit Preparation', LucideIcons.listTodo),
              const SizedBox(height: 8),
              const Text('Jot down any questions or symptoms you want to discuss with the doctor.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: _preVisitController,
                maxLines: 4,
                readOnly: widget.isReadOnly,
                decoration: InputDecoration(
                  hintText: '1. Why am I having headaches?\n2. Should I change my diet?',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                ),
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('Post-Visit Summary', LucideIcons.fileText),
              const SizedBox(height: 8),
              const Text('What did the doctor say? Any new diagnosis or advice?', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 12),
              TextField(
                controller: _visitSummaryController,
                maxLines: 4,
                readOnly: widget.isReadOnly,
                decoration: InputDecoration(
                  hintText: 'Doctor said blood pressure is normal. Recommended more cardio.',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                ),
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('Follow-Up Plan', LucideIcons.calendarClock),
              const SizedBox(height: 12),
              TextField(
                controller: _followUpController,
                maxLines: 2,
                readOnly: widget.isReadOnly,
                decoration: InputDecoration(
                  hintText: 'Book next appointment in 6 months.',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                ),
              ),
              const SizedBox(height: 32),
            ],

            if (!widget.isReadOnly && isUpcoming)
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _markCompleted,
                  icon: const Icon(LucideIcons.checkCircle2),
                  label: const Text('Mark as Completed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0EA5E9)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
      ],
    );
  }
}
