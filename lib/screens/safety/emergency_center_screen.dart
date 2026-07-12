import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

class EmergencyCenterScreen extends StatefulWidget {
  final String? targetUserId;
  const EmergencyCenterScreen({super.key, this.targetUserId});

  @override
  State<EmergencyCenterScreen> createState() => _EmergencyCenterScreenState();
}

class _EmergencyCenterScreenState extends State<EmergencyCenterScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _emergencyContacts = [];
  String _bloodGroup = '';
  String _allergies = '';
  String _conditions = '';
  String _hospitalName = '';

  @override
  void initState() {
    super.initState();
    _fetchEmergencyInfo();
  }

  Future<void> _fetchEmergencyInfo() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      final queryUserId = widget.targetUserId ?? currentUserId;
      if (queryUserId == null || currentUserId == null) return;

      if (widget.targetUserId != null && widget.targetUserId != currentUserId) {
        // Log emergency access
        try {
          await _supabase.from('emergency_access_log').insert({
            'patient_user_id': queryUserId,
            'accessed_by': currentUserId,
            'source': 'emergency_center',
          });
        } catch (e) {
          debugPrint('Failed to log emergency access: $e');
        }
      }

      final data = await _supabase.from('medical_profiles').select().eq('user_id', queryUserId).maybeSingle();
      if (data != null && mounted) {
        setState(() {
          _bloodGroup = data['blood_group'] ?? 'Unknown';
          _allergies = (data['allergies'] as List?)?.join(', ') ?? 'None';
          _conditions = (data['conditions'] as List?)?.join(', ') ?? 'None';
          _hospitalName = data['hospital_name'] ?? '';
          if (data['emergency_contacts'] != null) {
            _emergencyContacts = List<Map<String, dynamic>>.from(data['emergency_contacts']);
          }
        });
      }
    } catch (e) {
      debugPrint('Fetch emergency info error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildEmergencyAction({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3), width: 2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFFEF2F2),
      appBar: AppBar(
        title: const Text('Emergency Center', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFFDC2626)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('In a life-threatening emergency, always call local emergency services first.',
            style: TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w600, fontSize: 16), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          
          _buildEmergencyAction(
            title: 'Call Ambulance',
            subtitle: 'Dial 108 / 911 immediately',
            icon: LucideIcons.phoneCall,
            color: const Color(0xFFDC2626),
            onTap: () async {
              final uri = Uri(scheme: 'tel', path: '108');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              } else {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open dialer')));
              }
            },
          ),
          
          if (_hospitalName.isNotEmpty)
            _buildEmergencyAction(
              title: 'Navigate to Hospital',
              subtitle: _hospitalName,
              icon: LucideIcons.mapPin,
              color: const Color(0xFF0EA5E9),
              onTap: () async {
                final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(_hospitalName)}');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                } else {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open maps')));
                }
              },
            ),
          
          _buildEmergencyAction(
            title: 'Share Medical ID',
            subtitle: 'Share critical info with paramedics',
            icon: LucideIcons.share2,
            color: const Color(0xFFF59E0B),
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (ctx) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Medical Summary', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                      const SizedBox(height: 16),
                      Text('Blood Group: $_bloodGroup', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text('Allergies: $_allergies', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Conditions: $_conditions', style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56), padding: const EdgeInsets.all(16)),
                        icon: const Icon(LucideIcons.copy),
                        label: const Text('Copy to Clipboard'),
                        onPressed: () async {
                          final summaryText = 'Medical Summary\nBlood Group: $_bloodGroup\nAllergies: $_allergies\nConditions: $_conditions';
                          await Clipboard.setData(ClipboardData(text: summaryText));
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 20),
          const Text('Emergency Contacts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
          const SizedBox(height: 12),
          if (_emergencyContacts.isEmpty)
            const Text('No emergency contacts found. Add them in Medical ID.', style: TextStyle(color: Colors.grey)),
          ..._emergencyContacts.map((contact) {
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(LucideIcons.userCheck, color: Color(0xFFDC2626)),
                title: Text(contact['name'] ?? ''),
                subtitle: Text('${contact['relation'] ?? ''} • ${contact['phone'] ?? ''}'),
                trailing: IconButton(
                  icon: const Icon(LucideIcons.phone, color: Colors.green),
                  onPressed: () async {
                    final phone = contact['phone'] ?? '';
                    if (phone.isEmpty) return;
                    final uri = Uri(scheme: 'tel', path: phone);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri);
                    } else {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open dialer')));
                    }
                  },
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
