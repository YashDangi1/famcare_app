import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:share_plus/share_plus.dart';

class MedicineLogScreen extends StatefulWidget {
  final String? medicationId;
  final String? medicineName;
  final bool aggregated;

  const MedicineLogScreen({
    super.key,
    this.medicationId,
    this.medicineName,
    this.aggregated = false,
  });

  @override
  State<MedicineLogScreen> createState() => _MedicineLogScreenState();
}

class _MedicineLogScreenState extends State<MedicineLogScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];
  
  // Total stats for the timeframe
  int _takenCount = 0;
  int _missedCount = 0;
  int _snoozedCount = 0;
  
  // 7-day stats
  int _last7DaysTaken = 0;
  int _last7DaysMissed = 0;
  Map<int, Map<String, int>> _weeklyData = {};

  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final statsQuery = _supabase.from('medicine_logs').select('status, created_at, scheduled_time, medicine_name');
      final logsQuery = _supabase.from('medicine_logs').select();

      final List<Map<String, dynamic>> statsResponse;
      final List<Map<String, dynamic>> logsResponse;

      if (widget.aggregated) {
        statsResponse = await statsQuery.eq('user_id', userId).limit(500);
        logsResponse = await logsQuery.eq('user_id', userId).order('created_at', ascending: false).limit(100);
      } else {
        statsResponse = await statsQuery.eq('medication_id', widget.medicationId!).limit(500);
        logsResponse = await logsQuery.eq('medication_id', widget.medicationId!).order('created_at', ascending: false).limit(60);
      }

      int taken = 0;
      int missed = 0;
      int snoozed = 0;

      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final sevenDaysAgo = todayMidnight.subtract(const Duration(days: 6));

      // Initialize weekly data buckets (1=Mon..7=Sun)
      Map<int, Map<String, int>> weeklyData = {};
      for (int i = 0; i < 7; i++) {
        final d = todayMidnight.subtract(Duration(days: i));
        weeklyData[d.weekday] = {'taken': 0, 'missed': 0};
      }

      for (var row in statsResponse) {
        final status = row['status'] as String?;
        if (status == 'taken') taken++;
        else if (status == 'missed') missed++;
        else if (status == 'snoozed') snoozed++;
        
        final dateStr = row['created_at'] ?? row['scheduled_time'];
        if (dateStr != null) {
          final date = DateTime.parse(dateStr);
          // Only count last 7 days including today
          if (date.isAfter(sevenDaysAgo) || date.isAtSameMomentAs(sevenDaysAgo)) {
            if (status == 'taken') {
               if (weeklyData.containsKey(date.weekday)) {
                 weeklyData[date.weekday]!['taken'] = weeklyData[date.weekday]!['taken']! + 1;
               }
            } else if (status == 'missed') {
               if (weeklyData.containsKey(date.weekday)) {
                 weeklyData[date.weekday]!['missed'] = weeklyData[date.weekday]!['missed']! + 1;
               }
            }
          }
        }
      }

      int last7DaysTaken = 0;
      int last7DaysMissed = 0;
      for (var v in weeklyData.values) {
        last7DaysTaken += v['taken']!;
        last7DaysMissed += v['missed']!;
      }

      if (mounted) {
        setState(() {
          _takenCount = taken;
          _missedCount = missed;
          _snoozedCount = snoozed;
          _weeklyData = weeklyData;
          _last7DaysTaken = last7DaysTaken;
          _last7DaysMissed = last7DaysMissed;
          _logs = List<Map<String, dynamic>>.from(logsResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching logs: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _adherenceScore {
    int total = _last7DaysTaken + _last7DaysMissed;
    if (total == 0) return 0;
    return ((_last7DaysTaken / total) * 100).round();
  }

  void _shareReport() {
    final title = widget.aggregated ? "Overall Adherence Report" : "${widget.medicineName} Adherence Report";
    final buffer = StringBuffer();
    buffer.writeln("📋 $title");
    buffer.writeln("-----------------------------------");
    buffer.writeln("Weekly Adherence Score: $_adherenceScore%");
    buffer.writeln("-----------------------------------");
    buffer.writeln("Last 7 Days Summary:");
    buffer.writeln("✅ Taken: $_last7DaysTaken doses");
    buffer.writeln("❌ Missed: $_last7DaysMissed doses");
    buffer.writeln("");
    buffer.writeln("Overall Lifetime Summary:");
    buffer.writeln("Total Taken: $_takenCount");
    buffer.writeln("Total Missed: $_missedCount");
    buffer.writeln("Total Snoozed: $_snoozedCount");
    buffer.writeln("");
    buffer.writeln("Generated via Famcare App");
    
    Share.share(buffer.toString(), subject: title);
  }

  List<dynamic> _processLogs() {
    if (_logs.isEmpty) return [];

    final List<dynamic> items = [];
    String? lastDate;

    for (var log in _logs) {
      final status = log['status'] as String? ?? 'unknown';
      if (_selectedFilter != 'All' && status != _selectedFilter.toLowerCase()) continue;

      final dateStr = log['created_at'] ?? log['scheduled_time'];
      if (dateStr == null) continue;

      final date = DateTime.parse(dateStr);
      final dateKey = DateFormat('dd MMMM yyyy').format(date);

      if (dateKey != lastDate) {
        items.add("📅 $dateKey");
        lastDate = dateKey;
      }
      items.add(log);
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final processedItems = _processLogs();
    final title = widget.aggregated 
        ? "History & Insights" 
        : "${widget.medicineName ?? 'Medicine'} Insights";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(title, 
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18)
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.share2, color: Color(0xFF0EA5E9)),
            tooltip: "Share Report",
            onPressed: _isLoading ? null : _shareReport,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildHeroScore(),
                      if (_last7DaysTaken + _last7DaysMissed > 0) _buildWeeklyChart(),
                      _buildStatsRow(),
                      _buildFilters(),
                    ],
                  ),
                ),
                processedItems.isEmpty
                    ? SliverFillRemaining(child: _buildEmptyState())
                    : SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final item = processedItems[index];
                              if (item is String) {
                                return _buildDateHeader(item);
                              } else {
                                return _buildLogTile(item as Map<String, dynamic>);
                              }
                            },
                            childCount: processedItems.length,
                          ),
                        ),
                      ),
              ],
            ),
    );
  }

  Widget _buildHeroScore() {
    final score = _adherenceScore;
    Color scoreColor;
    String message;
    
    if (score >= 90) {
      scoreColor = Colors.green;
      message = "Outstanding! Keep it up.";
    } else if (score >= 75) {
      scoreColor = Colors.orange;
      message = "Good, but room for improvement.";
    } else if (score > 0) {
      scoreColor = Colors.red;
      message = "Needs attention. Try setting louder alarms.";
    } else {
      scoreColor = Colors.blueGrey;
      message = "No doses recorded this week.";
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scoreColor.withOpacity(0.1), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scoreColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: scoreColor.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
        ]
      ),
      child: Column(
        children: [
          Text("7-Day Adherence Score", style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text("$score", style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: scoreColor)),
              Text("%", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: scoreColor.withOpacity(0.7))),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final now = DateTime.now();
    final List<BarChartGroupData> barGroups = [];
    
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final data = _weeklyData[date.weekday] ?? {'taken': 0, 'missed': 0};
      final taken = data['taken']!.toDouble();
      final missed = data['missed']!.toDouble();
      
      barGroups.add(
        BarChartGroupData(
          x: 6 - i,
          barRods: [
            BarChartRodData(
              toY: taken + missed,
              rodStackItems: [
                BarChartRodStackItem(0, taken, Colors.green),
                BarChartRodStackItem(taken, taken + missed, Colors.red),
              ],
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        )
      );
    }

    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Weekly Activity", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: barGroups.isEmpty ? 10 : barGroups.map((g) => g.barRods[0].toY).reduce((a,b) => a > b ? a : b) + 1,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final daysAgo = 6 - value.toInt();
                        final d = now.subtract(Duration(days: daysAgo));
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(DateFormat('E').format(d).substring(0, 1), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 1, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[200], strokeWidth: 1)),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("✅ Total Taken", _takenCount, Colors.green),
          _buildStatItem("❌ Total Missed", _missedCount, Colors.red),
          _buildStatItem("😴 Snoozed", _snoozedCount, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        Text("$count", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildFilters() {
    final filters = ['All', 'Taken', 'Missed', 'Snoozed'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f),
              selected: isSelected,
              onSelected: (val) {
                if (val) setState(() => _selectedFilter = f);
              },
              selectedColor: const Color(0xFF0EA5E9).withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF0EA5E9) : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10, left: 4),
      child: Text(
        date,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
        ),
      ),
    );
  }

  Widget _buildLogTile(Map<String, dynamic> log) {
    final status = log['status'] as String? ?? 'unknown';
    final scheduledTimeStr = log['scheduled_time'] as String?;
    final loggedAtStr = log['created_at'] as String?;

    DateTime? scheduledTime;
    if (scheduledTimeStr != null) scheduledTime = DateTime.parse(scheduledTimeStr);

    DateTime? loggedAt;
    if (loggedAtStr != null) loggedAt = DateTime.parse(loggedAtStr);

    IconData icon;
    Color color;
    String statusText;

    final displayScheduledTime = scheduledTime != null
        ? DateFormat('hh:mm a').format(scheduledTime)
        : '--:--';

    switch (status) {
      case 'taken':
        icon = LucideIcons.checkCircle2;
        color = Colors.green;
        final timeTaken = loggedAt != null ? DateFormat('hh:mm a').format(loggedAt) : null;
        statusText = timeTaken != null ? "Due: $displayScheduledTime — Taken at $timeTaken" : "Due: $displayScheduledTime — Taken";
        break;
      case 'missed':
        icon = LucideIcons.xCircle;
        color = Colors.red;
        statusText = "Due: $displayScheduledTime — Missed";
        break;
      case 'snoozed':
        icon = LucideIcons.moon;
        color = Colors.amber;
        final timeSnoozed = loggedAt != null ? DateFormat('hh:mm a').format(loggedAt) : null;
        statusText = timeSnoozed != null ? "Due: $displayScheduledTime — Snoozed at $timeSnoozed" : "Due: $displayScheduledTime — Snoozed";
        break;
      case 'skipped':
        icon = LucideIcons.ban;
        color = Colors.grey;
        statusText = "Due: $displayScheduledTime — Skipped";
        break;
      default:
        icon = LucideIcons.ban;
        color = Colors.grey;
        statusText = "Due: $displayScheduledTime — Skipped";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log['medicine_name'] as String? ?? widget.medicineName ?? 'Medicine',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.clipboardList, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "Logs will appear after reminders are acted on",
            style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
