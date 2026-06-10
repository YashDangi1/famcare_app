import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../services/alarm_service.dart';

class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen({super.key});

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('appointments')
          .select()
          .eq('user_id', userId)
          .gte('appointment_time', DateTime.now().toIso8601String())
          .order('appointment_time', ascending: true);

      if (mounted) {
        setState(() {
          _appointments = List<Map<String, dynamic>>.from(response as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch appointments error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAppointment(String id) async {
    try {
      await _supabase.from('appointments').delete().eq('id', id);
      // Cancel reminder notification (ID = hash of appointment ID)
      final notifId = id.hashCode.abs() % 1000000;
      await AlarmService().notificationsPlugin.cancel(notifId);
      _fetchAppointments();
    } catch (e) {
      debugPrint('Delete appointment error: $e');
    }
  }

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddAppointmentSheet(
        onSaved: () {
          Navigator.pop(ctx);
          _fetchAppointments();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Appointments', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF334155)),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSheet,
        backgroundColor: const Color(0xFF0EA5E9),
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _appointments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.calendarX, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text('No upcoming appointments', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                      const SizedBox(height: 8),
                      Text('Tap + to add one', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _appointments.length,
                  itemBuilder: (context, index) => _buildAppointmentCard(_appointments[index]),
                ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> appt) {
    final doctorName = appt['doctor_name'] ?? 'Doctor';
    final apptTime = DateTime.tryParse(appt['appointment_time']?.toString() ?? '')?.toLocal();
    final notes = appt['notes']?.toString() ?? '';
    final reminderEnabled = appt['reminder_enabled'] == true;

    final dateStr = apptTime != null ? DateFormat('EEE, dd MMM yyyy').format(apptTime) : '';
    final timeStr = apptTime != null ? DateFormat('hh:mm a').format(apptTime) : '';

    return Dismissible(
      key: Key(appt['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(16)),
        child: const Icon(LucideIcons.trash2, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await _deleteAppointment(appt['id']);
        return false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.stethoscope, color: Color(0xFF0EA5E9), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doctorName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B))),
                  const SizedBox(height: 4),
                  Text('$dateStr  •  $timeStr',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  if (notes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(notes,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                if (reminderEnabled)
                  Icon(LucideIcons.bell, color: Colors.amber[600], size: 16),
                const SizedBox(height: 4),
                Icon(LucideIcons.chevronRight, color: Colors.grey[300], size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AddAppointmentSheet extends StatefulWidget {
  final VoidCallback onSaved;

  const _AddAppointmentSheet({required this.onSaved});

  @override
  State<_AddAppointmentSheet> createState() => _AddAppointmentSheetState();
}

class _AddAppointmentSheetState extends State<_AddAppointmentSheet> {
  final _supabase = Supabase.instance.client;
  final _doctorController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _selectedDateTime;
  bool _reminderEnabled = true;
  bool _isSaving = false;

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return;

    setState(() {
      _selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (_doctorController.text.trim().isEmpty || _selectedDateTime == null) return;

    setState(() => _isSaving = true);
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final response = await _supabase.from('appointments').insert({
        'user_id': userId,
        'doctor_name': _doctorController.text.trim(),
        'appointment_time': _selectedDateTime!.toUtc().toIso8601String(),
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'reminder_enabled': _reminderEnabled,
      }).select().maybeSingle();
      if (response == null) {
        throw Exception('Failed to save appointment');
      }

      // Schedule reminder notification 60 min before
      if (_reminderEnabled) {
        final apptId = response['id'] as String;
        final reminderTime = _selectedDateTime!.subtract(const Duration(minutes: 60));
        if (reminderTime.isAfter(DateTime.now())) {
          final notifId = apptId.hashCode.abs() % 1000000;
          const androidDetails = AndroidNotificationDetails(
            'famcare_appointments',
            'Appointment Reminders',
            channelDescription: 'Reminders for upcoming appointments',
            importance: Importance.high,
            priority: Priority.high,
          );
          const details = NotificationDetails(android: androidDetails);

          await AlarmService().notificationsPlugin.zonedSchedule(
            notifId,
            'Appointment Reminder',
            '${_doctorController.text.trim()} — 1 ghante baad appointment hai!',
            tz.TZDateTime.from(reminderTime, tz.local),
            details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
          debugPrint('Appointment reminder scheduled for $reminderTime');
        }
      }

      widget.onSaved();
    } catch (e) {
      debugPrint('Save appointment error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _doctorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('New Appointment', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 20),
          TextField(
            controller: _doctorController,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Doctor Name *',
              prefixIcon: const Icon(LucideIcons.user, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _pickDateTime,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date & Time *',
                prefixIcon: const Icon(LucideIcons.calendar, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              child: Text(
                _selectedDateTime != null
                    ? DateFormat('EEE, dd MMM yyyy  •  hh:mm a').format(_selectedDateTime!)
                    : 'Select date and time',
                style: TextStyle(
                  color: _selectedDateTime != null ? const Color(0xFF1E293B) : Colors.grey[400],
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              prefixIcon: const Icon(LucideIcons.fileText, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reminder (60 min before)', style: TextStyle(fontSize: 14)),
            subtitle: Text(
              _reminderEnabled ? 'You\'ll be notified 1 hour before' : 'No reminder',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            value: _reminderEnabled,
            activeColor: const Color(0xFF0EA5E9),
            onChanged: (val) => setState(() => _reminderEnabled = val),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (_doctorController.text.trim().isEmpty || _selectedDateTime == null || _isSaving)
                  ? null
                  : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Appointment', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
