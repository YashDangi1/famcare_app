import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class WeeklySummaryScreen extends StatefulWidget {
  const WeeklySummaryScreen({super.key});

  @override
  State<WeeklySummaryScreen> createState() => _WeeklySummaryScreenState();
}

class _WeeklySummaryScreenState extends State<WeeklySummaryScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  
  int _takenDoses = 0;
  int _missedDoses = 0;
  int _tasksCompleted = 0;
  int _alertsGenerated = 0;
  List<Map<String, dynamic>> _recentLogs = [];

  @override
  void initState() {
    super.initState();
    _fetchWeeklySummary();
  }

  Future<void> _fetchWeeklySummary() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase.rpc('rpc_get_weekly_family_summary');
      if (response != null && response is Map<String, dynamic> && response['error'] == null) {
        final meds = response['meds'] as Map<String, dynamic>? ?? {};
        final tasks = response['tasks'] as Map<String, dynamic>? ?? {};
        final alerts = response['alerts'] as int? ?? 0;

        if (mounted) {
          setState(() {
            _takenDoses = meds['total_taken'] ?? 0;
            _missedDoses = (meds['total_due'] ?? 0) - _takenDoses;
            _tasksCompleted = tasks['total_done'] ?? 0;
            _alertsGenerated = alerts;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching summary: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final totalDoses = _takenDoses + _missedDoses;
    final adherence = totalDoses > 0 ? (_takenDoses / totalDoses * 100).toStringAsFixed(0) : "0";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Weekly Summary', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF2563EB)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Weekly Adherence', style: TextStyle(color: Colors.white70, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('$adherence%', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(LucideIcons.activity, color: Colors.white, size: 32),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: _buildStatCard('Taken', _takenDoses.toString(), LucideIcons.checkCircle, Colors.green)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Missed', _missedDoses.toString(), LucideIcons.xCircle, Colors.red)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildStatCard('Tasks Done', _tasksCompleted.toString(), LucideIcons.checkSquare, Colors.purple)),
                const SizedBox(width: 16),
                Expanded(child: _buildStatCard('Alerts', _alertsGenerated.toString(), LucideIcons.alertTriangle, Colors.orange)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
        ],
      ),
    );
  }
}
