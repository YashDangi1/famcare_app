import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class MedicalProfileForm extends StatelessWidget {
  final bool isEditing;
  final TextEditingController bloodGroupCtrl;
  final TextEditingController allergiesCtrl;
  final TextEditingController conditionsCtrl;
  final TextEditingController medicationsCtrl;
  final TextEditingController doctorNameCtrl;
  final TextEditingController doctorPhoneCtrl;
  final TextEditingController hospitalNameCtrl;
  final List<Map<String, dynamic>> emergencyContacts;
  final VoidCallback onAddEmergencyContact;
  final Function(int) onRemoveEmergencyContact;

  const MedicalProfileForm({
    super.key,
    required this.isEditing,
    required this.bloodGroupCtrl,
    required this.allergiesCtrl,
    required this.conditionsCtrl,
    required this.medicationsCtrl,
    required this.doctorNameCtrl,
    required this.doctorPhoneCtrl,
    required this.hospitalNameCtrl,
    required this.emergencyContacts,
    required this.onAddEmergencyContact,
    required this.onRemoveEmergencyContact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Basic Health Info'),
        _buildTextField('Blood Group', bloodGroupCtrl, icon: LucideIcons.droplet),
        _buildTextField('Allergies (comma separated)', allergiesCtrl, icon: LucideIcons.alertTriangle),
        _buildTextField('Chronic Conditions', conditionsCtrl, icon: LucideIcons.activity),
        _buildTextField('Current Medications', medicationsCtrl, icon: LucideIcons.pill),
        
        const SizedBox(height: 24),
        _buildSectionHeader('Primary Care'),
        _buildTextField('Doctor Name', doctorNameCtrl, icon: LucideIcons.stethoscope),
        _buildTextField('Doctor Phone', doctorPhoneCtrl, icon: LucideIcons.phone, keyboardType: TextInputType.phone),
        _buildTextField('Preferred Hospital', hospitalNameCtrl, icon: LucideIcons.building),
        
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Emergency Contacts'),
            if (isEditing)
              IconButton(
                icon: const Icon(LucideIcons.plusCircle, color: Color(0xFF0EA5E9)),
                onPressed: onAddEmergencyContact,
              ),
          ],
        ),
        if (emergencyContacts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('No emergency contacts added.', style: TextStyle(color: Colors.grey)),
          ),
        ...emergencyContacts.asMap().entries.map((entry) {
          final idx = entry.key;
          final contact = entry.value;
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
            child: ListTile(
              leading: const Icon(LucideIcons.userCheck, color: Colors.red),
              title: Text(contact['name'] ?? ''),
              subtitle: Text('${contact['relation'] ?? ''} • ${contact['phone'] ?? ''}'),
              trailing: isEditing
                  ? IconButton(
                      icon: const Icon(LucideIcons.trash2, color: Colors.grey),
                      onPressed: () => onRemoveEmergencyContact(idx),
                    )
                  : IconButton(
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
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {IconData? icon, TextInputType? keyboardType}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: controller,
        enabled: isEditing,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: Colors.grey, size: 20) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
