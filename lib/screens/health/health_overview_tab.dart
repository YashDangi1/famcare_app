import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';

class HealthOverviewTab extends StatefulWidget {
  final String? targetUserId;

  const HealthOverviewTab({super.key, this.targetUserId});

  @override
  State<HealthOverviewTab> createState() => _HealthOverviewTabState();
}

class _HealthOverviewTabState extends State<HealthOverviewTab> {
  bool _isLoading = true;
  int _activeMedsCount = 0;
  int _recordsCount = 0;
  Map<String, dynamic>? _latestVital;

  @override
  void initState() {
    super.initState();
    _fetchOverviewData();
  }

  Future<void> _fetchOverviewData() async {
    setState(() => _isLoading = true);
    try {
      final uid = widget.targetUserId ?? Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final userId = uid;

      // Active Meds
      final today = DateTime.now().toIso8601String().split('T')[0];
      final medsResponse = await Supabase.instance.client
          .from('medications')
          .select('id')
          .eq('user_id', userId)
          .eq('is_active', true)
          .lte('start_date', today)
          .gte('end_date', today);
      
      // Records Count
      final recordsResponse = await Supabase.instance.client
          .from('health_records')
          .select('id')
          .eq('user_id', userId);
      
      // Latest Vital
      final vitalsResponse = await Supabase.instance.client
          .from('vitals')
          .select()
          .eq('user_id', userId)
          .order('measured_at', ascending: false)
          .limit(1);

      setState(() {
        _activeMedsCount = (medsResponse as List).length;
        _recordsCount = (recordsResponse as List).length;
        if (vitalsResponse.isNotEmpty) {
          _latestVital = vitalsResponse.first;
        }
      });
    } catch (e) {
      debugPrint('Error fetching overview data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
          : RefreshIndicator(
              onRefresh: _fetchOverviewData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuickActionsRow(),
                    const SizedBox(height: 24),
                    _buildSectionTitle("Health Snapshot"),
                    const SizedBox(height: 12),
                    _buildSnapshotCardsRow(),
                    const SizedBox(height: 24),
                    _buildSectionTitle("Latest Vitals"),
                    const SizedBox(height: 12),
                    _buildLatestVitalsCard(),
                    const SizedBox(height: 24),
                    _buildSectionTitle("Recent Symptoms"),
                    const SizedBox(height: 12),
                    _buildPlaceholderCard("No recent symptoms logged", LucideIcons.activitySquare),
                    const SizedBox(height: 24),
                    _buildSectionTitle("Next Appointment"),
                    const SizedBox(height: 12),
                    _buildPlaceholderCard("No upcoming appointments", LucideIcons.calendarClock),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
    );
  }

  Widget _buildQuickActionsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildQuickActionBtn("Log Vitals", LucideIcons.activity, Colors.red, () {}),
          _buildQuickActionBtn("Add Symptom", LucideIcons.activitySquare, Colors.orange, () {}),
          _buildQuickActionBtn("Upload Record", LucideIcons.uploadCloud, Colors.purple, () {}),
          _buildQuickActionBtn("Book Visit", LucideIcons.calendarPlus, Colors.teal, () {}),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn(String label, IconData icon, MaterialColor color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color.shade700),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color.shade800)),
          ],
        ),
      ),
    );
  }

  Widget _buildSnapshotCardsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildMiniCard(
            title: "Active Meds",
            value: _activeMedsCount.toString(),
            icon: LucideIcons.pill,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMiniCard(
            title: "Records",
            value: _recordsCount.toString(),
            icon: LucideIcons.folderHeart,
            color: Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniCard({required String title, required String value, required IconData icon, required MaterialColor color}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCard(String text, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestVitalsCard() {
    if (_latestVital == null) {
      return _buildPlaceholderCard("No vitals recorded yet", LucideIcons.heartPulse);
    }

    final measuredAt = _latestVital!['measured_at'] != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(_latestVital!['measured_at']))
        : 'Unknown date';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.heartPulse, color: Color(0xFF0EA5E9), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Most Recent Reading", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(measuredAt, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (_latestVital!['bp_systolic'] != null)
                _buildVitalChip("BP", "${_latestVital!['bp_systolic']}/${_latestVital!['bp_diastolic'] ?? '?'}", LucideIcons.activity, Colors.red),
              if (_latestVital!['heart_rate'] != null)
                _buildVitalChip("HR", "${_latestVital!['heart_rate']} bpm", LucideIcons.heart, Colors.pink),
              if (_latestVital!['spo2'] != null)
                _buildVitalChip("SpO2", "${_latestVital!['spo2']}%", LucideIcons.wind, Colors.blue),
              if (_latestVital!['weight'] != null)
                _buildVitalChip("Weight", "${_latestVital!['weight']} kg", LucideIcons.scale, Colors.orange),
              if (_latestVital!['temperature'] != null)
                _buildVitalChip("Temp", "${_latestVital!['temperature']}°F", LucideIcons.thermometer, Colors.amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVitalChip(String label, String value, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color.shade700),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color.shade700)),
            ],
          ),
        ],
      ),
    );
  }
}
