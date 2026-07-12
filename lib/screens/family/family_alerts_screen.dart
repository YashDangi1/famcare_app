import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../providers/family/family_alerts_provider.dart';
import '../../services/family/family_alert_service.dart';

class FamilyAlertsScreen extends ConsumerStatefulWidget {
  final String groupId;
  const FamilyAlertsScreen({super.key, required this.groupId});

  @override
  ConsumerState<FamilyAlertsScreen> createState() => _FamilyAlertsScreenState();
}

class _FamilyAlertsScreenState extends ConsumerState<FamilyAlertsScreen> {
  Future<void> _acknowledge(String alertId) async {
    try {
      await ref.read(familyAlertServiceProvider).acknowledgeAlert(alertId);
      // ignore: unused_result
      ref.refresh(familyAlertsProvider(widget.groupId));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _resolve(String alertId) async {
    try {
      await ref.read(familyAlertServiceProvider).resolveAlert(alertId);
      // ignore: unused_result
      ref.refresh(familyAlertsProvider(widget.groupId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alert resolved successfully')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error resolving alert: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(familyAlertsProvider(widget.groupId));

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Family Alerts', style: TextStyle(color: Colors.red)),
        backgroundColor: Colors.red[50],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.red),
      ),
      body: alertsAsync.when(
        data: (alerts) {
          if (alerts.isEmpty) {
            return const Center(child: Text('No active alerts.', style: TextStyle(color: Colors.grey)));
          }

          return RefreshIndicator(
            onRefresh: () async {
              // ignore: unused_result
              ref.refresh(familyAlertsProvider(widget.groupId));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                return _buildAlertCard(alerts[index]);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final title = alert['title'] as String;
    final message = alert['message'] as String;
    final severity = alert['severity'] as String;
    final status = alert['status'] as String;
    final createdAt = DateTime.parse(alert['created_at']).toLocal();

    final isCritical = severity == 'critical';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16), 
        side: BorderSide(color: isCritical ? Colors.red[300]! : Colors.orange[300]!)
      ),
      color: isCritical ? Colors.red[50] : Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isCritical ? LucideIcons.alertTriangle : LucideIcons.bell, color: isCritical ? Colors.red : Colors.orange),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isCritical ? Colors.red[900] : Colors.orange[900]))),
                Text(DateFormat('h:mm a').format(createdAt), style: TextStyle(color: isCritical ? Colors.red[300] : Colors.orange[300], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 12),
            Text(message, style: TextStyle(color: isCritical ? Colors.red[800] : Colors.orange[800])),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status == 'open')
                  TextButton(
                    onPressed: () => _acknowledge(alert['id']),
                    child: Text('Acknowledge', style: TextStyle(color: isCritical ? Colors.red[700] : Colors.orange[700])),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _resolve(alert['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCritical ? Colors.red : Colors.orange,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: const Text('Resolve'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
