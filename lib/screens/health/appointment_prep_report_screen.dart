import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/health/appointment.dart';
import '../../models/health/appointment_note.dart';
import '../../providers/medication_provider.dart';
import '../../providers/health/symptoms_provider.dart';
import '../../services/vitals_service.dart';

class AppointmentPrepReportScreen extends ConsumerStatefulWidget {
  final Appointment appointment;
  final AppointmentNote? note;

  const AppointmentPrepReportScreen({
    super.key,
    required this.appointment,
    this.note,
  });

  @override
  ConsumerState<AppointmentPrepReportScreen> createState() => _AppointmentPrepReportScreenState();
}

class _AppointmentPrepReportScreenState extends ConsumerState<AppointmentPrepReportScreen> {
  Map<String, dynamic>? _latestVitals;
  bool _isLoadingVitals = true;

  @override
  void initState() {
    super.initState();
    // Pre-fetch data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(medicationsProvider.notifier).fetchMedications(widget.appointment.userId, showLoading: false);
      ref.read(symptomsProvider.notifier).fetchSymptoms(widget.appointment.userId);
      _fetchVitals();
    });
  }

  Future<void> _fetchVitals() async {
    final svc = VitalsService();
    try {
      final vitals = await svc.getLatestVitals(userId: widget.appointment.userId);
      if (mounted) setState(() => _latestVitals = vitals);
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoadingVitals = false);
    }
  }

  String _generateReportText(BuildContext context) {
    final medsState = ref.read(medicationsProvider);
    final symptomsState = ref.read(symptomsProvider);

    final sb = StringBuffer();
    sb.writeln('DOCTOR VISIT PREP REPORT');
    sb.writeln('========================\n');
    
    sb.writeln('Doctor: ${widget.appointment.doctorName}');
    sb.writeln('Date: ${DateFormat('MMMM d, yyyy h:mm a').format(widget.appointment.appointmentDate)}');
    if (widget.appointment.visitReason != null && widget.appointment.visitReason!.isNotEmpty) {
      sb.writeln('Reason for Visit: ${widget.appointment.visitReason}');
    }
    sb.writeln('\n');

    if (widget.note?.preVisitQuestions != null && widget.note!.preVisitQuestions!.isNotEmpty) {
      sb.writeln('MY QUESTIONS / CONCERNS');
      sb.writeln('-----------------------');
      sb.writeln(widget.note!.preVisitQuestions);
      sb.writeln('\n');
    }

    sb.writeln('CURRENT MEDICATIONS');
    sb.writeln('-------------------');
    if (medsState.hasValue && medsState.value!.isNotEmpty) {
      for (final m in medsState.value!) {
        sb.writeln('- ${m.name} (${m.dosage}) - ${m.frequency} times/day');
      }
    } else {
      sb.writeln('No active medications listed.');
    }
    sb.writeln('\n');

    sb.writeln('LATEST VITALS');
    sb.writeln('-------------');
    if (_latestVitals != null) {
      final date = DateTime.parse(_latestVitals!['measured_at']).toLocal();
      sb.writeln('Recorded on: ${DateFormat('MMM d').format(date)}');
      if (_latestVitals!['bp_systolic'] != null) {
        sb.writeln('Blood Pressure: ${_latestVitals!['bp_systolic']}/${_latestVitals!['bp_diastolic']} mmHg');
      }
      if (_latestVitals!['heart_rate'] != null) {
        sb.writeln('Heart Rate: ${_latestVitals!['heart_rate']} bpm');
      }
      if (_latestVitals!['weight'] != null) {
        sb.writeln('Weight: ${_latestVitals!['weight']} kg');
      }
    } else {
      sb.writeln('No recent vitals logged.');
    }
    sb.writeln('\n');

    sb.writeln('RECENT SYMPTOMS');
    sb.writeln('---------------');
    if (symptomsState.hasValue && symptomsState.value!.isNotEmpty) {
      final recent = symptomsState.value!.take(5).toList();
      for (final s in recent) {
        sb.writeln('- ${s.symptomType} (Severity: ${s.severity}/10) on ${DateFormat('MMM d').format(s.startedAt)}');
      }
    } else {
      sb.writeln('No recent symptoms logged.');
    }

    return sb.toString();
  }

  void _handleShare() {
    final text = _generateReportText(context);
    Share.share(text, subject: 'Doctor Visit Prep - ${widget.appointment.doctorName}');
  }

  @override
  Widget build(BuildContext context) {
    final medsState = ref.watch(medicationsProvider);
    final symptomsState = ref.watch(symptomsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Prep Report', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF334155)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.share, color: Color(0xFF0EA5E9)),
            tooltip: 'Share Report',
            onPressed: _handleShare,
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
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
                      color: const Color(0xFF0EA5E9).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(LucideIcons.fileText, color: Color(0xFF0EA5E9), size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Doctor Visit Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                        const SizedBox(height: 4),
                        Text('For ${widget.appointment.doctorName}', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Pre-Visit Questions
            if (widget.note?.preVisitQuestions != null && widget.note!.preVisitQuestions!.isNotEmpty) ...[
              _buildSectionTitle('My Questions', LucideIcons.helpCircle),
              const SizedBox(height: 12),
              _buildCardContainer(
                child: Text(widget.note!.preVisitQuestions!, style: const TextStyle(fontSize: 15, height: 1.5)),
              ),
              const SizedBox(height: 24),
            ],

            // Current Medications
            _buildSectionTitle('Current Medications', LucideIcons.pill),
            const SizedBox(height: 12),
            _buildCardContainer(
              child: medsState.when(
                data: (meds) {
                  if (meds.isEmpty) return const Text('No active medications listed.', style: TextStyle(color: Colors.grey));
                  return Column(
                    children: meds.map((m) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(LucideIcons.pill, color: Colors.blue, size: 20),
                      title: Text('${m.name} (${m.dosage})', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${m.frequency} times/day', style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                    )).toList(),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error loading meds: $e'),
              ),
            ),
            const SizedBox(height: 24),

            // Latest Vitals
            _buildSectionTitle('Latest Vitals', LucideIcons.activity),
            const SizedBox(height: 12),
            _buildCardContainer(
              child: _isLoadingVitals
                  ? const CircularProgressIndicator()
                  : _latestVitals == null
                      ? const Text('No recent vitals logged.', style: TextStyle(color: Colors.grey))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Recorded on: ${DateFormat('MMM d, yyyy').format(DateTime.parse(_latestVitals!['measured_at']).toLocal())}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                            const SizedBox(height: 12),
                            if (_latestVitals!['bp_systolic'] != null)
                              _buildVitalRow(LucideIcons.activitySquare, 'Blood Pressure', '${_latestVitals!['bp_systolic']}/${_latestVitals!['bp_diastolic']} mmHg'),
                            if (_latestVitals!['heart_rate'] != null)
                              _buildVitalRow(LucideIcons.heartPulse, 'Heart Rate', '${_latestVitals!['heart_rate']} bpm'),
                            if (_latestVitals!['weight'] != null)
                              _buildVitalRow(LucideIcons.scale, 'Weight', '${_latestVitals!['weight']} kg'),
                          ],
                        ),
            ),
            const SizedBox(height: 24),

            // Recent Symptoms
            _buildSectionTitle('Recent Symptoms', LucideIcons.thermometer),
            const SizedBox(height: 12),
            _buildCardContainer(
              child: symptomsState.when(
                data: (symptoms) {
                  if (symptoms.isEmpty) return const Text('No recent symptoms logged.', style: TextStyle(color: Colors.grey));
                  final recent = symptoms.take(3).toList(); // Show top 3
                  return Column(
                    children: recent.map((s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
                        child: Icon(LucideIcons.alertCircle, color: Colors.orange.shade700, size: 16),
                      ),
                      title: Text(s.symptomType, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${DateFormat('MMM d').format(s.startedAt)} • Severity: ${s.severity}/10', style: const TextStyle(fontSize: 12)),
                      visualDensity: VisualDensity.compact,
                    )).toList(),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error loading symptoms: $e'),
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
        Icon(icon, size: 20, color: const Color(0xFF334155)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
      ],
    );
  }

  Widget _buildCardContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }

  Widget _buildVitalRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade300),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        ],
      ),
    );
  }
}
