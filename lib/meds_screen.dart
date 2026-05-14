import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/alarm_service.dart';
import 'utils/snackbar_utils.dart';

class MedsScreen extends StatefulWidget {
  const MedsScreen({super.key});

  @override
  State<MedsScreen> createState() => _MedsScreenState();
}

class _MedsScreenState extends State<MedsScreen> {
  final _supabase = Supabase.instance.client;
  final _alarmService = AlarmService();
  final _imagePicker = ImagePicker();
  List<dynamic> _medications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMedications();
  }

  Future<void> _fetchMedications() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final data = await _supabase
          .from('medications')
          .select('*')
          .eq('user_id', userId!)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _medications = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // ➕ MANUAL ADD/EDIT POPUP
  // ==========================================
  void _showAddManualDialog({Map<String, dynamic>? existingMed}) {
    TextEditingController nameController = TextEditingController(text: existingMed?['name']);
    TextEditingController doseController = TextEditingController(text: existingMed?['dosage']);
    TimeOfDay? selectedTime;
    File? selectedImage;

    if (existingMed != null && existingMed['time'] != null) {
      try {
        final timeStr = existingMed['time'] as String;
        final parts = timeStr.split(' ');
        final timeParts = parts[0].split(':');
        int hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final isPm = parts[1] == 'PM';
        
        if (isPm && hour < 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
        
        selectedTime = TimeOfDay(hour: hour, minute: minute);
      } catch (e) {
        debugPrint("Error parsing time: $e");
      }
    }
    
    if (existingMed != null && existingMed['image_path'] != null) {
      final path = existingMed['image_path'] as String;
      if (path.isNotEmpty && File(path).existsSync()) {
        selectedImage = File(path);
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: Text(existingMed == null ? "Add Medicine" : "Edit Medicine", style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              // Fix: Give the dialog a finite width to prevent IntrinsicWidth crashes
              width: MediaQuery.of(context).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        try {
                          final ImageSource? source = await showModalBottomSheet<ImageSource>(
                            context: dialogContext,
                            builder: (bottomSheetContext) => SafeArea(
                              child: Wrap(
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.camera_alt),
                                    title: const Text('Take Photo'),
                                    onTap: () => Navigator.pop(bottomSheetContext, ImageSource.camera),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.photo_library),
                                    title: const Text('Choose from Gallery'),
                                    onTap: () => Navigator.pop(bottomSheetContext, ImageSource.gallery),
                                  ),
                                ],
                              ),
                            ),
                          );

                          if (source != null && mounted && dialogContext.mounted) {
                            final XFile? image = await _imagePicker.pickImage(
                              source: source,
                              imageQuality: 50,
                              maxWidth: 800,
                            );
                            
                            if (image != null && mounted && dialogContext.mounted) {
                              setDialogState(() => selectedImage = File(image.path));
                            }
                          }
                        } catch (e) {
                          debugPrint("Image picking error: $e");
                          if (mounted && context.mounted) {
                            AppSnackBar.showError(context, "Error picking image: $e");
                          }
                        }
                      },
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedImage == null ? (Colors.grey[300] ?? Colors.grey) : Colors.transparent,
                            style: selectedImage == null ? BorderStyle.solid : BorderStyle.none,
                          ),
                        ),
                        child: selectedImage == null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt_outlined, size: 36, color: Colors.grey[400]),
                                  const SizedBox(height: 8),
                                  Text("Add Medicine Photo (Optional)", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  selectedImage!, 
                                  key: UniqueKey(), // CRASH FIX: Force fresh render object
                                  height: 120, 
                                  width: double.infinity, 
                                  fit: BoxFit.cover
                                ),
                              ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Medicine Name", prefixIcon: Icon(Icons.medication)),
                  ),
                  TextField(
                    controller: doseController,
                    decoration: const InputDecoration(labelText: "Dosage (e.g., 1 pill)", prefixIcon: Icon(Icons.scale)),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(selectedTime == null ? "Set Alarm Time" : "Alarm: ${selectedTime!.format(dialogContext)}"),
                    leading: const Icon(Icons.alarm, color: Color(0xFF0EA5E9)),
                    onTap: () async {
                      final time = await showTimePicker(context: dialogContext, initialTime: selectedTime ?? TimeOfDay.now());
                      if (time != null) setDialogState(() => selectedTime = time);
                    },
                    tileColor: Colors.blue.withOpacity(0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white),
                onPressed: () async {
                  // 1. Validation check
                  if (nameController.text.isEmpty || selectedTime == null) {
                    AppSnackBar.showError(context, "Name and Time are required!");
                    return;
                  }

                  // 2. Hide keyboard (CRASH FIX)
                  FocusScope.of(context).unfocus();

                  // 3. Save values
                  final name = nameController.text;
                  final dose = doseController.text;
                  final time = selectedTime!;
                  final image = selectedImage;
                  
                  // 4. CLOSE DIALOG IMMEDIATELY
                  Navigator.pop(dialogContext);

                  // 5. Loading message
                  AppSnackBar.showInfo(context, existingMed == null ? "Saving medicine & setting alarm..." : "Updating medicine...");

                  // 6. Background Processing
                  try {
                    final period = time.period == DayPeriod.am ? "AM" : "PM";
                    final h12 = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
                    final timeStr = "${h12.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period";

                    String? imagePath;
                    if (image != null) {
                      imagePath = await _saveImageLocally(image);
                    }

                    if (existingMed == null) {
                      // Save to backend
                      await _supabase.from('medications').insert({
                        'user_id': _supabase.auth.currentUser!.id,
                        'name': name,
                        'dosage': dose,
                        'time': timeStr,
                        'is_taken': false,
                        'image_path': imagePath,
                      });
                    } else {
                      // Update backend
                      await _supabase.from('medications').update({
                        'name': name,
                        'dosage': dose,
                        'time': timeStr,
                        'image_path': imagePath ?? existingMed['image_path'],
                      }).eq('id', existingMed['id']);
                    }

                    // Alarm logic
                    final now = DateTime.now();
                    DateTime alarmTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
                    
                    if (alarmTime.isBefore(now)) {
                      alarmTime = alarmTime.add(const Duration(days: 1));
                    }

                    try {
                      // Cancel old alarm if editing
                      if (existingMed != null && existingMed['alarm_id'] != null) {
                        await _alarmService.cancelAlarm(existingMed['alarm_id']);
                      }

                      final alarmId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                      await _alarmService.scheduleAlarm(
                        id: alarmId,
                        title: "Time for $name",
                        body: "Dosage: $dose",
                        time: alarmTime,
                      );

                      // Update the medication with the new alarm_id
                      if (existingMed != null) {
                        await _supabase.from('medications').update({'alarm_id': alarmId}).eq('id', existingMed['id']);
                      } else {
                        // For new med, we need the ID from the insert, but insert doesn't return data by default in some versions.
                        // For simplicity, we assume the latest inserted med for the user.
                        final latestMed = await _supabase.from('medications').select('id').eq('user_id', _supabase.auth.currentUser!.id).order('created_at', ascending: false).limit(1).single();
                        await _supabase.from('medications').update({'alarm_id': alarmId}).eq('id', latestMed['id']);
                      }
                    } catch (alarmErr) {
                      debugPrint("Alarm schedule error (ignored): $alarmErr");
                    }

                    // UI refresh and success snackbar
                    if (mounted) {
                      _fetchMedications();
                      AppSnackBar.showSuccess(context, existingMed == null ? "Medicine added successfully!" : "Medicine updated successfully!");
                    }
                  } catch (e) {
                    if (mounted) {
                      AppSnackBar.showError(context, "Error: $e");
                    }
                  }
                },
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteMedication(Map<String, dynamic> med) async {
    try {
      final id = med['id'];
      final alarmId = med['alarm_id'];

      await _supabase.from('medications').delete().eq('id', id);

      if (alarmId != null) {
        await _alarmService.cancelAlarm(alarmId);
      }

      if (mounted) {
        _fetchMedications();
        AppSnackBar.showError(context, "Medicine deleted");
      }
    } catch (e) {
      debugPrint('Delete Error: $e');
      if (mounted) AppSnackBar.showError(context, "Error deleting medicine: $e");
    }
  }

  // --- Toggle status ---
  Future<void> _toggleTaken(String id, bool currentStatus) async {
    try {
      await _supabase.from('medications').update({'is_taken': !currentStatus}).eq('id', id);
      _fetchMedications();
    } catch (e) {
      debugPrint('Toggle Error: $e');
    }
  }

  Future<String?> _saveImageLocally(File imageFile) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'med_$timestamp.jpg';
      final savedPath = '${directory.path}/$fileName';
      await imageFile.copy(savedPath);
      return savedPath;
    } catch (e) {
      debugPrint('Error saving image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Medication Schedule', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _medications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.pill,
                        size: 100,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        "Your schedule is clear",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Tap the + button to add your first medication.",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _medications.length,
                itemBuilder: (context, index) {
                  final med = _medications[index];
                  final isTaken = med['is_taken'] ?? false;

                  return Dismissible(
                    key: Key(med['id']?.toString() ?? index.toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (direction) => _deleteMedication(med),
                    child: Opacity(
                      opacity: isTaken ? 0.7 : 1.0,
                      child: GestureDetector(
                        onLongPress: () => _showAddManualDialog(existingMed: med),
                        child: Card(
                          elevation: 4,
                          shadowColor: Colors.black12,
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isTaken ? Colors.green.withOpacity(0.3) : Colors.grey[100]!,
                              width: 1.5,
                            ),
                          ),
                          color: isTaken ? Colors.green[50] : Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                // Left Side: Prominent Image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(15),
                                  child: Container(
                                    width: 70,
                                    height: 70,
                                    color: const Color(0xFF0EA5E9).withOpacity(0.1),
                                    child: med['image_path'] != null && med['image_path'].toString().isNotEmpty
                                        ? Image.file(
                                            File(med['image_path']),
                                            width: 70,
                                            height: 70,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return const Icon(LucideIcons.pill, color: Color(0xFF0EA5E9), size: 30);
                                            },
                                          )
                                        : const Icon(LucideIcons.pill, color: Color(0xFF0EA5E9), size: 30),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Middle: Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        med['name'] ?? '',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[900],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        med['dosage'] ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Time Chip
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0EA5E9).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          med['time'] ?? '',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0369A1),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Right Side: Action
                                IconButton(
                                  icon: Icon(
                                    isTaken ? LucideIcons.checkCircle2 : LucideIcons.circle,
                                    color: isTaken ? Colors.green : Colors.grey[300],
                                    size: 32,
                                  ),
                                  onPressed: () {
                                    final id = med['id']?.toString();
                                    if (id != null) {
                                      _toggleTaken(id, isTaken);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
      // FLOATING ACTION BUTTON
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddManualDialog,
        backgroundColor: const Color(0xFF0EA5E9),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Med", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}