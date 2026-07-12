import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'legal_content_screen.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  void _showTicketForm(BuildContext context, String category, String title) {
    final msgCtrl = TextEditingController();
    final subjectCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: subjectCtrl, decoration: const InputDecoration(labelText: 'Subject')),
                  const SizedBox(height: 12),
                  TextField(controller: msgCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder())),
                ],
              ),
            ),
            actions: [
              if (!isSubmitting) TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              isSubmitting
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: () async {
                        if (msgCtrl.text.isEmpty || subjectCtrl.text.isEmpty) return;
                        setState(() => isSubmitting = true);
                        try {
                          final userId = Supabase.instance.client.auth.currentUser?.id;
                          if (category == 'feedback' || category == 'bug') {
                            await Supabase.instance.client.from('app_feedback').insert({
                              'user_id': userId,
                              'message': msgCtrl.text.trim(),
                              'screen': title,
                              'metadata': {'subject': subjectCtrl.text.trim()},
                            });
                          } else {
                            await Supabase.instance.client.from('support_tickets').insert({
                              'user_id': userId,
                              'category': category,
                              'subject': subjectCtrl.text.trim(),
                              'message': msgCtrl.text.trim(),
                            });
                          }
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Submitted successfully')));
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
                        } finally {
                          if (ctx.mounted) setState(() => isSubmitting = false);
                        }
                      },
                      child: const Text('Submit'),
                    ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildListTile({required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: const Color(0xFF0EA5E9)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      trailing: Icon(LucideIcons.chevronRight, color: Colors.grey.shade300, size: 20),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Help & Support', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              children: [
                _buildListTile(
                  title: 'Contact Support',
                  subtitle: 'Get help with your account or features',
                  icon: LucideIcons.headphones,
                  onTap: () => _showTicketForm(context, 'support', 'Contact Support'),
                ),
                const Divider(height: 1),
                _buildListTile(
                  title: 'Report a Bug',
                  subtitle: 'Found an issue? Let us know',
                  icon: LucideIcons.bug,
                  onTap: () => _showTicketForm(context, 'bug', 'Report a Bug'),
                ),
                const Divider(height: 1),
                _buildListTile(
                  title: 'Feedback & Suggestions',
                  subtitle: 'Help us improve FamCare',
                  icon: LucideIcons.messageSquare,
                  onTap: () => _showTicketForm(context, 'feedback', 'Feedback & Suggestions'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
            child: Text('LEGAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
          ),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Column(
              children: [
                _buildListTile(
                  title: 'Privacy Policy',
                  subtitle: 'How we protect your data',
                  icon: LucideIcons.shield,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalContentScreen(
                      title: 'Privacy Policy',
                      content: 'Privacy Policy\n\nAt FamCare, we take your privacy seriously. All your health data is encrypted and securely stored. We do not sell your personal data to third parties. Your family members can only access the data you explicitly share with them. Please contact support for data deletion requests.',
                    )));
                  },
                ),
                const Divider(height: 1),
                _buildListTile(
                  title: 'Terms of Service',
                  subtitle: 'Rules and guidelines',
                  icon: LucideIcons.fileText,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalContentScreen(
                      title: 'Terms of Service',
                      content: 'Terms of Service\n\nFamCare is a platform designed to help families manage care. It is NOT a replacement for professional medical advice, diagnosis, or treatment. Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition.',
                    )));
                  },
                ),
                const Divider(height: 1),
                _buildListTile(
                  title: 'Medical Disclaimer',
                  subtitle: 'Important health information',
                  icon: LucideIcons.alertTriangle,
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalContentScreen(
                      title: 'Medical Disclaimer',
                      content: 'Medical Disclaimer\n\nThe FamCare application is designed for informational and organizational purposes only. It is not intended to be a substitute for professional medical advice, diagnosis, or treatment. Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition. Do not disregard professional medical advice or delay in seeking it because of something you have read on the FamCare application.\n\nIn case of a medical emergency, call your doctor, 911, or local emergency services immediately.',
                    )));
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
