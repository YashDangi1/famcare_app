import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../settings_screen.dart';
import 'alarm_setup_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../login_screen.dart';
import 'safety/medical_id_screen.dart';
import 'safety/emergency_center_screen.dart';
import 'settings/family_notifications_screen.dart';
import 'support/help_center_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionHeader('Account'),
          _buildRichTile(
            context,
            icon: LucideIcons.user,
            title: 'Profile & Settings',
            subtitle: 'Manage your account details',
            statusText: 'Configured',
            statusColor: Colors.green,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
          
          const SizedBox(height: 24),
          _buildSectionHeader('Reminders'),
          _buildRichTile(
            context,
            icon: LucideIcons.alarmClock,
            title: 'Alarm Setup',
            subtitle: 'Permissions and battery config',
            statusText: 'Check',
            statusColor: Colors.orange,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AlarmSetupScreen()));
            },
          ),
          _buildRichTile(
            context,
            icon: LucideIcons.bellRing,
            title: 'Family Notifications',
            subtitle: 'Alerts for missed meds & vitals',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyNotificationsScreen()));
            },
          ),
          
          const SizedBox(height: 24),
          _buildSectionHeader('Safety & Support'),
          _buildRichTile(
            context,
            icon: LucideIcons.shieldAlert,
            iconColor: Colors.red,
            title: 'Medical ID',
            subtitle: 'Allergies and emergency contacts',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicalIdScreen()));
            },
          ),
          _buildRichTile(
            context,
            icon: LucideIcons.siren,
            iconColor: Colors.red,
            title: 'Emergency Center',
            subtitle: 'Call ambulance & contacts',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyCenterScreen()));
            },
          ),
          _buildRichTile(
            context,
            icon: LucideIcons.helpCircle,
            iconColor: Colors.blue,
            title: 'Help & Support',
            subtitle: 'Contact support, legal, FAQ',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpCenterScreen()));
            },
          ),
          
          const SizedBox(height: 32),
          _buildRichTile(
            context,
            icon: LucideIcons.logOut,
            iconColor: Colors.red,
            title: 'Sign Out',
            subtitle: 'Log out of your account',
            titleColor: Colors.red,
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildRichTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Color? iconColor,
    Color? titleColor,
    String? statusText,
    Color? statusColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (iconColor ?? const Color(0xFF0EA5E9)).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor ?? const Color(0xFF0EA5E9)),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: titleColor)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        trailing: statusText != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor?.withOpacity(0.1) ?? Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor ?? Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : const Icon(LucideIcons.chevronRight, color: Colors.grey, size: 20),
        onTap: onTap,
      ),
    );
  }
}
