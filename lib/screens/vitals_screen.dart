import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../services/vitals_service.dart';
import 'vitals_input_sheet.dart';

class VitalsScreen extends StatefulWidget {
  final String? targetUserId;
  final String? targetUserName;

  const VitalsScreen({super.key, this.targetUserId, this.targetUserName});

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  final _vitalsService = VitalsService();
  bool _isLoading = true;
  Map<String, dynamic>? _latestVitals;
  List<Map<String, dynamic>> _vitalsHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchVitalsData();
  }

  Future<void> _fetchVitalsData() async {
    if (!mounted) return;
    
    // Always show skeleton on first load for smooth transition
    final isInitialLoad = _latestVitals == null && _vitalsHistory.isEmpty;
    if (isInitialLoad) {
      setState(() => _isLoading = true);
    }
    
    try {
      // Start fetching
      final latestFuture = _vitalsService.getLatestVitals(userId: widget.targetUserId);
      final historyFuture = _vitalsService.getVitalsHistory(userId: widget.targetUserId);
      
      // Wait for both, and add a small minimum delay for the shimmer to be visible
      final results = await Future.wait([
  latestFuture,
  historyFuture,
]);

      if (mounted) {
        setState(() {
          _latestVitals = results[0] as Map<String, dynamic>?;
          _vitalsHistory = results[1] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching vitals: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showVitalsInput() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => VitalsInputSheet(onSave: _fetchVitalsData),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card Skeleton
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            const SizedBox(height: 30),
            // Chart Section Title Skeleton
            Container(height: 20, width: 150, color: Colors.white),
            const SizedBox(height: 15),
            // Chart Skeleton
            Container(
              height: 250,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 30),
            // Recent Logs Title Skeleton
            Container(height: 20, width: 120, color: Colors.white),
            const SizedBox(height: 15),
            // List Items Skeleton
            ...List.generate(3, (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.targetUserName != null ? "${widget.targetUserName}'s Vitals" : "My Vitals", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? _buildLoadingSkeleton()
          : RefreshIndicator(
              onRefresh: _fetchVitalsData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SECTION 1: TOP SUMMARY CARD ---
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: _buildLatestVitalsCard(),
                    ),

                    // --- SECTION 2: THE CHART SECTION ---
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Heart Rate Trend',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildHeartRateChart(),
                    ),

                    // --- SECTION 3: THE HISTORY LIST ---
                    const SizedBox(height: 30),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'Recent Logs',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildHistoryList(),
                    ),
                    const SizedBox(height: 100), // Space for FAB
                  ],
                ),
              ),
            ),
      floatingActionButton: widget.targetUserId != null ? null : FloatingActionButton(
        heroTag: 'add_vitals_fab',
        onPressed: _showVitalsInput,
        backgroundColor: const Color(0xFF0EA5E9),
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
    );
  }

  Widget _buildLatestVitalsCard() {
    if (_latestVitals == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Icon(LucideIcons.activity, size: 50, color: Colors.grey[300]),
            const SizedBox(height: 15),
            const Text("No readings yet", style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Summary', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              Icon(LucideIcons.heartPulse, color: Colors.white.withOpacity(0.8), size: 28),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            DateFormat('MMM dd, hh:mm a').format(DateTime.parse(_latestVitals!['measured_at'] ?? DateTime.now().toIso8601String())),
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
          ),
          const SizedBox(height: 25),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricItem(
                LucideIcons.heart,
                'Heart Rate',
                '${_latestVitals!['heart_rate'] ?? '--'}',
                'bpm',
              ),
              _buildMetricItem(
                LucideIcons.activity,
                'Blood Pressure',
                '${_latestVitals!['bp_systolic'] ?? '--'}/${_latestVitals!['bp_diastolic'] ?? '--'}',
                'mmHg',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(IconData icon, String label, String value, String unit) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 10),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
      ],
    );
  }

  Widget _buildHeartRateChart() {
    if (_vitalsHistory.isEmpty) return const SizedBox.shrink();

    final heartRateData = _vitalsHistory
        .where((v) => v['heart_rate'] != null)
        .toList()
        .reversed
        .toList();

    if (heartRateData.isEmpty) {
      return Container(
        height: 250,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[100]!)),
        child: const Text("Need more data for trend", style: TextStyle(color: Colors.grey)),
      );
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.only(right: 20, top: 20, bottom: 10, left: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < heartRateData.length) {
                    final date = DateTime.parse(heartRateData[value.toInt()]['measured_at'] ?? DateTime.now().toIso8601String());
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(DateFormat('dd/MM').format(date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: heartRateData.asMap().entries.map((e) {
                return FlSpot(e.key.toDouble(), double.tryParse(e.value['heart_rate'].toString()) ?? 0);
              }).toList(),
              isCurved: true,
              curveSmoothness: 0.35,
              color: const Color(0xFF0EA5E9),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0EA5E9).withOpacity(0.2),
                    const Color(0xFF0EA5E9).withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_vitalsHistory.isEmpty) return const SizedBox.shrink();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _vitalsHistory.length,
      itemBuilder: (context, index) {
        final log = _vitalsHistory[index];
        final date = DateTime.parse(log['measured_at'] ?? DateTime.now().toIso8601String());
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[100]!),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(LucideIcons.activity, color: Color(0xFF0EA5E9), size: 20),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vitals Reading',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      DateFormat('MMM dd, yyyy • hh:mm a').format(date),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (log['heart_rate'] != null)
                    Text('${log['heart_rate']} bpm', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B))),
                  if (log['bp_systolic'] != null)
                    Text('${log['bp_systolic']}/${log['bp_diastolic']} mmHg', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
