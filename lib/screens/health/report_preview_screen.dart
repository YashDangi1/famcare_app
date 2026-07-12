import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../models/health/health_report_request.dart';
import '../../providers/health/reports_provider.dart';
import '../../services/health/reports_service.dart';

class ReportPreviewScreen extends ConsumerStatefulWidget {
  final HealthReportPreview preview;

  const ReportPreviewScreen({super.key, required this.preview});

  @override
  ConsumerState<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends ConsumerState<ReportPreviewScreen> {
  bool _isExporting = false;

  Future<void> _exportAndShare() async {
    setState(() => _isExporting = true);
    try {
      final service = ref.read(reportsServiceProvider);
      final pdfPath = await service.exportPdf(widget.preview);
      await service.shareReport(pdfPath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.preview.rawData;
    final patientName = data['patientName'] ?? 'Unknown';
    final meds = data['medications'] as List? ?? [];
    final vitals = data['vitals'] as List? ?? [];
    final symptoms = data['symptoms'] as List? ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Report Preview', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF334155)),
        actions: [
          IconButton(
            icon: _isExporting 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(LucideIcons.share),
            onPressed: _isExporting ? null : _exportAndShare,
            tooltip: 'Export & Share PDF',
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportAndShare,
              icon: _isExporting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(LucideIcons.fileDown),
              label: Text(_isExporting ? 'Exporting...' : 'Export as PDF', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    const Icon(LucideIcons.activity, size: 40, color: Color(0xFF0EA5E9)),
                    const SizedBox(height: 8),
                    const Text('Health Summary Report', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    const SizedBox(height: 4),
                    Text('Patient: $patientName', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                    Text('Date: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              
              _buildSectionTitle('Active Medications', LucideIcons.pill),
              if (meds.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('No active medications.'))
              else ...meds.map((m) => Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Expanded(child: Text('${m['name']} - ${m['dosage']} (${m['frequency']})', style: const TextStyle(fontSize: 15))),
                  ],
                ),
              )),
              
              const SizedBox(height: 24),
              _buildSectionTitle('Recent Vitals', LucideIcons.heartPulse),
              if (vitals.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('No recent vitals recorded.'))
              else ...vitals.map((v) {
                final date = DateFormat('MMM d').format(DateTime.parse(v['measured_at']));
                final bp = v['bp_systolic'] != null ? '${v['bp_systolic']}/${v['bp_diastolic']} mmHg' : null;
                final hr = v['heart_rate'] != null ? '${v['heart_rate']} bpm' : null;
                final parts = [if (bp != null) 'BP $bp', if (hr != null) 'HR $hr'].join(', ');
                
                return Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$date: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Expanded(child: Text(parts.isEmpty ? 'Recorded' : parts, style: const TextStyle(fontSize: 15))),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 24),
              _buildSectionTitle('Recent Symptoms', LucideIcons.activitySquare),
              if (symptoms.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('No recent symptoms recorded.'))
              else ...symptoms.map((s) {
                final date = DateFormat('MMM d').format(DateTime.parse(s['started_at']));
                return Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$date: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Expanded(child: Text('${s['symptom_type']} (Severity: ${s['severity']}/5)', style: const TextStyle(fontSize: 15))),
                    ],
                  ),
                );
              }),
            ],
          ),
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
