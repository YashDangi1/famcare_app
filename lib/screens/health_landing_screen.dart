import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'health_dashboard_screen.dart';
import 'vitals_screen.dart';
import 'appointment_screen.dart';
import '../vault_screen.dart';

enum HealthLandingSection { dashboard, vitals, appointments, records }

class HealthLandingScreen extends StatefulWidget {
  final String? targetUserId;
  final String? targetUserName;
  final HealthLandingSection? initialSection;

  const HealthLandingScreen({
    super.key,
    this.targetUserId,
    this.targetUserName,
    this.initialSection,
  });

  @override
  State<HealthLandingScreen> createState() => _HealthLandingScreenState();
}

class _HealthLandingScreenState extends State<HealthLandingScreen> {
  bool _hasOpenedInitialSection = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasOpenedInitialSection || widget.initialSection == null) return;
    _hasOpenedInitialSection = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.initialSection == null) return;
      _openSection(widget.initialSection!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.targetUserName != null ? "${widget.targetUserName}'s Health" : "Health",
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.withOpacity(0.05),
            child: Row(
              children: [
                const Icon(LucideIcons.checkCircle2, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All vitals up to date',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800]),
                      ),
                      Text(
                        '1 upcoming appointment this week',
                        style: TextStyle(color: Colors.blue[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.9,
              children: [
                _buildGridCard(
                  context,
                  title: 'Dashboard',
                  icon: LucideIcons.layoutDashboard,
                  color: Colors.blue,
                  onTap: () => _openSection(HealthLandingSection.dashboard),
                ),
                _buildGridCard(
                  context,
                  title: 'Vitals',
                  icon: LucideIcons.activity,
                  color: Colors.red,
                  badge: 'Due',
                  onTap: () => _openSection(HealthLandingSection.vitals),
                ),
                _buildGridCard(
                  context,
                  title: 'Appointments',
                  icon: LucideIcons.calendar,
                  color: Colors.orange,
                  badge: '1 New',
                  onTap: () => _openSection(HealthLandingSection.appointments),
                ),
                _buildGridCard(
                  context,
                  title: 'Records',
                  icon: LucideIcons.folderHeart,
                  color: Colors.purple,
                  onTap: () => _openSection(HealthLandingSection.records),
                ),
                _buildGridCard(
                  context,
                  title: 'Reports & Insights',
                  icon: LucideIcons.pieChart,
                  color: Colors.teal,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reports & Insights feature coming soon')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openSection(HealthLandingSection section) {
    switch (section) {
      case HealthLandingSection.dashboard:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HealthDashboardScreen(
              targetUserId: widget.targetUserId,
              targetUserName: widget.targetUserName,
            ),
          ),
        );
        break;
      case HealthLandingSection.vitals:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VitalsScreen(
              targetUserId: widget.targetUserId,
              targetUserName: widget.targetUserName,
            ),
          ),
        );
        break;
      case HealthLandingSection.appointments:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AppointmentScreen(
              targetUserId: widget.targetUserId,
              targetUserName: widget.targetUserName,
            ),
          ),
        );
        break;
      case HealthLandingSection.records:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VaultScreen(
              targetUserId: widget.targetUserId,
              targetUserName: widget.targetUserName,
            ),
          ),
        );
        break;
    }
  }

  Widget _buildGridCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    String? badge,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    const Spacer(),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
