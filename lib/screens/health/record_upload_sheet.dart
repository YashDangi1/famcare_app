import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../models/health/health_record.dart';
import '../../providers/health/records_provider.dart';
import '../../utils/snackbar_utils.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RecordUploadSheet extends ConsumerStatefulWidget {
  final String? targetUserId;
  final String? currentCategoryFilter;

  const RecordUploadSheet({super.key, this.targetUserId, this.currentCategoryFilter});

  @override
  ConsumerState<RecordUploadSheet> createState() => _RecordUploadSheetState();
}

class _RecordUploadSheetState extends ConsumerState<RecordUploadSheet> {
  final _titleController = TextEditingController();
  final _providerController = TextEditingController();
  
  File? _pickedImage;
  String _selectedCategory = 'prescription';
  DateTime _recordDate = DateTime.now();
  bool _isSaving = false;

  final List<String> _categories = [
    'Prescription', 'Lab Report', 'Imaging', 'Discharge Summary', 'Doctor Note', 'Vaccine', 'Other'
  ];

  List<Map<String, dynamic>> _appointments = [];
  String? _selectedAppointmentId;

  @override
  void initState() {
    super.initState();
    _fetchAppointments();
  }

  Future<void> _fetchAppointments() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = widget.targetUserId ?? supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      final response = await supabase
          .from('appointments')
          .select('id, doctor_name, appointment_date')
          .eq('user_id', userId)
          .order('appointment_date', ascending: false)
          .limit(20);
          
      if (mounted) {
        setState(() {
          _appointments = List<Map<String, dynamic>>.from(response as List);
        });
      }
    } catch (e) {
      debugPrint('Error fetching appointments for linking: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _providerController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      setState(() => _pickedImage = File(image.path));
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _recordDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) {
      setState(() => _recordDate = date);
    }
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty || _pickedImage == null) {
      AppSnackBar.showError(context, 'Please provide a title and select a document/image');
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      final record = HealthRecord(
        userId: widget.targetUserId ?? '', // Service uses current user if not provided
        category: _selectedCategory,
        title: _titleController.text.trim(),
        fileUrl: '', // Will be set by service after upload
        providerName: _providerController.text.trim().isEmpty ? null : _providerController.text.trim(),
        recordDate: _recordDate,
        linkedAppointmentId: _selectedAppointmentId,
      );

      await ref.read(recordsProvider.notifier).uploadRecord(
        record, 
        _pickedImage!,
        targetUserId: widget.targetUserId,
        currentCategory: widget.currentCategoryFilter,
      );

      if (mounted) {
        Navigator.pop(context, true);
        AppSnackBar.showSuccess(context, 'Record uploaded successfully');
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, 'Failed to upload: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Upload Record', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                IconButton(
                  icon: const Icon(LucideIcons.x, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Image Picker Area
            GestureDetector(
              onTap: () async {
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
                  await _pickImage(source);
                }
              },
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!, width: 2, style: BorderStyle.solid),
                ),
                child: _pickedImage == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.uploadCloud, size: 40, color: Colors.blue[300]),
                          const SizedBox(height: 8),
                          Text('Tap to scan or upload document', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.file(_pickedImage!, width: double.infinity, height: double.infinity, fit: BoxFit.cover),
                            Container(color: Colors.black38),
                            const Icon(LucideIcons.refreshCw, color: Colors.white, size: 32),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Document Title *',
                hintText: 'e.g. Blood Test Results',
                prefixIcon: const Icon(LucideIcons.fileText, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: InputDecoration(
                labelText: 'Category *',
                prefixIcon: const Icon(LucideIcons.tag, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              items: _categories.map((c) {
                return DropdownMenuItem(
                  value: c.toLowerCase().replaceAll(' ', '_'),
                  child: Text(c),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedCategory = val);
              },
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  flex: 5,
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Record Date',
                        prefixIcon: const Icon(LucideIcons.calendar, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        DateFormat('dd MMM yyyy').format(_recordDate),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 6,
                  child: TextField(
                    controller: _providerController,
                    decoration: InputDecoration(
                      labelText: 'Provider (Optional)',
                      prefixIcon: const Icon(LucideIcons.user, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_appointments.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                value: _selectedAppointmentId,
                decoration: InputDecoration(
                  labelText: 'Link to Appointment (Optional)',
                  prefixIcon: const Icon(LucideIcons.link, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                hint: const Text('Select an appointment'),
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('None'),
                  ),
                  ..._appointments.map((a) {
                    final dateStr = a['appointment_date'] != null 
                        ? DateFormat('dd MMM yyyy').format(DateTime.parse(a['appointment_date']).toLocal())
                        : '';
                    return DropdownMenuItem<String>(
                      value: a['id'].toString(),
                      child: Text('${a['doctor_name']} - $dateStr'),
                    );
                  }),
                ],
                onChanged: (val) {
                  setState(() => _selectedAppointmentId = val);
                },
              ),
              const SizedBox(height: 24),
            ],

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Upload Document', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
