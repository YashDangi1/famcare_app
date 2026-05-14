import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Services and Models imports
import '../models/medicine_model.dart';
import '../services/ocr_service.dart';
import '../services/prescription_service.dart';
import '../services/alarm_service.dart';
import '../services/database_service.dart';
import '../utils/snackbar_utils.dart';

class PrescriptionScreen extends StatefulWidget {
  const PrescriptionScreen({super.key});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  File? image;
  bool loading = false;
  List<Medicine> medicines = [];

  final picker = ImagePicker();
  final ocrService = OCRService();
  final service = PrescriptionService();
  final alarmService = AlarmService();
  final dbService = DatabaseService();

  @override
  void initState() {
    super.initState();
  }

  // ==========================================
  // MANUAL ADD MEDICINE
  // ==========================================
  void _showAddManualDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController doseController = TextEditingController();
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Add New Medicine", style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Medicine Name", prefixIcon: Icon(Icons.medication)),
              ),
              TextField(
                controller: doseController,
                decoration: const InputDecoration(labelText: "Dosage (e.g. 1 pill)", prefixIcon: Icon(Icons.scale)),
              ),
              const SizedBox(height: 20),
              ListTile(
                title: Text(selectedTime == null ? "Select Alarm Time" : "Time: ${selectedTime!.format(context)}"),
                leading: const Icon(Icons.access_time),
                onTap: () async {
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                  if (time != null) setDialogState(() => selectedTime = time);
                },
                tileColor: Colors.blue.withOpacity(0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || selectedTime == null) {
                  AppSnackBar.showError(context, "Please enter name and time");
                  return;
                }

                final now = DateTime.now();
                final alarmTime = DateTime(now.year, now.month, now.day, selectedTime!.hour, selectedTime!.minute);

                // Create Model
                final newMed = Medicine(
                  name: nameController.text,
                  dose: doseController.text,
                  morning: 1, afternoon: 0, night: 0, instructions: "",
                  morningTime: alarmTime,
                );

                setState(() => medicines.add(newMed));

                // Set Local Alarm
                await alarmService.scheduleAlarm(
                  id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  title: newMed.name,
                  body: "Time for your ${newMed.dose} dose!",
                  time: alarmTime,
                );

                // Save to Supabase in Background
                dbService.insertMedicines([newMed.toJson()]).catchError((e) => debugPrint("DB Error: $e"));

                Navigator.pop(context);
                AppSnackBar.showSuccess(context, "Medicine & Alarm added successfully!");
              },
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // 🚀 AI SCAN LOGIC (Existing Feature)
  // ==========================================
  Future<void> scanPrescription() async {
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked == null) return;

    setState(() {
      image = File(picked.path);
      loading = true;
    });

    try {
      final text = await ocrService.extractText(image!);
      final parsed = await service.parseWithAI(text);
      setState(() { medicines = parsed; loading = false; });

      dbService.insertMedicines(medicines.map((m) => m.toJson()).toList())
          .catchError((e) => debugPrint("Background DB Error: $e"));

      AppSnackBar.showSuccess(context, "Scan Complete! Please review and set alarms.");
    } catch (e) {
      setState(() => loading = false);
      AppSnackBar.showError(context, "Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Medical Vault", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => setState(() => medicines = []))
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: loading ? null : scanPrescription,
              icon: const Icon(Icons.camera_alt),
              label: Text(loading ? "Processing AI..." : "Scan Prescription with AI"),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
            ),
          ),
          if (loading) const LinearProgressIndicator(color: Color(0xFF0EA5E9)),
          const Divider(),
          Expanded(
            child: medicines.isEmpty
                ? _buildEmptyState()
                : _buildMedicinesList(),
          ),
        ],
      ),
      // ✅ FLOATING ACTION BUTTON FOR MANUAL ADD
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddManualDialog,
        backgroundColor: const Color(0xFF0EA5E9),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Manually", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.medication_liquid_sharp, size: 80, color: Colors.grey[200]),
          const SizedBox(height: 10),
          Text("No records yet.", style: TextStyle(color: Colors.grey[400])),
          Text("Scan a prescription or add manually below.", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMedicinesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: medicines.length,
      itemBuilder: (_, i) {
        final med = medicines[i];
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.grey[100]!)),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.medication, color: Color(0xFF0EA5E9)),
            title: Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Dose: ${med.dose}"),
            trailing: IconButton(
              icon: Icon(Icons.notifications_active, color: med.morningTime != null ? Colors.green : Colors.grey[300]),
              onPressed: () {}, // Detail view or edit can go here
            ),
          ),
        );
      },
    );
  }
}