import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'history_service.dart';
import 'services/ocr_service.dart';

class PrescriptionScreen extends StatefulWidget {
  const PrescriptionScreen({super.key});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  final _supabase = Supabase.instance.client;
  final _ocrService = OCRService();
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isScanningOCR = false;
  List<dynamic> _prescriptions = [];
  List<Map<String, String>> _scannedMeds = [];
  String _lastScannedText = '';
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
        title: Text('Prescription Details', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Future<void> _scanPrescriptionOCR(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source, imageQuality: 70);
    if (image == null) return;

    setState(() {
      _isScanningOCR = true;
      _scannedMeds = [];
      _lastScannedText = '';
    });

    try {
      final extractedText = await _ocrService.extractText(File(image.path));
      _lastScannedText = extractedText;
      _scannedMeds = _parseMedicinesFromText(extractedText);

      if (_scannedMeds.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No medicines found. Try a clearer image.'))
          );
        }
      } else {
        _showScannedMedsDialog();
      }
    } catch (e) {
      debugPrint('OCR Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR failed: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) setState(() => _isScanningOCR = false);
    }
  }

  List<Map<String, String>> _parseMedicinesFromText(String text) {
    final List<Map<String, String>> meds = [];
    final lines = text.split('\n');

    final timePatterns = [
      RegExp(r'(\d{1,2}):(\d{2})\s*(AM|PM|am|pm)'),
      RegExp(r'morning|afternoon|evening|night|bedtime', caseSensitive: false),
    ];

    final medicinePatterns = [
      RegExp(r'^([A-Za-z]+(?:\s+[A-Za-z]+){0,3})\s*[-–]?\s*(\d+)', caseSensitive: false),
      RegExp(r'^([A-Za-z]+(?:\s+[A-Za-z]+){0,3})\s*\d+', caseSensitive: false),
    ];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      String? medName;
      String? dosage;
      String? time;

      for (var pattern in timePatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          if (match.groupCount >= 3 && match.group(1) != null) {
            int hour = int.parse(match.group(1)!);
            final minute = match.group(2)!;
            var period = match.group(3)!.toUpperCase();
            if (period == 'PM' && hour != 12) hour += 12;
            if (period == 'AM' && hour == 12) hour = 0;
            final h12 = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
            time = '${h12.toString().padLeft(2, '0')}:$minute ${period == 'PM' ? 'PM' : 'AM'}';
          } else {
            time = match.group(0)!.toLowerCase().contains('morning') ? '08:00 AM' :
                   match.group(0)!.toLowerCase().contains('afternoon') ? '02:00 PM' :
                   match.group(0)!.toLowerCase().contains('evening') ? '06:00 PM' :
                   match.group(0)!.toLowerCase().contains('night') || match.group(0)!.toLowerCase().contains('bedtime') ? '10:00 PM' : '08:00 AM';
          }
          break;
        }
      }

      for (var pattern in medicinePatterns) {
        final match = pattern.firstMatch(line);
        if (match != null) {
          medName = match.group(1)?.trim() ?? '';
          if (match.groupCount >= 2 && match.group(2) != null) {
            dosage = '${match.group(2)} tablet(s)';
          }
          break;
        }
      }

      if (medName != null && medName.length > 2 && !medName.toLowerCase().contains('doctor') && !medName.toLowerCase().contains('patient')) {
        meds.add({
          'name': medName,
          'dosage': dosage ?? '1 tablet',
          'time': time ?? '08:00 AM',
        });
      }
    }

    if (meds.isEmpty && text.isNotEmpty) {
      meds.add({'name': 'Review Prescription', 'dosage': 'See details', 'time': 'Manual Entry'});
    }

    return meds;
  }

  void _showScannedMedsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(children: [
          const Icon(LucideIcons.scan, color: Color(0xFF0EA5E9)),
          const SizedBox(width: 10),
          Text('Scanned Medicines', style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_lastScannedText.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                  child: Text(_lastScannedText.length > 200 ? '${_lastScannedText.substring(0, 200)}...' : _lastScannedText, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ),
                const SizedBox(height: 10),
              ],
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 12,
                  columns: const [
                    DataColumn(label: Text('Medicine', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Dosage', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Time', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Alarm', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _scannedMeds.map((med) {
                    return DataRow(cells: [
                      DataCell(Text(med['name'] ?? '', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(med['dosage'] ?? '', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(med['time'] ?? '', style: const TextStyle(fontSize: 12))),
                      DataCell(med['time'] != 'Manual Entry' ? IconButton(
                        icon: const Icon(LucideIcons.bell, size: 18, color: Color(0xFF0EA5E9)),
                        onPressed: () => _saveMedicationFromOCR(med),
                        tooltip: 'Set Alarm',
                      ) : const SizedBox()),
                    ]);
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
            icon: const Icon(Icons.add, color: Colors.white, size: 18),
            label: const Text('Add All to Meds', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(context);
              for (var med in _scannedMeds) {
                if (med['time'] != 'Manual Entry') _saveMedicationFromOCR(med);
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${_scannedMeds.length} medicines added to schedule!'))
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveMedicationFromOCR(Map<String, String> med) async {
    try {
      await _supabase.from('medications').insert({
        'user_id': _supabase.auth.currentUser!.id,
        'name': med['name'],
        'dosage': med['dosage'],
        'time': med['time'],
        'is_taken': false,
      });
      await HistoryService.logAction(actionType: 'MED', description: 'Added ${med["name"]} from prescription scan');
    } catch (e) {
      debugPrint('Save med error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Medical Vault', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true, backgroundColor: Colors.white, elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              _prescriptions.isEmpty ? _buildEmptyState() : _buildList(),
              if (_isUploading || _isScanningOCR)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _isScanningOCR 
                              ? const Column(children: [Icon(LucideIcons.scan, size: 40, color: Color(0xFF0EA5E9)), SizedBox(height: 16), Text("Scanning prescription..."), SizedBox(height: 8), Text("Extracting medicine details", style: TextStyle(fontSize: 12, color: Colors.grey))])
                              : const Column(children: [CircularProgressIndicator(), SizedBox(height: 16), Text("Uploading securely...")]),
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
                  const Divider(),
                  ListTile(
                    leading: const Icon(LucideIcons.scan, color: Colors.orange),
                    title: const Text('📸 Scan Prescription (OCR)'),
                    subtitle: const Text('Extract medicines & set alarms automatically'),
                    onTap: () { Navigator.pop(context); _scanPrescriptionOCR(ImageSource.camera); },
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.scanLine, color: Colors.purple),
                    title: const Text('📱 Scan from Gallery'),
                    subtitle: const Text('Choose image to scan'),
                    onTap: () { Navigator.pop(context); _scanPrescriptionOCR(ImageSource.gallery); },
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
       Text('Vault is Empty', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
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