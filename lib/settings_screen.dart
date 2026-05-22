import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/alarm_setup_screen.dart';
import 'utils/snackbar_utils.dart';
import 'login_screen.dart';
import 'services/slot_preferences_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedBloodGroup;
  File? _avatarImage;
  bool _isSaving = false;
  bool _isLoading = true;
  bool _alarmStyleFullscreen = true; // default: full screen

  // Slot preferences
  final _slotService = SlotPreferencesService();
  Map<String, dynamic> _slotPrefs = {};
  bool _slotPrefsLoaded = false;

  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final data = await Supabase.instance.client.from('profiles').select('*').eq('id', userId).maybeSingle();

      // Load alarm style preference
      final prefs = await SharedPreferences.getInstance();
      final fullscreen = prefs.getBool('alarm_style_fullscreen') ?? true;

      // Load slot preferences
      final slotPrefs = await _slotService.getPreferences();

      if (data != null && mounted) {
        File? avatar;
        if (data['avatar_url'] != null) {
          final dir = await getApplicationDocumentsDirectory();
          avatar = File('${dir.path}/${data['avatar_url']}');
        }
        setState(() {
          _nameController.text = data['full_name'] ?? '';
          _ageController.text = data['age']?.toString() ?? '';
          _phoneController.text = data['phone_number'] ?? '';
          _selectedBloodGroup = data['blood_group'];
          _avatarImage = avatar;
          _alarmStyleFullscreen = fullscreen;
          _slotPrefs = slotPrefs;
          _slotPrefsLoaded = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(LucideIcons.camera),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(LucideIcons.image),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = await File(pickedFile.path).copy('${directory.path}/$fileName');
        setState(() => _avatarImage = savedImage);
      }
    }
  }

  Future<void> _updateProfile() async {
    setState(() => _isSaving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      await Supabase.instance.client.from('profiles').upsert({
        'id': userId,
        'full_name': _nameController.text.trim(),
        'age': int.tryParse(_ageController.text.trim()),
        'phone_number': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'blood_group': _selectedBloodGroup,
        'avatar_url': _avatarImage != null ? _avatarImage!.path.split('/').last : null,
        'updated_at': DateTime.now().toIso8601String(),
      });
      if (mounted) AppSnackBar.showSuccess(context, 'Profile Updated!');
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _avatarImage != null && _avatarImage!.existsSync() ? FileImage(_avatarImage!) : null,
                    child: _avatarImage == null || !_avatarImage!.existsSync()
                        ? const Icon(LucideIcons.user, size: 50, color: Colors.grey)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0EA5E9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.camera, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.bellRing, color: Colors.orange, size: 22),
              ),
              title: const Text('Alarm Setup', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Permissions check aur fix karo'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AlarmSetupScreen(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _alarmStyleFullscreen ? LucideIcons.smartphone : LucideIcons.bell,
                    color: const Color(0xFF0EA5E9),
                    size: 22,
                  ),
                ),
                title: const Text('Alarm Style', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  _alarmStyleFullscreen
                      ? 'Full screen alarm over lock screen'
                      : 'Notification only (silent)',
                  style: const TextStyle(fontSize: 12),
                ),
                value: _alarmStyleFullscreen,
                activeColor: const Color(0xFF0EA5E9),
                onChanged: (val) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('alarm_style_fullscreen', val);
                  setState(() => _alarmStyleFullscreen = val);
                },
              ),
            ),
            const SizedBox(height: 20),
            _buildScheduleTimesSection(),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: const Icon(LucideIcons.user, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Age',
                prefixIcon: const Icon(LucideIcons.calendar, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: '+91 9876543210',
                prefixIcon: const Icon(LucideIcons.phone, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              value: _selectedBloodGroup,
              items: _bloodGroups.map((group) {
                return DropdownMenuItem(value: group, child: Text(group));
              }).toList(),
              onChanged: (val) => setState(() => _selectedBloodGroup = val),
              decoration: InputDecoration(
                labelText: 'Blood Group',
                prefixIcon: const Icon(LucideIcons.droplets, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isSaving 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('Save Changes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (Route<dynamic> route) => false,
                  );
                }
              },
              child: const Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 20),
            _buildPermissionGuide(),
          ],
        ),
      ),
    );
  }

  // ── Medicine Schedule Times ──

  Widget _buildScheduleTimesSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(LucideIcons.clock, color: Color(0xFF10B981), size: 22),
            ),
            title: const Text('Medicine Schedule Times', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Set your preferred time ranges for each slot'),
          ),
          if (_slotPrefsLoaded) ...[
            _buildSlotTile('morning', 'Morning', LucideIcons.sunrise, const Color(0xFFF59E0B)),
            _buildSlotTile('afternoon', 'Afternoon', LucideIcons.sun, const Color(0xFFF97316)),
            _buildSlotTile('evening', 'Evening', LucideIcons.sunset, const Color(0xFF8B5CF6)),
            _buildSlotTile('night', 'Night', LucideIcons.moon, const Color(0xFF3B82F6)),
          ] else
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildSlotTile(String slot, String label, IconData icon, Color color) {
    final startKey = '${slot}_start';
    final endKey = '${slot}_end';
    final startTime = _slotPrefs[startKey] ?? '08:00';
    final endTime = _slotPrefs[endKey] ?? '09:30';

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(icon, color: color, size: 20),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(
          '${_formatTime(startTime)} — ${_formatTime(endTime)}',
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildTimePickerButton(
                    label: 'Start',
                    time: startTime,
                    color: color,
                    onPicked: (picked) {
                      setState(() => _slotPrefs[startKey] = picked);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimePickerButton(
                    label: 'End',
                    time: endTime,
                    color: color,
                    onPicked: (picked) {
                      setState(() => _slotPrefs[endKey] = picked);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => _saveSlotPrefs(),
                  icon: const Icon(LucideIcons.check, color: Color(0xFF10B981)),
                  tooltip: 'Save',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePickerButton({
    required String label,
    required String time,
    required Color color,
    required Function(String) onPicked,
  }) {
    return OutlinedButton.icon(
      onPressed: () async {
        final parsed = _parseTime(time);
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: parsed[0], minute: parsed[1]),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
              child: child!,
            );
          },
        );
        if (picked != null) {
          final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
          onPicked(formatted);
        }
      },
      icon: Icon(LucideIcons.clock, size: 16, color: color),
      label: Text(
        _formatTime(time),
        style: const TextStyle(fontSize: 14),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _saveSlotPrefs() async {
    try {
      await _slotService.savePreferences(_slotPrefs);
      if (mounted) AppSnackBar.showSuccess(context, 'Schedule times saved!');
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, 'Error saving: $e');
    }
  }

  String _formatTime(String time24) {
    final parts = time24.split(':');
    if (parts.length != 2) return time24;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour12:${m.toString().padLeft(2, '0')} $period';
  }

  List<int> _parseTime(String time24) {
    final parts = time24.split(':');
    return [int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0];
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF0EA5E9)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(LucideIcons.chevronRight, size: 20),
        onTap: onTap,
      ),
    );
  }

  Widget _buildPermissionGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(LucideIcons.bellRing, color: Color(0xFF0EA5E9), size: 24),
            SizedBox(width: 12),
            Text(
              'Troubleshooting Alarms',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'To ensure your medication alarms ring reliably even when your phone is locked or the app is closed, please enable the following settings:',
          style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
        ),
        const SizedBox(height: 20),
        _buildGuideItem(
          icon: LucideIcons.battery,
          title: 'Disable Battery Optimization',
          description: 'Go to Settings > Apps > FamCare > Battery and set it to "Unrestricted".',
        ),
        _buildGuideItem(
          icon: LucideIcons.layers,
          title: 'Allow "Display over other apps"',
          description: 'Required for the full-screen alarm to appear when your phone is locked.',
        ),
        _buildGuideItem(
          icon: LucideIcons.zap,
          title: 'Enable "Auto-start"',
          description: 'Common on Xiaomi/Oppo/Vivo. Ensures the app can start in the background.',
        ),
      ],
    );
  }

  Widget _buildGuideItem({required IconData icon, required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF0EA5E9), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 4),
                Text(description, style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
