import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:alarm/alarm.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/alarm_service.dart';
import 'models/medicine_model.dart';
import 'screens/alarm_setup_screen.dart';
import 'screens/medicine_log_screen.dart';
import 'utils/snackbar_utils.dart';
import 'services/activity_service.dart';

class MedsScreen extends StatefulWidget {
  const MedsScreen({super.key});

  @override
  State<MedsScreen> createState() => _MedsScreenState();
}

class _MedsScreenState extends State<MedsScreen> {
  final _supabase = Supabase.instance.client;
  final _alarmService = AlarmService();
  final Set<String> _existingImagePaths = {};
  bool _isSaving = false;
  final _imagePicker = ImagePicker();
  List<Medicine> _medications = [];
  bool _isLoading = true;
  String? _expandedMedId;

  @override
  void initState() {
    super.initState();
    _fetchMedications();
  }

  Future<void> _fetchMedications() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print("Fetch Error: No user ID found");
        return;
      }

      print("Fetching medications for user: $userId");
      
      var query = _supabase.from('medications').select('*').eq('user_id', userId);
      
      // Try to order by created_at, but handle cases where the column might be missing
      PostgrestList data;
      try {
        data = await query.order('created_at', ascending: false);
      } catch (e) {
        print("Ordering failed, fetching without order: $e");
        data = await query;
      }

      print("Fetched ${data.length} medications");

      if (mounted) {
        setState(() {
          _medications = (data as List).map((m) => Medicine.fromJson(m)).toList();
          // Cache image existence to avoid sync I/O in build()
          _existingImagePaths.clear();
          for (final m in _medications) {
            if (m.imagePath != null && m.imagePath!.isNotEmpty && File(m.imagePath!).existsSync()) {
              _existingImagePaths.add(m.imagePath!);
            }
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Fetch Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // ➕ ADD/EDIT MEDICINE DIALOG
  // ==========================================
  void _showAddEditDialog({Medicine? existingMed}) {
    final nameController = TextEditingController(text: existingMed?.name);
    final dosageController = TextEditingController(text: existingMed?.dosage ?? "1 tablet");
    final durationController = TextEditingController(text: (existingMed?.durationDays ?? 7).toString());
    final qtyController = TextEditingController(text: (existingMed?.qty ?? 7).toString());
    
    int frequency = existingMed?.frequency ?? 1;
    DateTime startDate = existingMed?.startDate ?? DateTime.now();
    File? selectedImage;
    if (existingMed?.imagePath != null && File(existingMed!.imagePath!).existsSync()) {
      selectedImage = File(existingMed.imagePath!);
    }

    TimeOfDay? t1 = _parseTime(existingMed?.time1) ?? const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay? t2 = _parseTime(existingMed?.time2) ?? const TimeOfDay(hour: 14, minute: 0);
    TimeOfDay? t3 = _parseTime(existingMed?.time3) ?? const TimeOfDay(hour: 21, minute: 0);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final durDays = int.tryParse(durationController.text) ?? 1;
          final endDate = startDate.add(Duration(days: durDays)).subtract(const Duration(days: 1));
          
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            title: Text(existingMed == null ? "Add Medicine" : "Edit Medicine", 
              style: const TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: MediaQuery.of(context).size.width,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Image Picker
                    GestureDetector(
                      onTap: () async {
                        final source = await _showImageSourceSheet(dialogContext);
                        if (source != null) {
                          final image = await _imagePicker.pickImage(source: source, imageQuality: 50);
                          if (image != null) setDialogState(() => selectedImage = File(image.path));
                        }
                      },
                      child: _buildImagePlaceholder(selectedImage),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameController, 
                      decoration: const InputDecoration(
                        labelText: "Medicine Name*", 
                        prefixIcon: Icon(LucideIcons.pill),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      )
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dosageController, 
                      decoration: const InputDecoration(
                        labelText: "Dosage (e.g. 1 tablet)", 
                        prefixIcon: Icon(LucideIcons.scale),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      )
                    ),
                    
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Frequency", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    Wrap(
                      alignment: WrapAlignment.start,
                      spacing: 0,
                      children: [1, 2, 3].map((f) => SizedBox(
                        width: (MediaQuery.of(context).size.width - 100) / 3,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Radio<int>(
                              value: f,
                              groupValue: frequency,
                              activeColor: const Color(0xFF0EA5E9),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              onChanged: (val) {
                                setDialogState(() {
                                  frequency = val!;
                                  final dur = int.tryParse(durationController.text) ?? 7;
                                  qtyController.text = (frequency * dur).toString();
                                });
                              },
                            ),
                            Flexible(child: Text("${f}x/day", style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      )).toList(),
                    ),

                    const SizedBox(height: 12),
                    _buildTimePickerTile(dialogContext, "Morning Time", t1, (t) => setDialogState(() => t1 = t)),
                    if (frequency >= 2) _buildTimePickerTile(dialogContext, "Afternoon Time", t2, (t) => setDialogState(() => t2 = t)),
                    if (frequency >= 3) _buildTimePickerTile(dialogContext, "Night Time", t3, (t) => setDialogState(() => t3 = t)),

                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: durationController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Duration (Days)", 
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            onChanged: (val) {
                              final dur = int.tryParse(val) ?? 1;
                              setDialogState(() => qtyController.text = (frequency * dur).toString());
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: qtyController, 
                            keyboardType: TextInputType.number, 
                            decoration: const InputDecoration(
                              labelText: "Total Qty", 
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            )
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text("Start Date: ${DateFormat('dd MMM yyyy').format(startDate)}", style: const TextStyle(fontWeight: FontWeight.w500)),
                      trailing: const Icon(LucideIcons.calendar, color: Color(0xFF0EA5E9), size: 20),
                      onTap: () async {
                        final date = await showDatePicker(
                          context: dialogContext, 
                          initialDate: startDate, 
                          firstDate: DateTime.now().subtract(const Duration(days: 365)), 
                          lastDate: DateTime.now().add(const Duration(days: 365))
                        );
                        if (date != null) setDialogState(() => startDate = date);
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      width: double.infinity,
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                      child: Text("Auto-calculated End Date: ${DateFormat('dd MMM yyyy').format(endDate)}", 
                        style: const TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9), 
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _handleSave(
                  dialogContext: dialogContext,
                  existingMed: existingMed,
                  name: nameController.text,
                  dosage: dosageController.text,
                  freq: frequency,
                  t1: t1, t2: t2, t3: t3,
                  dur: int.tryParse(durationController.text) ?? 7,
                  start: startDate,
                  qty: int.tryParse(qtyController.text) ?? 0,
                  image: selectedImage,
                ),
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleSave({
    BuildContext? dialogContext,
    Medicine? existingMed,
    required String name,
    required String dosage,
    required int freq,
    TimeOfDay? t1, TimeOfDay? t2, TimeOfDay? t3,
    required int dur,
    required DateTime start,
    required int qty,
    File? image,
  }) async {
    if (_isSaving) return;
    _isSaving = true;

    if (name.isEmpty) {
      AppSnackBar.showError(context, "Medicine name is required");
      _isSaving = false;
      return;
    }

    try {
      String? imagePath = existingMed?.imagePath;
      if (image != null && (existingMed?.imagePath == null || image.path != existingMed!.imagePath)) {
        final dir = await getApplicationDocumentsDirectory();
        final fileName = 'med_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = await image.copy('${dir.path}/$fileName');
        imagePath = savedImage.path;
      }

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final med = Medicine(
        id: existingMed?.id,
        userId: userId,
        name: name,
        dosage: dosage,
        frequency: freq,
        time1: _formatTimeOfDay(t1!),
        time2: freq >= 2 ? _formatTimeOfDay(t2!) : null,
        time3: freq >= 3 ? _formatTimeOfDay(t3!) : null,
        startDate: start,
        durationDays: dur,
        qty: qty,
        counter: existingMed?.counter ?? 0,
        isActive: true,
        isTaken: existingMed?.isTaken ?? false,
        imagePath: imagePath,
      );

      // Cancel old alarms if editing
      if (existingMed != null) {
        // ✅ Sirf valid IDs cancel karo
        await _alarmService.cancelAlarmsForMedicine([
          existingMed.alarmId1,
          existingMed.alarmId2,
          existingMed.alarmId3,
        ]);
      }

      // Schedule new alarms only if today is between start_date and end_date
      int? aid1, aid2, aid3;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startDateOnly = DateTime(med.startDate.year, med.startDate.month, med.startDate.day);
      final endDateOnly = DateTime(med.endDate.year, med.endDate.month, med.endDate.day);

      if ((today.isAfter(startDateOnly) || today.isAtSameMomentAs(startDateOnly)) &&
          (today.isBefore(endDateOnly) || today.isAtSameMomentAs(endDateOnly))) {
        
        print("Today is in range. Scheduling alarms...");
        aid1 = await _scheduleSingleAlarm(med, 1, t1!);
        if (freq >= 2) aid2 = await _scheduleSingleAlarm(med, 2, t2!);
        if (freq >= 3) aid3 = await _scheduleSingleAlarm(med, 3, t3!);
      } else {
        print("Today is NOT in range. Alarms not scheduled.");
        print("Today: $today, Start: $startDateOnly, End: $endDateOnly");
      }

      final finalMed = Medicine(
        id: med.id,
        userId: med.userId,
        name: med.name,
        dosage: med.dosage,
        frequency: med.frequency,
        time1: med.time1,
        time2: med.time2,
        time3: med.time3,
        alarmId1: aid1,
        alarmId2: aid2,
        alarmId3: aid3,
        startDate: med.startDate,
        durationDays: med.durationDays,
        qty: med.qty,
        counter: med.counter,
        isActive: med.isActive,
        isTaken: med.isTaken,
        imagePath: med.imagePath,
      );

      if (existingMed == null) {
        await _supabase.from('medications').insert(finalMed.toJson());
        
        // Log activity for new medicine
        try {
          await ActivityService.log(
            actionType: 'MEDICINE_ADDED',
            description: 'Added a new medicine: $name',
          );
        } catch (e) {
          debugPrint('Log error: $e');
        }
      } else {
        await _supabase.from('medications').update(finalMed.toJson()).eq('id', existingMed.id!);
      }

      if (mounted) {
        if (dialogContext != null && Navigator.canPop(dialogContext)) {
          Navigator.pop(dialogContext); // ✅ Dialog close karo
        }
        _fetchMedications();
        AppSnackBar.showSuccess(context, "Medicine saved successfully!");
      }
    } catch (e) {
      debugPrint("Save Error: $e");
      if (mounted) AppSnackBar.showError(context, "Failed to save: $e");
    } finally {
      _isSaving = false;
    }
  }

  /// Generates a unique alarm ID using a monotonic counter stored in SharedPreferences.
  /// Avoids hashCode collisions and is deterministic across isolates.
  Future<int> _nextAlarmId() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('alarm_id_counter') ?? 1000;
    final next = current + 1;
    await prefs.setInt('alarm_id_counter', next);
    return next;
  }

  Future<int?> _scheduleSingleAlarm(Medicine med, int slot, TimeOfDay tod) async {
    final stableId = await _nextAlarmId();
    final now = DateTime.now();
    DateTime alarmTime = DateTime(now.year, now.month, now.day, tod.hour, tod.minute);

    debugPrint("=== ALARM SCHEDULE ATTEMPT ===");
    debugPrint("Medicine: ${med.name}, Slot: $slot, ID: $stableId");
    debugPrint("Requested time: ${tod.format(context)} => DateTime: $alarmTime");
    debugPrint("Current time: $now");

    // If the time has ALREADY PASSED today (not just 2 min buffer — remove that logic)
    // Only shift to tomorrow if more than 1 minute in the past
    if (alarmTime.isBefore(now.subtract(const Duration(minutes: 1)))) {
      debugPrint("⚠️ Time already passed today — shifting to TOMORROW");
      alarmTime = alarmTime.add(const Duration(days: 1));
      debugPrint("New alarm time: $alarmTime");
    }

    // Safety: Never schedule a past alarm
    if (alarmTime.isBefore(now)) {
      debugPrint("⚠️ Still in past after adjustment — adding 1 more day");
      alarmTime = alarmTime.add(const Duration(days: 1));
    }

    final endDateLimit = DateTime(
      med.endDate.year, med.endDate.month, med.endDate.day, 23, 59, 59
    );

    if (alarmTime.isBefore(endDateLimit)) {
      try {
        await _alarmService.scheduleAlarm(
          id: stableId,
          medicineName: med.name,
          dosage: med.dosage,
          imagePath: med.imagePath ?? '',
          time: alarmTime,
        );

        // Cache full medication data for instant AlarmScreen
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('cached_med_$stableId', jsonEncode({
            'id': med.id ?? '',
            'name': med.name,
            'dosage': med.dosage,
            'qty': med.qty,
            'image_path': med.imagePath,
            'alarm_id1': med.alarmId1,
            'alarm_id2': med.alarmId2,
            'alarm_id3': med.alarmId3,
            'slot': slot,
          }));
        } catch (_) {}

        final alarms = await Alarm.getAlarms();
        final wasSet = alarms.any((a) => a.id == stableId);
        debugPrint(wasSet
          ? "✅ SUCCESS: Alarm $stableId set for $alarmTime"
          : "❌ FAILED: Alarm $stableId NOT found in active alarms!");
        debugPrint("All active alarms: ${alarms.map((a) => '${a.id}@${a.dateTime}').join(', ')}");

        return stableId;
      } catch (e) {
        debugPrint("❌ EXCEPTION while scheduling: $e");
        return null;
      }
    } else {
      debugPrint("❌ NOT SCHEDULED: alarmTime ($alarmTime) is after endDate ($endDateLimit)");
      return null;
    }
  }

  Future<void> _deleteMedication(Medicine med) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Medicine?"),
        content: Text("Are you sure you want to delete ${med.name}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Delete", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _alarmService.cancelAlarmsForMedicine([
          med.alarmId1,
          med.alarmId2,
          med.alarmId3,
        ]);
        await _supabase.from('medications').delete().eq('id', med.id!);
        _fetchMedications();
        if (mounted) AppSnackBar.showSuccess(context, "Medicine deleted");
      } catch (e) {
        if (mounted) AppSnackBar.showError(context, "Delete failed: $e");
      }
    }
  }

  Future<void> _updateQty(Medicine med, int delta) async {
    try {
      final newQty = (med.qty + delta).clamp(0, 99999);
      await _supabase.from('medications').update({'qty': newQty}).eq('id', med.id!);
      _fetchMedications();
      if (mounted) {
        if (newQty <= med.frequency * 3 && newQty > 0) {
          AppSnackBar.showError(context, "Low stock! Only $newQty left.");
        } else if (newQty == 0) {
          AppSnackBar.showError(context, "Medicine stock is over. Please refill.");
        } else {
          AppSnackBar.showSuccess(context, "Qty updated to $newQty");
        }
      }
    } catch (e) {
      debugPrint("Qty update error: $e");
      if (mounted) AppSnackBar.showError(context, "Failed to update qty: $e");
    }
  }

  void _showRefillDialog(Medicine med) {
    final refillController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Refill ${med.name}", style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: refillController,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: "Add how many tablets?",
            prefixIcon: Icon(LucideIcons.pill),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final addQty = int.tryParse(refillController.text) ?? 0;
              if (addQty <= 0) {
                AppSnackBar.showError(context, "Enter a valid number");
                return;
              }
              try {
                final newQty = med.qty + addQty;
                await _supabase.from('medications').update({
                  'qty': newQty,
                  'is_active': true,
                }).eq('id', med.id!);
                Navigator.pop(dialogContext);
                _fetchMedications();
                if (mounted) AppSnackBar.showSuccess(context, "Refilled! New qty: $newQty");
              } catch (e) {
                debugPrint("Refill error: $e");
                if (mounted) AppSnackBar.showError(context, "Refill failed: $e");
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("My Medications", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.alarmClock, color: Colors.orange),
            tooltip: "Test Alarm (1 min)",
            onPressed: () async {
              try {
                final testTime = DateTime.now().add(const Duration(minutes: 1));
                const testId = 99999;
                
                await AlarmService().scheduleAlarm(
                  id: testId,
                  medicineName: "TEST ALARM 🔔",
                  dosage: "1 tablet",
                  imagePath: '',
                  time: testTime,
                );
                
                final alarms = await Alarm.getAlarms();
                final wasSet = alarms.any((a) => a.id == testId);
                
                if (mounted) {
                  AppSnackBar.showSuccess(
                    context, 
                    wasSet 
                      ? "✅ Test alarm set! Will ring at ${testTime.hour}:${testTime.minute.toString().padLeft(2,'0')}" 
                      : "❌ Alarm NOT set — check permissions!", 
                  );
                }
              } catch (e) {
                if (mounted) AppSnackBar.showError(context, "Error: $e");
              }
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.bellRing, color: Color(0xFF0EA5E9)),
            tooltip: "Alarm Setup",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AlarmSetupScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.helpCircle, color: Colors.grey),
            onPressed: () => _showPermissionGuide(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0EA5E9)))
          : RefreshIndicator(
              onRefresh: _fetchMedications,
              color: const Color(0xFF0EA5E9),
              child: _medications.isEmpty
                  ? _buildEmptyState()
                  : Builder(
                      builder: (context) {
                        final activeMeds = _medications.where((m) => m.isActive).toList();
                        final inactiveMeds = _medications.where((m) => !m.isActive).toList();
                        final totalItems = activeMeds.length + (inactiveMeds.isNotEmpty ? inactiveMeds.length + 1 : 0);
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: totalItems,
                          itemBuilder: (ctx, i) {
                            if (i < activeMeds.length) {
                              return _buildMedicineCard(activeMeds[i]);
                            }
                            if (i == activeMeds.length) {
                              // Section header for inactive
                              return Padding(
                                padding: const EdgeInsets.only(top: 16, bottom: 8),
                                child: Row(
                                  children: [
                                    const Icon(LucideIcons.archive, size: 18, color: Colors.grey),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Completed / Inactive",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            final inactiveIndex = i - activeMeds.length - 1;
                            return _buildInactiveMedicineCard(inactiveMeds[inactiveIndex]);
                          },
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_medicine_fab',
        onPressed: () => _showAddEditDialog(),
        backgroundColor: const Color(0xFF0EA5E9),
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: const Text("Add Medicine", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildMedicineCard(Medicine med) {
    final isExpanded = _expandedMedId == med.id;
    final bool lowStock = med.qty <= med.frequency * 3;

    return Dismissible(
      key: Key(med.id!),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(20)),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.trash2, color: Colors.white),
            Text("Delete", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await _deleteMedication(med);
        return false;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ===== 1. ORIGINAL CARD CONTENT (untouched) =====
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onLongPress: () => _showAddEditDialog(existingMed: med),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MedicineLogScreen(
                    medicationId: med.id!,
                    medicineName: med.name,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Image
                    Hero(
                      tag: 'med_img_${med.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Container(
                          width: 70, height: 70,
                          color: const Color(0xFF0EA5E9).withOpacity(0.1),
                          child: med.imagePath != null && File(med.imagePath!).existsSync()
                              ? Image.file(File(med.imagePath!), fit: BoxFit.cover)
                              : const Icon(LucideIcons.pill, color: Color(0xFF0EA5E9), size: 30),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Right: Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(med.name,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: lowStock ? Colors.red[50] : Colors.green[50],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text("${med.qty} left",
                                  style: TextStyle(color: lowStock ? Colors.red : Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text("${DateFormat('dd MMM').format(med.startDate)} → ${DateFormat('dd MMM').format(med.endDate)}",
                            style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: med.activeTimes.map((t) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0EA5E9).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.clock, size: 10, color: Color(0xFF0EA5E9)),
                                  const SizedBox(width: 4),
                                  Text(t, style: const TextStyle(fontSize: 11, color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )).toList(),
                          ),
                        ],
                      ),
                    ),
                    // Edit + Expand buttons
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(LucideIcons.edit3, size: 20, color: Colors.blueGrey),
                          onPressed: () => _showAddEditDialog(existingMed: med),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                            size: 20,
                            color: const Color(0xFF0EA5E9),
                          ),
                          onPressed: () => setState(() => _expandedMedId = isExpanded ? null : med.id),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ===== 2. EXPANDED STOCK MANAGEMENT (strictly below) =====
            if (isExpanded) ...[
              const Divider(height: 1, thickness: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Stock Management', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Qty: ${med.qty}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () => _updateQty(med, -1),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                              onPressed: () => _updateQty(med, 1),
                            ),
                            TextButton(
                              onPressed: () => _showRefillDialog(med),
                              child: const Text('Refill +'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInactiveMedicineCard(Medicine med) {
    return GestureDetector(
      onTap: () => _showRefillDialog(med),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Opacity(
          opacity: 0.6,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    width: 60, height: 60,
                    color: Colors.grey[200],
                    child: med.imagePath != null && _existingImagePaths.contains(med.imagePath!)
                        ? Image.file(File(med.imagePath!), fit: BoxFit.cover, color: Colors.grey, colorBlendMode: BlendMode.saturation)
                        : Icon(LucideIcons.pill, color: Colors.grey[400], size: 28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(med.name,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text("Stock: ${med.qty} | ${med.frequency}x/day",
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(10)),
                  child: Text("Tap to Refill", style: TextStyle(color: Colors.orange[700], fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
            child: const Icon(LucideIcons.pill, size: 60, color: Color(0xFF0EA5E9)),
          ),
          const SizedBox(height: 24),
          const Text("No medications yet", style: TextStyle(color: Colors.black87, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Keep track of your family's health\nby adding their medications here.", 
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 15)
          ),
        ],
      ),
    );
  }

  // --- Helper Methods ---
  void _showPermissionGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(LucideIcons.bellRing, color: Color(0xFF0EA5E9)),
            SizedBox(width: 12),
            Text("Alarm Guide", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Ensure your alarms ring reliably by enabling these settings:",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 20),
              _buildGuideItem(
                icon: LucideIcons.battery,
                title: "Battery Optimization",
                desc: "Set to 'Unrestricted' in Settings > Apps > FamCare > Battery.",
              ),
              _buildGuideItem(
                icon: LucideIcons.layers,
                title: "Display over apps",
                desc: "Allow this for the alarm to appear when your phone is locked.",
              ),
              _buildGuideItem(
                icon: LucideIcons.zap,
                title: "Auto-start",
                desc: "Common on Xiaomi/Oppo/Vivo devices. Enable in app settings.",
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9))),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideItem({required IconData icon, required String title, required String desc}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF0EA5E9), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null) return null;
    try {
      final parts = timeStr.split(' ');
      final tParts = parts[0].split(':');
      int hour = int.parse(tParts[0]);
      final min = int.parse(tParts[1]);
      if (parts[1] == 'PM' && hour < 12) hour += 12;
      if (parts[1] == 'AM' && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: min);
    } catch (_) { return null; }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m = tod.minute.toString().padLeft(2, '0');
    final p = tod.period == DayPeriod.am ? "AM" : "PM";
    return "${h.toString().padLeft(2, '0')}:$m $p";
  }

  Widget _buildTimePickerTile(BuildContext context, String label, TimeOfDay? time, Function(TimeOfDay) onPicked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!)
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        visualDensity: VisualDensity.compact,
        dense: true,
        title: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Text(time == null ? "Not set" : time.format(context), 
          style: TextStyle(color: time == null ? Colors.grey : const Color(0xFF0EA5E9), fontWeight: FontWeight.bold, fontSize: 14)),
        trailing: const Icon(LucideIcons.clock, size: 18, color: Color(0xFF0EA5E9)),
        onTap: () async {
          final t = await showTimePicker(context: context, initialTime: time ?? TimeOfDay.now());
          if (t != null) onPicked(t);
        },
      ),
    );
  }

  Future<ImageSource?> _showImageSourceSheet(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select Image Source", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSourceOption(ctx, LucideIcons.camera, "Camera", ImageSource.camera),
                  _buildSourceOption(ctx, LucideIcons.image, "Gallery", ImageSource.gallery),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption(BuildContext context, IconData icon, String label, ImageSource source) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, source),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF0EA5E9).withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFF0EA5E9), size: 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder(File? image) {
    return Container(
      height: 120, width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[50], 
        borderRadius: BorderRadius.circular(15), 
        border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid)
      ),
      child: image != null
          ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(image, fit: BoxFit.cover))
          : Column(
              mainAxisAlignment: MainAxisAlignment.center, 
              children: [
                Icon(LucideIcons.camera, color: Colors.grey[400], size: 40),
                const SizedBox(height: 8),
                Text("Add Medication Photo", style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
                Text("(Optional)", style: TextStyle(color: Colors.grey[400], fontSize: 11)),
              ]
            ),
    );
  }
}
