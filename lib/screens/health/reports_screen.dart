import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/health/health_report_request.dart';
import '../../providers/health/reports_provider.dart';
import 'report_preview_screen.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  final String? targetUserId;
  final String? targetUserName;

  const ReportsScreen({
    super.key,
    this.targetUserId,
    this.targetUserName,
  });

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  final _supabase = Supabase.instance.client;
  String? _generatingType;

  void _generateReport(String reportType) async {
    final uid = widget.targetUserId ?? _supabase.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _generatingType = reportType);

    final request = HealthReportRequest(
      userId: uid,
      reportType: reportType,
    );

    HealthReportPreview? preview;
    if (reportType == 'doctor_visit') {
      preview = await ref.read(reportsProvider.notifier).buildDoctorVisitReport(request);
    } else if (reportType == 'vitals_summary') {
      preview = await ref.read(reportsProvider.notifier).buildVitalsSummaryReport(request);
    } else if (reportType == 'full_health_summary') {
      preview = await ref.read(reportsProvider.notifier).buildFullHealthSummaryReport(request);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${reportType.replaceAll('_', ' ')} coming soon!')));
      return;
    }

    if (mounted) setState(() => _generatingType = null);

    if (preview != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ReportPreviewScreen(preview: preview!),
        ),
      );
    } else if (mounted) {
      final error = ref.read(reportsProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate report: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportsState = ref.watch(reportsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generate Health Reports',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Text(
              'Create comprehensive PDFs to share with doctors or family members.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),

            _buildReportCard(
              title: 'Doctor Visit Summary',
              description: 'Includes active medications, recent vitals, and logged symptoms from the last 30 days. Perfect for your next checkup.',
              icon: LucideIcons.stethoscope,
              color: Colors.blue,
              reportType: 'doctor_visit',
              isGenerating: reportsState.isGenerating,
            ),
            
            const SizedBox(height: 16),

            _buildReportCard(
              title: 'Vitals Summary',
              description: 'A detailed log of all vitals recorded over a custom date range. Good for monitoring chronic conditions like hypertension.',
              icon: LucideIcons.heartPulse,
              color: Colors.red,
              reportType: 'vitals_summary',
              isGenerating: reportsState.isGenerating,
            ),

            const SizedBox(height: 16),

            _buildReportCard(
              title: 'Full Health Export',
              description: 'A complete export of all medical records, vitals, symptoms, and appointments.',
              icon: LucideIcons.folderArchive,
              color: Colors.purple,
              reportType: 'full_health_summary',
              isGenerating: reportsState.isGenerating,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard({
    required String title,
    required String description,
    required IconData icon,
    required MaterialColor color,
    required String reportType,
    required bool isGenerating,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color.shade700, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(description, style: TextStyle(color: Colors.grey.shade600, height: 1.4)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: isGenerating ? null : () => _generateReport(reportType),
              icon: isGenerating && _generatingType == reportType
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(LucideIcons.fileOutput),
              label: Text(
                isGenerating && _generatingType == reportType ? 'Generating...' : 'Generate Report',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: color.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
