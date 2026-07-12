import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/health/health_report_request.dart';
import '../activity_service.dart';

class ReportsService {
  final _supabase = Supabase.instance.client;

  Future<HealthReportPreview> buildDoctorVisitReport(HealthReportRequest request) async {
    final uid = request.userId;
    
    // Fetch user profile
    final profileRes = await _supabase.from('profiles').select().eq('id', uid).maybeSingle();
    final patientName = profileRes?['full_name'] ?? 'Patient';

    // Fetch active medications
    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final medsRes = await _supabase.from('medications')
      .select()
      .eq('user_id', uid)
      .eq('is_active', true)
      .lte('start_date', todayStr)
      .gte('end_date', todayStr);

    // Fetch recent vitals (last 30 days)
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    final vitalsRes = await _supabase.from('vitals')
      .select()
      .eq('user_id', uid)
      .gte('measured_at', thirtyDaysAgo)
      .order('measured_at', ascending: false)
      .limit(5);

    // Fetch recent symptoms (last 30 days)
    final symptomsRes = await _supabase.from('symptoms')
      .select()
      .eq('user_id', uid)
      .gte('started_at', thirtyDaysAgo)
      .order('started_at', ascending: false);

    final rawData = {
      'patientName': patientName,
      'medications': medsRes,
      'vitals': vitalsRes,
      'symptoms': symptomsRes,
      'generatedAt': DateTime.now().toIso8601String(),
    };

    // A simple HTML preview string for UI
    final htmlContent = '''
    <h2>Doctor Visit Summary</h2>
    <p><b>Patient:</b> $patientName</p>
    <p><b>Generated:</b> ${DateFormat('MMM d, yyyy').format(DateTime.now())}</p>
    <hr/>
    <h3>Active Medications (${(medsRes as List).length})</h3>
    <ul>
      ${medsRes.map((m) => '<li>${m['name']} - ${m['dosage']} (${m['frequency']})</li>').join('')}
    </ul>
    <h3>Recent Vitals</h3>
    <ul>
      ${(vitalsRes as List).map((v) => '<li>${DateFormat('MMM d').format(DateTime.parse(v['measured_at']))}: BP ${v['bp_systolic'] ?? '?'}/${v['bp_diastolic'] ?? '?'} mmHg, HR ${v['heart_rate'] ?? '?'} bpm</li>').join('')}
    </ul>
    <h3>Recent Symptoms</h3>
    <ul>
      ${(symptomsRes as List).map((s) => '<li>${DateFormat('MMM d').format(DateTime.parse(s['started_at']))}: ${s['symptom_type']} (Severity: ${s['severity']}/5)</li>').join('')}
    </ul>
    ''';

    return HealthReportPreview(
      reportType: request.reportType,
      htmlContent: htmlContent,
      rawData: rawData,
    );
  }

  Future<HealthReportPreview> buildVitalsSummaryReport(HealthReportRequest request) async {
    final uid = request.userId;
    
    final profileRes = await _supabase.from('profiles').select().eq('id', uid).maybeSingle();
    final patientName = profileRes?['full_name'] ?? 'Patient';

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    final vitalsRes = await _supabase.from('vitals')
      .select()
      .eq('user_id', uid)
      .gte('measured_at', thirtyDaysAgo)
      .order('measured_at', ascending: false);

    final rawData = {
      'patientName': patientName,
      'vitals': vitalsRes,
      'generatedAt': DateTime.now().toIso8601String(),
    };

    final htmlContent = '''
    <h2>Vitals Summary (Last 30 Days)</h2>
    <p><b>Patient:</b> $patientName</p>
    <p><b>Generated:</b> ${DateFormat('MMM d, yyyy').format(DateTime.now())}</p>
    <hr/>
    <ul>
      ${(vitalsRes as List).map((v) => '<li>${DateFormat('MMM d, h:mm a').format(DateTime.parse(v['measured_at']))}: BP ${v['bp_systolic'] ?? '-'}/${v['bp_diastolic'] ?? '-'}, HR ${v['heart_rate'] ?? '-'}, SpO2 ${v['spo2'] ?? '-'}%</li>').join('')}
    </ul>
    ''';

    return HealthReportPreview(
      reportType: request.reportType,
      htmlContent: htmlContent,
      rawData: rawData,
    );
  }

  Future<HealthReportPreview> buildFullHealthSummaryReport(HealthReportRequest request) async {
    final uid = request.userId;
    
    final profileRes = await _supabase.from('profiles').select().eq('id', uid).maybeSingle();
    final patientName = profileRes?['full_name'] ?? 'Patient';

    final medsRes = await _supabase.from('medications').select().eq('user_id', uid);
    final vitalsRes = await _supabase.from('vitals').select().eq('user_id', uid).order('measured_at', ascending: false);
    final symptomsRes = await _supabase.from('symptoms').select().eq('user_id', uid).order('started_at', ascending: false);
    final appointmentsRes = await _supabase.from('appointments').select().eq('user_id', uid).order('appointment_date', ascending: false);

    final rawData = {
      'patientName': patientName,
      'medications': medsRes,
      'vitals': vitalsRes,
      'symptoms': symptomsRes,
      'appointments': appointmentsRes,
      'generatedAt': DateTime.now().toIso8601String(),
    };

    final htmlContent = '''
    <h2>Full Health Export</h2>
    <p><b>Patient:</b> $patientName</p>
    <p><b>Generated:</b> ${DateFormat('MMM d, yyyy').format(DateTime.now())}</p>
    <hr/>
    <p>Contains complete history of Medications (${(medsRes as List).length}), Vitals (${(vitalsRes as List).length}), Symptoms (${(symptomsRes as List).length}), and Appointments (${(appointmentsRes as List).length}). Export PDF to view all data.</p>
    ''';

    return HealthReportPreview(
      reportType: request.reportType,
      htmlContent: htmlContent,
      rawData: rawData,
    );
  }

  Future<String> exportPdf(HealthReportPreview preview) async {
    final pdf = pw.Document();
    final data = preview.rawData;
    final patientName = data['patientName'] ?? 'Unknown Patient';
    final meds = data['medications'] as List? ?? [];
    final vitals = data['vitals'] as List? ?? [];
    final symptoms = data['symptoms'] as List? ?? [];
    final appointments = data['appointments'] as List? ?? [];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              title: 'Health Summary Report',
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Health Summary Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.Text(DateFormat('MMM d, yyyy').format(DateTime.now()), style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                ],
              )
            ),
            pw.SizedBox(height: 20),
            pw.Text('Patient: $patientName', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            
            // Medications Section
            pw.Text('Active Medications', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
            pw.Divider(),
            if (meds.isEmpty) pw.Text('No active medications recorded.', style: const pw.TextStyle(color: PdfColors.grey700))
            else pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: meds.map((m) => pw.Bullet(text: '${m['name']} - ${m['dosage']} (${m['frequency']})')).toList(),
            ),
            pw.SizedBox(height: 20),

            // Vitals Section
            pw.Text('Recent Vitals (Last 30 Days)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
            pw.Divider(),
            if (vitals.isEmpty) pw.Text('No recent vitals recorded.', style: const pw.TextStyle(color: PdfColors.grey700))
            else pw.TableHelper.fromTextArray(
              headers: ['Date', 'Blood Pressure', 'Heart Rate', 'SpO2', 'Weight', 'Temp'],
              data: vitals.map((v) {
                return [
                  DateFormat('MMM d').format(DateTime.parse(v['measured_at'])),
                  v['bp_systolic'] != null ? '${v['bp_systolic']}/${v['bp_diastolic']}' : '-',
                  v['heart_rate'] != null ? '${v['heart_rate']} bpm' : '-',
                  v['spo2'] != null ? '${v['spo2']}%' : '-',
                  v['weight'] != null ? '${v['weight']} kg' : '-',
                  v['temperature'] != null ? '${v['temperature']}°F' : '-',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),

            // Symptoms Section
            pw.Text('Recent Symptoms (Last 30 Days)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
            pw.Divider(),
            if (symptoms.isEmpty) pw.Text('No recent symptoms recorded.', style: const pw.TextStyle(color: PdfColors.grey700))
            else pw.TableHelper.fromTextArray(
              headers: ['Date', 'Symptom', 'Severity', 'Notes'],
              data: symptoms.map((s) {
                return [
                  DateFormat('MMM d').format(DateTime.parse(s['started_at'])),
                  s['symptom_type'],
                  '${s['severity']}/5',
                  s['notes'] ?? '-',
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),

            if (appointments.isNotEmpty) ...[
              pw.Text('Appointments History', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.Divider(),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Doctor', 'Status'],
                data: appointments.map((a) {
                  return [
                    DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(a['appointment_date'])),
                    a['doctor_name'] ?? '-',
                    a['status'] ?? '-',
                  ];
                }).toList(),
              ),
            ]
          ];
        },
      ),
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/health_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());

    // Track the export
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        final now = DateTime.now();
        await Supabase.instance.client.from('health_report_exports').insert({
          'user_id': userId,
          'report_type': preview.reportType,
          'date_range_start': now.subtract(const Duration(days: 30)).toIso8601String(),
          'date_range_end': now.toIso8601String(),
          'file_url': 'local://${file.path.split('/').last}',
          'metadata': {
            'generated_from': 'mobile_app',
            'has_meds': meds.isNotEmpty,
            'has_vitals': vitals.isNotEmpty,
          },
        });
      } catch (e) {
        debugPrint('Failed to log report export: $e');
      }
    }

    // Record activity
    try {
      await ActivityService.log(
        actionType: 'REPORT_GENERATED',
        description: 'Generated a ${preview.reportType.replaceAll('_', ' ')}',
      );
    } catch (e) {
      debugPrint('Error logging activity: $e');
    }

    return file.path;
  }

  Future<void> shareReport(String filePath) async {
    await Share.shareXFiles([XFile(filePath)], text: 'My Health Report from FamCare');
  }
}
