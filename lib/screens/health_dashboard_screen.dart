import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

class HealthDashboardScreen extends StatefulWidget {
  final String? targetUserId;
  final String? targetUserName;

  const HealthDashboardScreen({super.key, this.targetUserId, this.targetUserName});

  @override
  State<HealthDashboardScreen> createState() => _HealthDashboardScreenState();
}

class _HealthDashboardScreenState extends State<HealthDashboardScreen> {
  bool _isLoading = true;
  int _activeMedsCount = 0;
  List<dynamic> _lowStockMeds = [];
  Map<String, dynamic>? _latestVital;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final uid = widget.targetUserId ?? Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final userId = uid;

      // 1. Fetch active, non-expired medications
      final today = DateTime.now().toIso8601String().split('T')[0];
      final medsResponse = await Supabase.instance.client
          .from('medications')
          .select()
          .eq('user_id', userId)
          .eq('is_active', true)
          .lte('start_date', today)
          .gte('end_date', today);

      final medsList = medsResponse as List<dynamic>;

      // 2. Filter low stock (exclude qty=0 — those are already inactive)
      final lowStock = medsList.where((m) {
        final qty = int.tryParse(m['qty']?.toString() ?? '0') ?? 0;
        final freq = int.tryParse(m['frequency']?.toString() ?? '1') ?? 1;
        return qty > 0 && qty <= (freq * 3); // Dynamic threshold: 3 days worth
      }).toList();

      // 3. Fetch latest vital (use measured_at — same as vitals_screen)
      final vitalsResponse = await Supabase.instance.client
          .from('vitals')
          .select()
          .eq('user_id', userId)
          .order('measured_at', ascending: false)
          .limit(1);

      setState(() {
        _activeMedsCount = medsList.where((m) => m['is_active'] == true).length;
        _lowStockMeds = lowStock;
        if (vitalsResponse.isNotEmpty) {
          _latestVital = vitalsResponse.first;
        }
      });
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dashboard Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titlePrefix = widget.targetUserName != null ? "${widget.targetUserName}'s" : "My";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("$titlePrefix Health Dashboard", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
          : RefreshIndicator(
              onRefresh: _fetchDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle("Active Medicines"),
                    const SizedBox(height: 12),
                    _buildActiveMedicinesCard(),
                    const SizedBox(height: 24),
                    _buildSectionTitle("Low Stock Alerts"),
                    const SizedBox(height: 12),
                    _buildLowStockSection(),
                    const SizedBox(height: 24),
                    _buildSectionTitle("Latest Vitals"),
                    const SizedBox(height: 12),
                    _buildLatestVitalsCard(),
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

  // --- Section 1: Active Medicines ---
  Widget _buildActiveMedicinesCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Color.fromRGBO(14, 165, 233, 0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(LucideIcons.pill, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$_activeMedsCount",
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  _activeMedsCount == 1 ? "Active Medicine" : "Active Medicines",
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.85)),
                ),
              ],
            ),
          ),
          if (_activeMedsCount == 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text("All clear!", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  // --- Section 2: Low Stock Alerts ---
  Widget _buildLowStockSection() {
    if (_lowStockMeds.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.checkCircle, color: Colors.green[600], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "All medicines have sufficient stock",
                style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _lowStockMeds.map((med) {
        final qty = int.tryParse(med['qty']?.toString() ?? '0') ?? 0;
        final name = med['name'] ?? 'Unknown';
        final freq = int.tryParse(med['frequency']?.toString() ?? '1') ?? 1;
        final daysLeft = freq > 0 ? (qty / freq).floor() : 0;

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red[200]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(LucideIcons.alertTriangle, color: Colors.red[600], size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      "$qty left · ~$daysLeft day${daysLeft == 1 ? '' : 's'} remaining",
                      style: TextStyle(color: Colors.red[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[600],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text("Low", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- Section 3: Latest Vitals ---
  Widget _buildLatestVitalsCard() {
    if (_latestVital == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.heartPulse, color: Colors.grey[400], size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "No vitals recorded yet",
                style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
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

  Widget _buildVitalChip(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ],
      ),
    );
  }
}
