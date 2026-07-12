import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../providers/family/family_group_provider.dart';

class FamilySetupScreen extends ConsumerStatefulWidget {
  final VoidCallback onSetupComplete;
  const FamilySetupScreen({super.key, required this.onSetupComplete});

  @override
  ConsumerState<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends ConsumerState<FamilySetupScreen> {
  final _groupNameController = TextEditingController();
  final _joinCodeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _createGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(familyServiceProvider).createGroup(name);
      if (mounted) {
        widget.onSetupComplete();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinGroup() async {
    final code = _joinCodeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(familyServiceProvider).joinGroup(code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent! Waiting for admin approval.')));
        widget.onSetupComplete();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid code or error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Family Setup'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(LucideIcons.users, size: 64, color: Color(0xFF0EA5E9)),
                  const SizedBox(height: 24),
                  const Text(
                    'Welcome to Family Hub',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Collaborate with your family, assign tasks, and track health together.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 48),
                  
                  // Create Group Card
                  Card(
                    elevation: 0,
                    color: Colors.blue[50],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.blue[200]!)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Create a New Group', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9))),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _groupNameController,
                            decoration: InputDecoration(
                              labelText: 'Family Group Name',
                              hintText: 'e.g. The Smiths',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _createGroup,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              child: const Text('Create Group'),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  const Center(child: Text('OR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 24),

                  // Join Group Card
                  Card(
                    elevation: 0,
                    color: Colors.orange[50],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.orange[200]!)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Join Existing Group', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange[800])),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _joinCodeController,
                            decoration: InputDecoration(
                              labelText: 'Invite Code',
                              hintText: 'Paste the UUID here',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _joinGroup,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[600], foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              child: const Text('Join Group'),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
