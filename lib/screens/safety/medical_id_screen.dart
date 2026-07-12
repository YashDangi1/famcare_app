import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/safety/medical_profile_form.dart';

class MedicalIdScreen extends StatefulWidget {
  final String? targetUserId;
  const MedicalIdScreen({super.key, this.targetUserId});

  @override
  State<MedicalIdScreen> createState() => _MedicalIdScreenState();
}

class _MedicalIdScreenState extends State<MedicalIdScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;

  final _bloodGroupCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _conditionsCtrl = TextEditingController();
  final _medicationsCtrl = TextEditingController();
  final _doctorNameCtrl = TextEditingController();
  final _doctorPhoneCtrl = TextEditingController();
  final _hospitalNameCtrl = TextEditingController();

  List<Map<String, dynamic>> _emergencyContacts = [];

  @override
  void initState() {
    super.initState();
    _fetchMedicalProfile();
  }

  bool _canEdit = false;

  Future<void> _fetchMedicalProfile() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      final queryUserId = widget.targetUserId ?? currentUserId;
      if (queryUserId == null || currentUserId == null) return;

      bool canEditProfile = (queryUserId == currentUserId);

      if (widget.targetUserId != null && widget.targetUserId != currentUserId) {
        // Log emergency access
        try {
          await _supabase.from('emergency_access_log').insert({
            'patient_user_id': queryUserId,
            'accessed_by': currentUserId,
            'source': 'family_hub',
          });
        } catch (e) {
          debugPrint('Failed to log emergency access: $e');
        }

        // Check if caregiver has permission to edit
        try {
          final members = await _supabase
            .from('family_members')
            .select('group_id, can_edit_emergency, role')
            .eq('user_id', currentUserId)
            .eq('status', 'approved');
            
          final patientMembers = await _supabase
            .from('family_members')
            .select('group_id')
            .eq('user_id', queryUserId)
            .eq('status', 'approved');
            
          final myGroups = (members as List).map((m) => m['group_id']).toSet();
          final theirGroups = (patientMembers as List).map((m) => m['group_id']).toSet();
          
          if (myGroups.intersection(theirGroups).isNotEmpty) {
             final myShared = (members as List).where((m) => theirGroups.contains(m['group_id']));
             canEditProfile = myShared.any((m) => m['can_edit_emergency'] == true || m['role'] == 'admin');
          }
        } catch (e) {
          debugPrint('Permission check error: $e');
        }
      }

      final data = await _supabase
          .from('medical_profiles')
          .select()
          .eq('user_id', queryUserId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _canEdit = canEditProfile;
          if (data != null) {
            _bloodGroupCtrl.text = data['blood_group'] ?? '';
            _allergiesCtrl.text = (data['allergies'] as List?)?.join(', ') ?? '';
            _conditionsCtrl.text = (data['conditions'] as List?)?.join(', ') ?? '';
            _medicationsCtrl.text = data['current_med_summary'] ?? '';
            _doctorNameCtrl.text = data['doctor_name'] ?? '';
            _doctorPhoneCtrl.text = data['doctor_phone'] ?? '';
            _hospitalNameCtrl.text = data['hospital_name'] ?? '';
            
            if (data['emergency_contacts'] != null) {
              _emergencyContacts = List<Map<String, dynamic>>.from(data['emergency_contacts']);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Fetch medical profile error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMedicalProfile() async {
    setState(() => _isSaving = true);
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      final queryUserId = widget.targetUserId ?? currentUserId;
      if (queryUserId == null || currentUserId == null) return;

      final allergiesList = _allergiesCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final conditionsList = _conditionsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      await _supabase.from('medical_profiles').upsert({
        'user_id': queryUserId,
        'blood_group': _bloodGroupCtrl.text.trim(),
        'allergies': allergiesList,
        'conditions': conditionsList,
        'current_med_summary': _medicationsCtrl.text.trim(),
        'doctor_name': _doctorNameCtrl.text.trim(),
        'doctor_phone': _doctorPhoneCtrl.text.trim(),
        'hospital_name': _hospitalNameCtrl.text.trim(),
        'emergency_contacts': _emergencyContacts,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': currentUserId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Medical ID saved successfully')));
        setState(() => _isEditing = false);
      }
    } catch (e) {
      debugPrint('Save medical profile error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addEmergencyContact() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relationCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Emergency Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone),
            TextField(controller: relationCtrl, decoration: const InputDecoration(labelText: 'Relation (e.g. Spouse)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _emergencyContacts.add({
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'relation': relationCtrl.text.trim(),
                });
                _isEditing = true;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Medical ID', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          if (_canEdit)
            if (_isEditing)
              _isSaving
                  ? const Padding(padding: EdgeInsets.all(16.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                  : TextButton(
                      onPressed: _saveMedicalProfile,
                      child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9))),
                    )
            else
              IconButton(
                icon: const Icon(LucideIcons.edit),
                onPressed: () => setState(() => _isEditing = true),
              ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MedicalProfileForm(
            isEditing: _isEditing,
            bloodGroupCtrl: _bloodGroupCtrl,
            allergiesCtrl: _allergiesCtrl,
            conditionsCtrl: _conditionsCtrl,
            medicationsCtrl: _medicationsCtrl,
            doctorNameCtrl: _doctorNameCtrl,
            doctorPhoneCtrl: _doctorPhoneCtrl,
            hospitalNameCtrl: _hospitalNameCtrl,
            emergencyContacts: _emergencyContacts,
            onAddEmergencyContact: _addEmergencyContact,
            onRemoveEmergencyContact: (idx) {
              setState(() {
                _emergencyContacts.removeAt(idx);
              });
            },
          ),
        ],
      ),
    );
  }
}
