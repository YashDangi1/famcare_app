import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'history_service.dart';

class PrescriptionScreen extends StatefulWidget {
  const PrescriptionScreen({super.key});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isUploading = false;
  List<dynamic> _prescriptions = [];
  String? _currentGroupId;
  String? _myStatus;

  final _doctorController = TextEditingController();
  final _diagnosisController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPrescriptions();
  }

  @override
  void dispose() {
    _doctorController.dispose();
    _diagnosisController.dispose();
    super.dispose();
  }

  Future<void> _fetchPrescriptions() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      final member = await _supabase.from('family_members').select('group_id, status').eq('user_id', userId!).maybeSingle();
      
      if (member != null) {
        _currentGroupId = member['group_id'];
        _myStatus = member['status'];
      }

      var query = _supabase.from('prescriptions').select('*, profiles(full_name)');
      
      if (_myStatus == 'approved' && _currentGroupId != null) {
        query = query.or('user_id.eq.$userId, group_id.eq.$_currentGroupId');
      } else {
        query = query.eq('user_id', userId);
      }

      final data = await query.order('created_at', ascending: false);
      if (mounted) setState(() => _prescriptions = data);
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 70); // Quality 70 to save data
    
    if (image == null) return;

    _showDetailsDialog(File(image.path));
  }

  void _showDetailsDialog(File imageFile) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Prescription Details', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(imageFile, height: 150, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 16),
              TextField(controller: _doctorController, decoration: const InputDecoration(labelText: 'Doctor Name', prefixIcon: Icon(LucideIcons.user))),
              const SizedBox(height: 10),
              TextField(controller: _diagnosisController, decoration: const InputDecoration(labelText: 'Diagnosis / Reason', prefixIcon: Icon(LucideIcons.stethoscope))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () { _doctorController.clear(); _diagnosisController.clear(); Navigator.pop(context); }, child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _uploadPrescriptionData(imageFile);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  Future<void> _uploadPrescriptionData(File imageFile) async {
    final doctorName = _doctorController.text.trim();
    final diagnosis = _diagnosisController.text.trim();
    if (doctorName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Doctor name is required')));
      return;
    }

    setState(() => _isUploading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 1. Upload Image to Supabase Storage
      await _supabase.storage.from('prescriptions').upload(fileName, imageFile);
      
      // 2. Get Public URL
      final imageUrl = _supabase.storage.from('prescriptions').getPublicUrl(fileName);

      // 3. Save to Database
      await _supabase.from('prescriptions').insert({
        'user_id': userId,
        'group_id': _currentGroupId,
        'doctor_name': doctorName,
        'diagnosis': diagnosis,
        'image_url': imageUrl,
      });

      await HistoryService.logAction(actionType: 'VAULT', description: 'Uploaded a prescription from Dr. $doctorName');

      _doctorController.clear();
      _diagnosisController.clear();
      _fetchPrescriptions();
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prescription Saved!'), backgroundColor: Colors.green));
    } catch (e) {
      debugPrint('Upload Error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Medical Vault', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true, backgroundColor: Colors.white, elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              _prescriptions.isEmpty ? _buildEmptyState() : _buildList(),
              if (_isUploading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text("Uploading securely..."),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (context) => SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(LucideIcons.camera, color: Color(0xFF0EA5E9)),
                    title: const Text('Take a Photo'),
                    onTap: () { Navigator.pop(context); _pickAndUploadImage(ImageSource.camera); },
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.image, color: Color(0xFF0EA5E9)),
                    title: const Text('Choose from Gallery'),
                    onTap: () { Navigator.pop(context); _pickAndUploadImage(ImageSource.gallery); },
                  ),
                ],
              ),
            ),
          );
        },
        label: const Text('Upload', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        icon: const Icon(LucideIcons.uploadCloud, color: Colors.white),
        backgroundColor: const Color(0xFF0EA5E9),
      ),
    );
  }

  Widget _buildEmptyState() {
     return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
       const Icon(LucideIcons.folderOpen, size: 80, color: Colors.grey),
       const SizedBox(height: 16),
       Text('Vault is Empty', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
       const Text('Keep your medical records safe here.', style: TextStyle(color: Colors.grey)),
     ]));
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _prescriptions.length,
      itemBuilder: (context, index) {
        final p = _prescriptions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: CircleAvatar(backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.1), child: const Icon(LucideIcons.fileText, color: Color(0xFF0EA5E9))),
                title: Text("Dr. ${p['doctor_name']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(p['diagnosis'] ?? 'General Checkup'),
                trailing: IconButton(
                  icon: const Icon(LucideIcons.trash2, color: Colors.red, size: 20),
                  onPressed: () async {
                    await _supabase.from('prescriptions').delete().eq('id', p['id']);
                    _fetchPrescriptions();
                  },
                ),
              ),
              if (p['image_url'] != null)
                GestureDetector(
                  onTap: () {
                    // Simple full screen viewer
                    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                      backgroundColor: Colors.black,
                      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
                      body: Center(child: InteractiveViewer(child: Image.network(p['image_url']))),
                    )));
                  },
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
                      image: DecorationImage(image: NetworkImage(p['image_url']), fit: BoxFit.cover),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}