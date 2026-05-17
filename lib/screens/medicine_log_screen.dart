import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

class MedicineLogScreen extends StatefulWidget {
  final String medicationId;
  final String medicineName;

  const MedicineLogScreen({
    super.key,
    required this.medicationId,
    required this.medicineName,
  });

  @override
  State<MedicineLogScreen> createState() => _MedicineLogScreenState();
}

class _MedicineLogScreenState extends State<MedicineLogScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];
  int _takenCount = 0;
  int _missedCount = 0;
  int _snoozedCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Fetch stats
      final statsResponse = await _supabase
          .from('medicine_logs')
          .select('status')
          .eq('medication_id', widget.medicationId);

      int taken = 0;
      int missed = 0;
      int snoozed = 0;

      for (var row in statsResponse) {
        final status = row['status'] as String?;
        if (status == 'taken') taken++;
        else if (status == 'missed') missed++;
        else if (status == 'snoozed') snoozed++;
      }

      // Fetch logs
      final logsResponse = await _supabase
          .from('medicine_logs')
          .select('*')
          .eq('medication_id', widget.medicationId)
          .order('created_at', ascending: false)
          .limit(60);

      if (mounted) {
        setState(() {
          _takenCount = taken;
          _missedCount = missed;
          _snoozedCount = snoozed;
          _logs = List<Map<String, dynamic>>.from(logsResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching logs: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _processLogs() {
    if (_logs.isEmpty) return [];

    final List<dynamic> items = [];
    String? lastDate;

    for (var log in _logs) {
      // Use created_at or scheduled_time for grouping
      final dateStr = log['created_at'] ?? log['scheduled_time'];
      if (dateStr == null) continue;

      final date = DateTime.parse(dateStr);
      final dateKey = DateFormat('dd MMMM yyyy').format(date);

      if (dateKey != lastDate) {
        items.add("📅 $dateKey"); // Header with icon
        lastDate = dateKey;
      }
      items.add(log); // Log entry
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final processedItems = _processLogs();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("${widget.medicineName} — Log", 
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 18)
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
          : Column(
              children: [
                _buildStatsRow(),
                Expanded(
                  child: _logs.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: processedItems.length,
                          itemBuilder: (context, index) {
                            final item = processedItems[index];
                            if (item is String) {
                              return _buildDateHeader(item);
                            } else {
                              return _buildLogTile(item as Map<String, dynamic>);
                            }
                          },
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
          _buildStatItem("✅ Taken", _takenCount, Colors.green),
          _buildStatItem("❌ Missed", _missedCount, Colors.red),
          _buildStatItem("😴 Snoozed", _snoozedCount, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        Text("$count", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
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
      default:
        icon = LucideIcons.helpCircle;
        color = Colors.grey;
        statusText = "Due: $displayScheduledTime — Unknown";
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
            child: Text(
              statusText,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
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
            "No logs yet",
            style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
