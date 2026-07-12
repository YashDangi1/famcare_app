import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/family/family_member_permission.dart';
import '../../services/family/family_service.dart';

class MemberPermissionsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> member;
  final String groupId;
  final bool isAdmin;

  const MemberPermissionsScreen({
    super.key,
    required this.member,
    required this.groupId,
    required this.isAdmin,
  });

  @override
  ConsumerState<MemberPermissionsScreen> createState() => _MemberPermissionsScreenState();
}

class _MemberPermissionsScreenState extends ConsumerState<MemberPermissionsScreen> {
  late bool canViewMeds;
  late bool canEditMeds;
  late bool canViewVitals;
  late bool canLogVitals;
  late bool canViewAppointments;
  late bool canManageAppointments;
  late bool canViewRecords;
  late bool canUploadRecords;
  late bool canManageTasks;
  late bool canViewEmergency;
  late bool canEditEmergency;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initValues();
  }

  void _initValues() {
    canViewMeds = widget.member['can_view_meds'] ?? true;
    canEditMeds = widget.member['can_edit_meds'] ?? false;
    canViewVitals = widget.member['can_view_vitals'] ?? true;
    canLogVitals = widget.member['can_log_vitals'] ?? false;
    canViewAppointments = widget.member['can_view_appointments'] ?? true;
    canManageAppointments = widget.member['can_manage_appointments'] ?? false;
    canViewRecords = widget.member['can_view_records'] ?? true;
    canUploadRecords = widget.member['can_upload_records'] ?? false;
    canManageTasks = widget.member['can_manage_tasks'] ?? false;
    canViewEmergency = widget.member['can_view_emergency'] ?? false;
    canEditEmergency = widget.member['can_edit_emergency'] ?? false;
  }

  Future<void> _savePermissions() async {
    setState(() => _isSaving = true);
    try {
      final input = FamilyMemberPermissionInput(
        canViewMeds: canViewMeds,
        canEditMeds: canEditMeds,
        canViewVitals: canViewVitals,
        canLogVitals: canLogVitals,
        canViewAppointments: canViewAppointments,
        canManageAppointments: canManageAppointments,
        canViewRecords: canViewRecords,
        canUploadRecords: canUploadRecords,
        canManageTasks: canManageTasks,
        canViewEmergency: canViewEmergency,
        canEditEmergency: canEditEmergency,
      );

      final service = FamilyService(Supabase.instance.client);
      await service.updateMemberPermissions(widget.groupId, widget.member['user_id'], input);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permissions updated successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update permissions: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberName = widget.member['profiles']?['full_name'] ?? 'Member';

    return Scaffold(
      appBar: AppBar(
        title: Text('$memberName\'s Roles'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (widget.isAdmin)
            _isSaving
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  )
                : TextButton(
                    onPressed: _savePermissions,
                    child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
        ],
      ),
      body: ListView(
        children: [
          if (!widget.isAdmin)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.withOpacity(0.1),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You are viewing this member\'s permissions. Only group admins can edit permissions.',
                      style: TextStyle(color: Colors.blue, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          _buildSectionHeader('Medications'),
          _buildSwitch('View Medications', canViewMeds, (val) => setState(() => canViewMeds = val)),
          _buildSwitch('Edit/Add Medications', canEditMeds, (val) => setState(() => canEditMeds = val)),
          
          _buildSectionHeader('Vitals'),
          _buildSwitch('View Vitals', canViewVitals, (val) => setState(() => canViewVitals = val)),
          _buildSwitch('Log Vitals', canLogVitals, (val) => setState(() => canLogVitals = val)),
          
          _buildSectionHeader('Appointments'),
          _buildSwitch('View Appointments', canViewAppointments, (val) => setState(() => canViewAppointments = val)),
          _buildSwitch('Manage Appointments', canManageAppointments, (val) => setState(() => canManageAppointments = val)),

          _buildSectionHeader('Health Records'),
          _buildSwitch('View Records', canViewRecords, (val) => setState(() => canViewRecords = val)),
          _buildSwitch('Upload Records', canUploadRecords, (val) => setState(() => canUploadRecords = val)),

          _buildSectionHeader('Collaboration & Safety'),
          _buildSwitch('Manage Family Tasks', canManageTasks, (val) => setState(() => canManageTasks = val)),
          _buildSwitch('View Emergency Info', canViewEmergency, (val) => setState(() => canViewEmergency = val)),
          _buildSwitch('Edit Emergency Info', canEditEmergency, (val) => setState(() => canEditEmergency = val)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitch(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 16)),
      value: value,
      onChanged: widget.isAdmin ? onChanged : null,
      activeColor: Colors.blue,
    );
  }
}
