import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/alarm_service.dart';

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
    _alarmService.init();
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
  // ➕ MANUAL ADD POPUP
  // ==========================================
  void _showAddManualDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController doseController = TextEditingController();
    TimeOfDay? selectedTime;
    File? selectedImage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text("Add Medicine", style: TextStyle(fontWeight: FontWeight.bold)),
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error picking image: $e"))
                            );
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
                      final time = await showTimePicker(context: dialogContext, initialTime: TimeOfDay.now());
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
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name and Time are required!")));
                    return;
                  }

                  // 2. Keyboard ko hide karo (CRASH FIX)
                  FocusScope.of(context).unfocus();

                  // 3. Values save karo
                  final name = nameController.text;
                  final dose = doseController.text;
                  final time = selectedTime!;
                  final image = selectedImage;
                  
                  // 4. DIALOG TURANT CLOSE KARO
                  Navigator.pop(dialogContext);

                  // 5. Loading message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Saving medicine & setting alarm..."),
                      duration: Duration(seconds: 2),
                    )
                  );

                  // 6. Background Processing
                  try {
                    final period = time.period == DayPeriod.am ? "AM" : "PM";
                    final h12 = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
                    final timeStr = "${h12.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')} $period";

                    String? imagePath;
                    if (image != null) {
                      imagePath = await _saveImageLocally(image);
                    }

                    // Backend mein save
                    await _supabase.from('medications').insert({
                      'user_id': _supabase.auth.currentUser!.id,
                      'name': name,
                      'dosage': dose,
                      'time': timeStr,
                      'is_taken': false,
                      'image_path': imagePath,
                    });

                    // Alarm logic
                    final now = DateTime.now();
                    DateTime alarmTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);
                    
                    if (alarmTime.isBefore(now.add(const Duration(minutes: 1)))) {
                      alarmTime = alarmTime.add(const Duration(days: 1));
                    }

                    try {
                      await _alarmService.scheduleAlarm(
                        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                        title: "Time for $name",
                        body: "Dosage: $dose",
                        time: alarmTime,
                      );
                    } catch (alarmErr) {
                      debugPrint("Alarm schedule error (ignored): $alarmErr");
                    }

                    // UI refresh aur Green SnackBar
                    if (mounted) {
                      _fetchMedications();
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Medicine added successfully!"), 
                          backgroundColor: Colors.green
                        )
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
                      );
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

                    return Opacity(
                      opacity: isTaken ? 0.7 : 1.0,
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
                    );
                  },
                ),
      // ✅ FLOATING ACTION BUTTON
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddManualDialog,
        backgroundColor: const Color(0xFF0EA5E9),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Med", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}