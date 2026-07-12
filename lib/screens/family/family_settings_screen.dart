import 'package:flutter/material.dart';

class FamilySettingsScreen extends StatefulWidget {
  const FamilySettingsScreen({super.key});

  @override
  State<FamilySettingsScreen> createState() => _FamilySettingsScreenState();
}

class _FamilySettingsScreenState extends State<FamilySettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Family Settings'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Alert Rules', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('Missed Dose Escalation'),
              subtitle: const Text('Level 1: 15m, Level 2: 30m'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
          const SizedBox(height: 24),
          const Text('Quiet Hours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: const Text('10:00 PM - 06:00 AM'),
              trailing: Switch(value: true, onChanged: (v) {}),
            ),
          ),
        ],
      ),
    );
  }
}
