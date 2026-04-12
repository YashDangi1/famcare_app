import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentName();
  }

  // Pehle se jo naam hai use load karo
  Future<void> _loadCurrentName() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final data = await Supabase.instance.client.from('profiles').select('full_name').eq('id', userId).maybeSingle();
    if (data != null) {
      _nameController.text = data['full_name'] ?? '';
    }
  }

  // Naam badalne ka logic (Ab ye App se hi hoga!)
  Future<void> _updateProfile() async {
    setState(() => _isSaving = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('profiles').upsert({
        'id': userId,
        'full_name': _nameController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Updated!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Settings')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _updateProfile,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Changes', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}