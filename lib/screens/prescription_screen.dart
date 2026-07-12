import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
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
                title: Text(selectedTime == null ? "Select Alarm Time" : "Time: ${selectedTime!.format(dialogContext)}"),
                leading: const Icon(Icons.access_time),
                onTap: () async {
                  final time = await showTimePicker(context: dialogContext, initialTime: TimeOfDay.now());
                  if (time != null) setDialogState(() => selectedTime = time);
                },
                tileColor: Colors.blue.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || selectedTime == null) {
                  AppSnackBar.showError(dialogContext, "Please enter name and time");
                  return;
                }

                final now = DateTime.now();
                var alarmTime = DateTime(now.year, now.month, now.day, selectedTime!.hour, selectedTime!.minute);
                
                // If the time has already passed today OR is within the next 2 minutes, schedule for tomorrow
                if (alarmTime.isBefore(now.add(const Duration(minutes: 2)))) {
                  alarmTime = alarmTime.add(const Duration(days: 1));
                }

                final h12 = selectedTime!.hour == 0 ? 12 : (selectedTime!.hour > 12 ? selectedTime!.hour - 12 : selectedTime!.hour);
                final period = selectedTime!.period == DayPeriod.am ? "AM" : "PM";
                final timeStr = "${h12.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')} $period";

                // Create Model
                final newMed = Medicine(
                  name: nameController.text,
                  dosage: doseController.text,
                  frequency: 1,
                  time1: timeStr,
                  startDate: DateTime.now(),
                  durationDays: 7,
                  qty: 10,
                  counter: 0,
                  slotTypes: const ['custom'],
                  customTimes: [timeStr],
                );

                final inserted = await dbService.insertMedicinesReturning([
                  newMed.toJson(),
                ]);
                if (inserted.isEmpty) {
                  if (!dialogContext.mounted) return;
                  AppSnackBar.showError(
                    dialogContext,
                    "Medicine save failed. Alarm not scheduled.",
                  );
                  return;
                }

                final persistedMed = Medicine.fromJson(inserted.first);

                // Set Local Alarm only after a real medication ID exists.
                await alarmService.scheduleAlarm(
                  id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                  medicationId: persistedMed.id!,
                  medicineName: persistedMed.name,
                  dosage: persistedMed.getCurrentDosage(DateTime.now()),
                  qty: persistedMed.qty,
                  imagePath: persistedMed.imagePath,
                  time: alarmTime,
                  slotIndex: 5,
                  // C2: Fixed slotKey format to match the expected 'custom_{medId}_{i}' pattern.
                  // Old 'custom_0' caused retry alarms to never schedule, orphaned alarms to persist,
                  // and slot-end missed marking to silently fail.
                  slotKey: 'custom_${persistedMed.id}_0',
                );

                setState(() => medicines.add(persistedMed));
                if (!dialogContext.mounted) return;

                Navigator.pop(dialogContext);
                AppSnackBar.showSuccess(dialogContext, "Medicine & Alarm added successfully!");
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
      if (!mounted) return;
      setState(() { medicines = parsed; loading = false; });

      dbService.insertMedicines(medicines.map((m) => m.toJson()).toList())
          .catchError((e) => debugPrint("Background DB Error: $e"));

      AppSnackBar.showSuccess(context, "Scan Complete! Please review and set alarms.");
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      AppSnackBar.showError(context, "Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Medical Records", style: TextStyle(fontWeight: FontWeight.bold)),
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
          Expanded(
            child: loading 
                ? _buildSkeletonLoader()
                : medicines.isEmpty
                    ? _buildEmptyState()
                    : _buildMedicinesList(),
          ),
        ],
      ),
      // ✅ FLOATING ACTION BUTTON FOR MANUAL ADD
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddManualDialog,
        backgroundColor: const Color(0xFF0EA5E9),
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: const Text("Add Manually", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ).animate().scale(delay: 500.ms, curve: Curves.easeOutBack),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.fileScan, size: 80, color: Color(0xFF0EA5E9)),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scaleXY(end: 1.05, duration: 2.seconds),
          const SizedBox(height: 24),
          Text("No records yet", style: TextStyle(color: Colors.grey[800], fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text("Scan a prescription or add manually below.", style: TextStyle(color: Colors.grey[500], fontSize: 14)),
        ],
      ).animate().fade(duration: 500.ms).slideY(begin: 0.2),
    );
  }

  Widget _buildSkeletonLoader() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          height: 80,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(15),
          ),
        )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .fade(begin: 0.5, end: 1.0, duration: 1.seconds);
      },
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
            subtitle: Text("Dose: ${med.getCurrentDosage(DateTime.now())}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_active, color: med.time1 != null ? Colors.green : Colors.grey[300]),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(i),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Prescription?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Are you sure you want to delete this prescription? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                medicines.removeAt(index);
              });
              Navigator.pop(context);
              AppSnackBar.showSuccess(context, "Prescription deleted!");
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
