import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:alarm/alarm.dart';
import 'services/alarm_service.dart';
import 'services/slot_preferences_service.dart';
import 'models/medicine_model.dart';
import 'screens/alarm_setup_screen.dart';
import 'screens/medicine_log_screen.dart';
import 'utils/snackbar_utils.dart';
import 'main.dart' show medicineUpdatedNotifier;
import 'services/activity_service.dart';
import 'screens/meds/add_medicine_wizard.dart';
import 'screens/meds/widgets/medicine_card.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'providers/medication_provider.dart';
import 'providers/theme_provider.dart';

class MedsScreen extends ConsumerStatefulWidget {
  const MedsScreen({super.key});

  @override
  ConsumerState<MedsScreen> createState() => _MedsScreenState();
}

class _MedsScreenState extends ConsumerState<MedsScreen> {
  final _supabase = Supabase.instance.client;
  final _alarmService = AlarmService();
  bool _isSaving = false;
  final _imagePicker = ImagePicker();
  String? _expandedMedId;

  // Slot-based grouping
  Map<String, dynamic> _slotPrefs = {};
  final Set<String> _expandedSlots = {
    'morning',
    'afternoon',
    'evening',
    'night',
    'custom'
  };

  // Phase 1 UX State
  bool _isRefillCollapsed = false;
  final Set<String> _dismissedRefillMeds = {};
  String _selectedFilter = 'All'; // 'Today', 'All', 'Refills', 'Inactive'
  
  // Phase 5: Meds Overview & Logs
  int _todayTaken = 0;
  int _todayMissed = 0;
  int _todayNeedAction = 0;
  List<Map<String, dynamic>> _recentLogs = [];
  bool _isLoadingTodayLogs = true;
  bool _logsFetchError = false;

  @override
  void initState() {
    super.initState();
    _loadDismissedRefills();
    _fetchMedications();
  }

  Future<void> _loadDismissedRefills() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      for (String key in keys) {
        if (key.startsWith('refill_dismiss_')) {
          final parts = key.split('_');
          if (parts.length >= 5) {
            final date = parts[4];
            if (date != todayStr) {
              await prefs.remove(key); // clear old
            } else {
              _dismissedRefillMeds.add(parts[3]); // medId
            }
          }
        }
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _fetchTodayLogs() async {
    if (mounted) {
      setState(() {
        _isLoadingTodayLogs = true;
        _logsFetchError = false;
      });
    }
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          setState(() {
            _isLoadingTodayLogs = false;
            _logsFetchError = true;
          });
        }
        return;
      }
      
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      final logsResponse = await _supabase
          .from('medicine_logs')
          .select('*')
          .eq('user_id', userId)
          .gte('created_at', '${todayStr}T00:00:00')
          .order('created_at', ascending: false)
          .limit(100);
          
      int taken = 0;
      int missed = 0;
      int snoozed = 0;
      
      for (var row in logsResponse) {
        final status = row['status'] as String?;
        if (status == 'taken') taken++;
        else if (status == 'missed') missed++;
        else if (status == 'snoozed') snoozed++;
      }
      
      if (mounted) {
        setState(() {
          _todayTaken = taken;
          _todayMissed = missed;
          _todayNeedAction = snoozed;
          _recentLogs = List<Map<String, dynamic>>.from(logsResponse.take(3));
          _isLoadingTodayLogs = false;
          _logsFetchError = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching today logs: $e");
      if (mounted) {
        setState(() {
          _isLoadingTodayLogs = false;
          _logsFetchError = true;
        });
      }
    }
  }

  Future<void> _fetchMedications() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print("Fetch Error: No user ID found");
        return;
      }

      print("Fetching medications for user: $userId via Riverpod");

      // Load slot preferences for card headers
      final slotPrefs = await SlotPreferencesService().getPreferences();

      // Trigger Riverpod fetch (it updates the UI automatically)
      await ref.read(medicationsProvider.notifier).fetchMedications(userId);
      _fetchTodayLogs(); // non-blocking parallel load

      if (mounted) {
        setState(() {
          _slotPrefs = slotPrefs;
        });
      }
    } catch (e) {
      print('Fetch Error: $e');
    }
  }

  // ==========================================
  // ➕ ADD/EDIT MEDICINE DIALOG (Redesigned)
  // ==========================================
  Future<void> _showAddEditDialog({Medicine? existingMed}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMedicineWizard(
          existingMed: existingMed,
          onSave: _handleSave,
        ),
      ),
    );
  }

  Widget _buildSlotChip(
      String value,
      String label,
      IconData icon,
      List<String> selected,
      StateSetter setDialogState,
      VoidCallback recalcQty) {
    final isSelected = selected.contains(value);
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF0EA5E9)),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF0EA5E9),
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? const Color(0xFF0EA5E9) : Colors.grey[300]!,
        ),
      ),
      onSelected: (val) {
        setDialogState(() {
          if (val) {
            selected.add(value);
          } else {
            selected.remove(value);
          }
          recalcQty();
        });
      },
    );
  }

  Widget _buildScheduleRadio({
    required String value,
    required String groupValue,
    required String label,
    required Function(String?) onChanged,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Radio<String>(
            value: value,
            groupValue: groupValue,
            activeColor: const Color(0xFF0EA5E9),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            onChanged: onChanged,
          ),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Future<void> _showMultiDatePicker(
    BuildContext context,
    List<String> currentDates,
    StateSetter setDialogState,
    VoidCallback recalcQty,
  ) async {
    final selected = currentDates.map((d) => DateTime.parse(d)).toSet();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, sheetState) {
          final dates =
              List.generate(90, (i) => DateTime.now().add(Duration(days: i)));

          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            minChildSize: 0.4,
            expand: false,
            builder: (_, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'Select Dates',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        '${selected.length} selected',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      _quickSelectChip(
                          'Today', [DateTime.now()], selected, sheetState),
                      _quickSelectChip(
                        'This week',
                        List.generate(
                            7, (i) => DateTime.now().add(Duration(days: i))),
                        selected,
                        sheetState,
                      ),
                      _quickSelectChip(
                        'Next 30 days',
                        List.generate(
                            30, (i) => DateTime.now().add(Duration(days: i))),
                        selected,
                        sheetState,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      childAspectRatio: 1,
                    ),
                    itemCount: dates.length,
                    itemBuilder: (_, i) {
                      final date = dates[i];
                      final isSelected =
                          selected.any((s) => _isSameDate(s, date));
                      final isToday = _isSameDate(date, DateTime.now());
                      return GestureDetector(
                        onTap: () {
                          sheetState(() {
                            if (isSelected) {
                              selected.removeWhere((s) => _isSameDate(s, date));
                            } else {
                              selected.add(
                                  DateTime(date.year, date.month, date.day));
                            }
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0EA5E9)
                                : isToday
                                    ? Colors.blue[50]
                                    : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: isToday
                                ? Border.all(color: const Color(0xFF0EA5E9))
                                : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('d').format(date),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              Text(
                                DateFormat('MMM').format(date),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isSelected
                                      ? Colors.white70
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    MediaQuery.of(ctx).viewInsets.bottom + 16,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selected.isEmpty
                          ? null
                          : () {
                              final sorted = selected.toList()..sort();
                              setDialogState(() {
                                currentDates
                                  ..clear()
                                  ..addAll(sorted.map((d) =>
                                      DateFormat('yyyy-MM-dd').format(d)));
                                recalcQty();
                              });
                              Navigator.pop(ctx);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        selected.isEmpty
                            ? 'Select dates'
                            : 'Confirm ${selected.length} dates',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _quickSelectChip(
    String label,
    List<DateTime> dates,
    Set<DateTime> selected,
    StateSetter sheetState,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label),
        onPressed: () {
          sheetState(() {
            for (final date in dates) {
              selected.add(DateTime(date.year, date.month, date.day));
            }
          });
        },
      ),
    );
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _handleSave({
    required BuildContext dialogContext,
    Medicine? existingMed,
    required String name,
    required String condition,
    required String? form,
    required String? color,
    File? image,
    required double? strength,
    required String? strengthUnit,
    required String? takeAmount,
    required String? foodInstruction,
    required bool isAsNeeded,
    required List<String> selectedSlots,
    required List<TimeOfDay> customAlarmTimes,
    required String scheduleType,
    required int everyXDays,
    required List<String> specificDates,
    required String notes,
    required int dur,
    required DateTime start,
    required int qty,
    required int? refillReminderThreshold,
  }) async {
    if (_isSaving) return;
    _isSaving = true;

    if (name.isEmpty) {
      AppSnackBar.showError(context, "Medicine name is required");
      _isSaving = false;
      return;
    }

    if (selectedSlots.isEmpty) {
      AppSnackBar.showError(context, "Select at least one time slot");
      _isSaving = false;
      return;
    }

    try {
      String? imagePath = existingMed?.imagePath;
      if (image != null &&
          (existingMed?.imagePath == null ||
              image.path != existingMed!.imagePath)) {
        final dir = await getApplicationDocumentsDirectory();
        final fileName = 'med_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final savedImage = await image.copy('${dir.path}/$fileName');
        imagePath = savedImage.path;
      }

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Map selected slots to time1/time2/time3 for backward compat
      // Load slot preferences for default times
      final slotPrefs = await SlotPreferencesService().getPreferences();
      final standardSlots = selectedSlots.where((s) => s != 'custom').toList();

      // Build time list from standard slots using preferences
      List<String> alarmTimeStrings = [];
      for (final slot in standardSlots) {
        final startKey = '${slot}_start';
        final time24 = slotPrefs[startKey] ?? _defaultSlotStart(slot);
        alarmTimeStrings.add(_formatTime24To12(time24));
      }
      // Add custom times
      for (final tod in customAlarmTimes) {
        alarmTimeStrings.add(_formatTimeOfDay(tod));
      }

      // Assign to time1/time2/time3
      String? time1 = alarmTimeStrings.isNotEmpty ? alarmTimeStrings[0] : null;
      String? time2 = alarmTimeStrings.length >= 2 ? alarmTimeStrings[1] : null;
      String? time3 = alarmTimeStrings.length >= 3 ? alarmTimeStrings[2] : null;

      // frequency = total slots for backward compat
      int frequency = alarmTimeStrings.length;

      final durationDays =
          scheduleType == 'specific_dates' ? specificDates.length : dur;
      DateTime end;
      if (scheduleType == 'specific_dates' && specificDates.isNotEmpty) {
        end = DateTime.parse(specificDates.last);
      } else {
        end = start.add(Duration(days: durationDays - 1));
      }
      final newMedicine = Medicine(
        id: existingMed?.id,
        userId: userId,
        name: name,
        dosage: takeAmount ?? "1 tablet", // Fallback for legacy
        frequency: frequency,
        time1: time1,
        time2: time2,
        time3: time3,
        startDate: start,
        durationDays: durationDays,
        qty: qty,
        counter: existingMed?.counter ?? 0,
        isActive: true,
        isTaken: existingMed?.isTaken ?? false,
        imagePath: imagePath,
        slotTypes: selectedSlots,
        customTimes: customAlarmTimes.map((t) {
          final h = t.hour.toString().padLeft(2, '0');
          final m = t.minute.toString().padLeft(2, '0');
          return '$h:$m';
        }).toList(),
        scheduleType: scheduleType,
        everyXDays: everyXDays,
        specificDates: specificDates,
        notes: notes,
        isPaused: existingMed?.isPaused ?? false,
        lowStockAlerted: existingMed?.lowStockAlerted ?? false,
        form: form,
        color: color,
        strength: strength,
        strengthUnit: strengthUnit,
        takeAmount: takeAmount,
        foodInstruction: foodInstruction,
        isAsNeeded: isAsNeeded,
        refillReminderThreshold: refillReminderThreshold,
        condition: condition,
      );

      if (existingMed?.id != null) {
        await ref
            .read(medicationsProvider.notifier)
            .updateMedication(newMedicine, userId);
      } else {
        await ref
            .read(medicationsProvider.notifier)
            .addMedication(newMedicine, userId);
        try {
          await ActivityService.log(
            actionType: 'MEDICINE_ADDED',
            description: 'Added a new medicine: $name',
          );
        } catch (e) {
          debugPrint('Log error: $e');
        }
      }

      if (existingMed != null) {
        // Cancel the individual legacy alarms
        await _alarmService.cancelAlarmsForMedicine([
          existingMed.alarmId1,
          existingMed.alarmId2,
          existingMed.alarmId3,
        ]);
      }

      if (mounted) {
        if (dialogContext != null && Navigator.canPop(dialogContext)) {
          Navigator.pop(dialogContext);
        }
        _fetchMedications();
        AppSnackBar.showSuccess(context, "Medicine saved successfully!");
        medicineUpdatedNotifier.value++;
      }
      debugPrint(
          'Medicine saved with ID=${newMedicine.id}; group alarm reschedule requested');
    } catch (e) {
      debugPrint("Save Error: $e");
      if (mounted) AppSnackBar.showError(context, "Failed to save: $e");
    } finally {
      _isSaving = false;
    }
  }

  String _defaultSlotStart(String slot) {
    switch (slot) {
      case 'morning':
        return '08:00';
      case 'afternoon':
        return '12:00';
      case 'evening':
        return '16:00';
      case 'night':
        return '21:00';
      default:
        return '08:00';
    }
  }

  String _formatTime24To12(String time24) {
    final parts = time24.split(':');
    if (parts.length != 2) return time24;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${hour12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
  }

  void _showMedicineOptions(Medicine med) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(LucideIcons.edit3, color: Color(0xFF0EA5E9)),
              title: const Text('Edit Medicine'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddEditDialog(existingMed: med);
              },
            ),
            ListTile(
              leading: Icon(
                med.isPaused ? LucideIcons.play : LucideIcons.pause,
                color: med.isPaused ? Colors.green : Colors.orange,
              ),
              title: Text(med.isPaused ? 'Resume Medicine' : 'Pause Medicine'),
              subtitle: Text(med.isPaused
                  ? 'Alarms and reminders will resume'
                  : 'Alarms and reminders will be paused'),
              onTap: () {
                Navigator.pop(ctx);
                _togglePauseMedicine(med);
              },
            ),
            ListTile(
              leading: const Icon(LucideIcons.trash2, color: Colors.red),
              title: const Text('Delete Medicine',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _deleteMedication(med);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePauseMedicine(Medicine med) async {
    final newPaused = !med.isPaused;
    try {
      final updatedMed = med.copyWith(isPaused: newPaused);
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await ref
            .read(medicationsProvider.notifier)
            .updateMedication(updatedMed, userId);
      }

      if (newPaused) {
        // Cancel all alarms for this medicine
        await _alarmService.cancelAlarmsForMedicine([
          med.alarmId1,
          med.alarmId2,
          med.alarmId3,
        ]);
        AppSnackBar.showInfo(context, "${med.name} paused — alarms cancelled");
      } else {
        AppSnackBar.showInfo(context, "${med.name} resumed");
      }
      medicineUpdatedNotifier.value++;
    } catch (e) {
      debugPrint('Pause toggle error: $e');
      AppSnackBar.showError(
          context, "Failed to ${newPaused ? 'pause' : 'resume'} medicine");
    }
  }

  Future<void> _deleteMedication(Medicine med) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Medicine?"),
        content: Text("Are you sure you want to delete ${med.name}?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red))),
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
        final userId = _supabase.auth.currentUser?.id;
        if (userId != null) {
          await ref
              .read(medicationsProvider.notifier)
              .deleteMedication(med.id!, userId);
        }
        if (mounted) {
          AppSnackBar.showSuccess(context, "Medicine deleted");
          medicineUpdatedNotifier.value++;
        }
      } catch (e) {
        if (mounted) AppSnackBar.showError(context, "Delete failed: $e");
      }
    }
  }

  Future<void> _updateQty(Medicine med, int delta) async {
    try {
      final newQty = (med.qty + delta).clamp(0, 99999);
      final updatedMed = med.copyWith(qty: newQty);
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await ref
            .read(medicationsProvider.notifier)
            .updateMedication(updatedMed, userId);
      }

      if (mounted) {
        if (newQty <= med.frequency * 3 && newQty > 0) {
          AppSnackBar.showError(context, "Low stock! Only $newQty left.");
        } else if (newQty == 0) {
          AppSnackBar.showError(
              context, "Medicine stock is over. Please refill.");
        } else {
          AppSnackBar.showSuccess(context, "Qty updated to $newQty");
        }
        medicineUpdatedNotifier.value++;
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
        title: Text("Refill ${med.name}",
            style: const TextStyle(fontWeight: FontWeight.bold)),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final addQty = int.tryParse(refillController.text) ?? 0;
              if (addQty <= 0) {
                AppSnackBar.showError(context, "Enter a valid number");
                return;
              }
              try {
                final newQty = med.qty + addQty;
                final updatedMed = med.copyWith(qty: newQty, isActive: true);
                final userId = _supabase.auth.currentUser?.id;
                if (userId != null) {
                  await ref
                      .read(medicationsProvider.notifier)
                      .updateMedication(updatedMed, userId);
                }

                Navigator.pop(dialogContext);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Refilled! New qty: $newQty"),
                      backgroundColor: Colors.green,
                      action: SnackBarAction(
                        label: 'Undo',
                        textColor: Colors.white,
                        onPressed: () async {
                           final revertedMed = med.copyWith(qty: med.qty, isActive: med.isActive);
                           if (userId != null) {
                             await ref.read(medicationsProvider.notifier).updateMedication(revertedMed, userId);
                             medicineUpdatedNotifier.value++;
                           }
                        },
                      ),
                    ),
                  );
                  medicineUpdatedNotifier.value++;
                }
              } catch (e) {
                debugPrint("Refill error: $e");
                if (mounted)
                  AppSnackBar.showError(context, "Refill failed: $e");
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _openHistoryLogs() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MedicineLogScreen(aggregated: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("My Medications"),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.history, color: AppTheme.cyanAccent),
            tooltip: "History / Logs",
            onPressed: _openHistoryLogs,
          ),
          IconButton(
            icon: const Icon(LucideIcons.alarmClock, color: AppTheme.orangeAccent),
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
                        ? "✅ Test alarm set! Will ring at ${testTime.hour}:${testTime.minute.toString().padLeft(2, '0')}"
                        : "❌ Alarm NOT set — check permissions!",
                  );
                }
              } catch (e) {
                if (mounted) AppSnackBar.showError(context, "Error: $e");
              }
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.bellRing, color: AppTheme.cyanAccent),
            tooltip: "Alarm Setup",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AlarmSetupScreen()),
            ),
          ),
          IconButton(
            icon: Icon(
              ref.watch(themeProvider) == ThemeMode.dark 
                ? LucideIcons.sun 
                : LucideIcons.moon,
              color: AppTheme.cyanAccent,
            ),
            tooltip: "Toggle Theme",
            onPressed: () {
              ref.read(themeProvider.notifier).toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(LucideIcons.helpCircle, color: AppTheme.textSecondary),
            onPressed: () => _showPermissionGuide(),
          ),
        ],
      ),
      body: ref.watch(medicationsProvider).when(
            data: (medications) => RefreshIndicator(
              onRefresh: _fetchMedications,
              color: AppTheme.cyanAccent,
              child: medications.isEmpty
                  ? _buildEmptyState()
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildMedsOverviewStrip(),
                              _buildHistoryLogsSection(),
                              _buildRefillCenter(medications),
                              _buildFilterStrip(),
                            ],
                          ),
                        ),
                        SliverFillRemaining(
                          child: _buildGroupedSlotView(medications),
                        ),
                      ],
                    ),
            ),
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.cyanAccent)),
            error: (err, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.wifiOff, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text("Could not load medications", style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text("Please check your connection and try again.", style: TextStyle(color: Colors.grey[600])),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _fetchMedications,
                    icon: const Icon(LucideIcons.refreshCw, size: 18),
                    label: const Text("Retry"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.cyanAccent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_medicine_fab',
        onPressed: () => _showAddEditDialog(),
        backgroundColor: AppTheme.cyanAccent,
        icon: const Icon(LucideIcons.plus, color: AppTheme.background),
        label: const Text("Add Medicine",
            style: TextStyle(color: AppTheme.background, fontWeight: FontWeight.bold)),
      ).animate().scale(delay: 500.ms, curve: Curves.easeOutBack),
    );
  }

  // ══════════════════════════════════
  // SLOT-GROUPED VIEW
  // ══════════════════════════════════

  Map<String, List<Medicine>> _groupMedicinesBySlot(List<Medicine> meds) {
    final groups = {
      'morning': <Medicine>[],
      'afternoon': <Medicine>[],
      'evening': <Medicine>[],
      'night': <Medicine>[],
      'custom': <Medicine>[],
    };
    for (final med in meds) {
      if (!med.isActive) continue; // inactive meds handled separately
      for (final slot in med.slotTypes) {
        groups[slot]?.add(med);
      }
      if (med.slotTypes.isEmpty) {
        groups['custom']?.add(med); // Legacy medicines go to custom
      }
    }
    return groups;
  }

  Widget _buildFilterStrip() {
    final filters = ['Today', 'All', 'Refills', 'Inactive'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f),
              selected: isSelected,
              onSelected: (val) {
                if (val) setState(() => _selectedFilter = f);
              },
              selectedColor: AppTheme.cyanAccent.withOpacity(0.2),
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.cyanAccent : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMedsOverviewStrip() {
    if (_isLoadingTodayLogs) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: AppTheme.cyanAccent),
            ),
            const SizedBox(width: 10),
            Text(
              "Loading today's activity",
              style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (_logsFetchError) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.wifiOff, size: 16, color: Colors.grey[500]),
            const SizedBox(width: 8),
            Text("Overview unavailable offline", style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildOverviewStat("Taken", _todayTaken, Colors.green),
          _buildOverviewStat("Missed", _todayMissed, Colors.red),
          _buildOverviewStat("Snoozed", _todayNeedAction, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildOverviewStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(count.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildHistoryLogsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cyanAccent.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cyanAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(LucideIcons.history, size: 20, color: AppTheme.cyanAccent),
                  SizedBox(width: 8),
                  Text("History / Logs", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              TextButton(
                onPressed: _openHistoryLogs,
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.cyanAccent,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text("View Logs"),
              ),
            ],
          ),
          if (_logsFetchError)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text("History temporarily unavailable", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            )
          else if (_recentLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text("Start by taking or snoozing a reminder", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            )
          else
            Column(
              children: _recentLogs.map((log) {
                final status = log['status'] as String? ?? 'unknown';
                final timeStr = log['created_at'] as String?;
                final time = timeStr != null ? DateFormat('hh:mm a').format(DateTime.parse(timeStr)) : '';
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        status == 'taken' ? LucideIcons.checkCircle2 : status == 'missed' ? LucideIcons.xCircle : LucideIcons.moon,
                        size: 14,
                        color: status == 'taken' ? Colors.green : status == 'missed' ? Colors.red : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "${log['medicine_name']} — $time",
                          style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  int _effectiveRefillThreshold(Medicine med) {
    return med.refillReminderThreshold ?? (med.frequency * 3);
  }

  int? _estimateDaysLeft(Medicine med) {
    if (med.isAsNeeded || !med.isActive || med.scheduleType != 'daily') {
      return null;
    }

    final takeAmt = double.tryParse(med.takeAmount ?? '1') ?? 1.0;
    if (med.frequency <= 0 || takeAmt <= 0) return null;

    final estimated = (med.qty / takeAmt / med.frequency).floor();
    return estimated < 0 ? 0 : estimated;
  }

  Widget _buildRefillCenter(List<Medicine> medications) {
    if (_selectedFilter != 'All' && _selectedFilter != 'Refills' && _selectedFilter != 'Today') return const SizedBox.shrink();

    final lowStockMeds = medications.where((med) {
      if (med.isAsNeeded || !med.isActive) return false;
      if (_dismissedRefillMeds.contains(med.id)) return false;
      final threshold = _effectiveRefillThreshold(med);
      return med.qty <= threshold;
    }).toList()
      ..sort((a, b) {
        final aPriority = a.qty <= 0 ? 0 : 1;
        final bPriority = b.qty <= 0 ? 0 : 1;
        final severityCompare = aPriority.compareTo(bPriority);
        if (severityCompare != 0) return severityCompare;
        return a.qty.compareTo(b.qty);
      });

    if (lowStockMeds.isEmpty) return const SizedBox.shrink();

    final displayedMeds = _isRefillCollapsed ? lowStockMeds.take(2).toList() : lowStockMeds;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.alertTriangle, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              const Text("Refill Center", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              if (lowStockMeds.length > 2)
                InkWell(
                  onTap: () => setState(() => _isRefillCollapsed = !_isRefillCollapsed),
                  child: Row(
                    children: [
                      Text(
                        _isRefillCollapsed ? 'View All (${lowStockMeds.length})' : 'Show Less',
                        style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      Icon(
                        _isRefillCollapsed ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                        color: Colors.red[700],
                        size: 16,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...displayedMeds.map((med) {
            final threshold = _effectiveRefillThreshold(med);
            final estDaysLeft = _estimateDaysLeft(med);
            final isCritical = med.qty <= 0;

            return Dismissible(
              key: Key('refill_${med.id}'),
              direction: DismissDirection.endToStart,
              onDismissed: (dir) async {
                setState(() => _dismissedRefillMeds.add(med.id!));
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final userId = _supabase.auth.currentUser?.id ?? 'unknown';
                  final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                  await prefs.setBool('refill_dismiss_${userId}_${med.id}_$todayStr', true);
                } catch (_) {}
                if (mounted) AppSnackBar.showInfo(context, "Dismissed refill alert for today");
              },
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8)),
                child: const Icon(LucideIcons.eyeOff, color: Colors.black54),
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(med.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text("Alert at $threshold left", style: TextStyle(fontSize: 12, color: Colors.red[400])),
                          if (estDaysLeft != null && med.qty > 0)
                            Text("Est: $estDaysLeft days left", style: TextStyle(fontSize: 12, color: Colors.red[400]))
                          else if (med.qty > 0)
                            Text("Estimate unavailable for this schedule", style: TextStyle(fontSize: 12, color: Colors.red[400])),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCritical ? Colors.red : Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCritical ? "Out of stock" : "${med.qty} left",
                        style: TextStyle(color: isCritical ? Colors.white : Colors.red[700], fontWeight: FontWeight.bold, fontSize: 12)
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () => _showRefillDialog(med),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isCritical ? Colors.red : Colors.orange[700],
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Text(isCritical ? "Refill now" : "Refill soon"),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildGroupedSlotView(List<Medicine> medications) {
    List<Medicine> activeMeds = medications.where((m) => m.isActive).toList();
    List<Medicine> inactiveMeds = medications.where((m) => !m.isActive).toList();
    
    if (_selectedFilter == 'Today') {
      // Very basic "Today" filter: only show active meds. (Could be expanded to check specific dates)
      inactiveMeds = [];
    } else if (_selectedFilter == 'Inactive') {
      activeMeds = [];
    } else if (_selectedFilter == 'Refills') {
      activeMeds = activeMeds.where((m) => m.qty <= _effectiveRefillThreshold(m)).toList();
      inactiveMeds = [];
    }

    final groups = _groupMedicinesBySlot(activeMeds);

    final slotOrder = ['morning', 'afternoon', 'evening', 'night', 'custom'];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: slotOrder.where((s) => groups[s]!.isNotEmpty).length +
          (inactiveMeds.isNotEmpty ? 1 : 0),
      itemBuilder: (ctx, i) {
        // Filter to non-empty slots
        final nonEmptySlots =
            slotOrder.where((s) => groups[s]!.isNotEmpty).toList();

        if (i < nonEmptySlots.length) {
          final slot = nonEmptySlots[i];
          return _buildSlotCard(slot, groups[slot]!);
        }

        // Inactive section
        if (inactiveMeds.isNotEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Row(
                  children: [
                    const Icon(LucideIcons.archive,
                        size: 18, color: Colors.grey),
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
              ),
              ...inactiveMeds.map((m) => _buildInactiveMedicineCard(m)),
            ],
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSlotCard(String slot, List<Medicine> meds) {
    final slotConfig = _slotCardConfig(slot);
    final isExpanded = _expandedSlots.contains(slot);
    final timeRange = _slotTimeRange(slot);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // ── Card Header ──
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() {
              isExpanded
                  ? _expandedSlots.remove(slot)
                  : _expandedSlots.add(slot);
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: slotConfig['color'].withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(slotConfig['icon'],
                        size: 20, color: slotConfig['color']),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              slotConfig['label'],
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: slotConfig['color'].withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${meds.length} medicine${meds.length > 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: slotConfig['color'],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (timeRange.isNotEmpty)
                          Text(
                            timeRange,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(LucideIcons.chevronDown,
                        size: 20, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ).asGlass(context: context, color: slotConfig['color'].withValues(alpha: 0.05)),


          // ── Medicine List ──
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: meds.map((med) {
                  final isPrimarySlot =
                      med.slotTypes.isEmpty || med.slotTypes.first == slot;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child:
                        _buildMedicineCard(med, isPrimarySlot: isPrimarySlot),
                  );
                }).toList(),
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _slotCardConfig(String slot) {
    switch (slot) {
      case 'morning':
        return {
          'icon': LucideIcons.sunrise,
          'label': 'Morning',
          'color': AppTheme.orangeAccent
        };
      case 'afternoon':
        return {
          'icon': LucideIcons.sun,
          'label': 'Afternoon',
          'color': AppTheme.emeraldAccent
        };
      case 'evening':
        return {
          'icon': LucideIcons.sunset,
          'label': 'Evening',
          'color': AppTheme.purpleAccent
        };
      case 'night':
        return {
          'icon': LucideIcons.moon,
          'label': 'Night',
          'color': AppTheme.cyanAccent
        };
      case 'custom':
        return {
          'icon': LucideIcons.clock,
          'label': 'Custom',
          'color': AppTheme.textSecondary
        };
      default:
        return {'icon': LucideIcons.clock, 'label': slot, 'color': AppTheme.textSecondary};
    }
  }

  String _slotTimeRange(String slot) {
    final startKey = '${slot}_start';
    final endKey = '${slot}_end';
    final start = _slotPrefs[startKey];
    final end = _slotPrefs[endKey];
    if (start == null || end == null) return '';
    return '${_formatTimeTo12(start)} – ${_formatTimeTo12(end)}';
  }

  String _formatTimeTo12(String time24) {
    final parts = time24.split(':');
    if (parts.length != 2) return time24;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$hour12:${m.toString().padLeft(2, '0')} $period';
  }

  // HATAO purana method, LAGAO yeh:
  String _formatMedicineChipTime(String timeStr, BuildContext context) {
    try {
      final trimmed = timeStr.trim();
      // Try 12-hour format
      if (trimmed.contains('AM') || trimmed.contains('PM')) {
        final dt = DateFormat('hh:mm a').parseStrict(trimmed);
        return TimeOfDay.fromDateTime(dt).format(context);
      }
      // Try 24-hour format (also handles "08:00:00")
      final parts = trimmed.split(':');
      if (parts.length >= 2) {
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        return TimeOfDay(hour: h, minute: m).format(context);
      }
      return trimmed;
    } catch (_) {
      return timeStr;
    }
  }

  Widget _buildMedicineCard(Medicine med, {bool isPrimarySlot = true}) {
    return MedicineCard(
      med: med,
      isExpanded: _expandedMedId == med.id,
      onDelete: () => _deleteMedication(med),
      onToggleExpand: () => setState(
          () => _expandedMedId = _expandedMedId == med.id ? null : med.id),
      onShowOptions: () => _showMedicineOptions(med),
      onRefill: () => _showRefillDialog(med),
      onUpdateQty: (delta) => _updateQty(med, delta),
      slotPrefs: _slotPrefs,
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
                    width: 60,
                    height: 60,
                    color: Colors.grey[200],
                    child: med.imagePath != null &&
                            File(med.imagePath!).existsSync()
                        ? Image.file(File(med.imagePath!),
                            fit: BoxFit.cover,
                            color: Colors.grey,
                            colorBlendMode: BlendMode.saturation)
                        : Icon(LucideIcons.pill,
                            color: Colors.grey[400], size: 28),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.name,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Stock: ${med.qty} | ${med.frequency}x/day",
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(10)),
                  child: Text("Tap to Refill",
                      style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
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
            padding: const EdgeInsets.all(24),
            decoration:
                BoxDecoration(color: AppTheme.cyanAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(LucideIcons.pill,
                size: 60, color: AppTheme.cyanAccent),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true)).scaleXY(end: 1.1, duration: 2.seconds),
          const SizedBox(height: 32),
          Text("No medications yet",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text(
              "Keep track of your family's health\nby adding their medications here.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
        ],
      ).animate().fade(duration: 500.ms).slideY(begin: 0.2),
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
                desc:
                    "Set to 'Unrestricted' in Settings > Apps > FamCare > Battery.",
              ),
              _buildGuideItem(
                icon: LucideIcons.layers,
                title: "Display over apps",
                desc:
                    "Allow this for the alarm to appear when your phone is locked.",
              ),
              _buildGuideItem(
                icon: LucideIcons.zap,
                title: "Auto-start",
                desc:
                    "Common on Xiaomi/Oppo/Vivo devices. Enable in app settings.",
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9))),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideItem(
      {required IconData icon, required String title, required String desc}) {
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
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(desc,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
      if (parts.length < 2) return null;
      final tParts = parts[0].split(':');
      if (tParts.length < 2) return null;
      final hour = int.tryParse(tParts[0]);
      final min = int.tryParse(tParts[1]);
      if (hour == null || min == null) return null;
      int h = hour;
      if (parts[1] == 'PM' && h < 12) h += 12;
      if (parts[1] == 'AM' && h == 12) h = 0;
      return TimeOfDay(hour: h, minute: min);
    } catch (_) {
      return null;
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m = tod.minute.toString().padLeft(2, '0');
    final p = tod.period == DayPeriod.am ? "AM" : "PM";
    return "${h.toString().padLeft(2, '0')}:$m $p";
  }

  Future<ImageSource?> _showImageSourceSheet(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select Image Source",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildSourceOption(
                      ctx, LucideIcons.camera, "Camera", ImageSource.camera),
                  _buildSourceOption(
                      ctx, LucideIcons.image, "Gallery", ImageSource.gallery),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSourceOption(
      BuildContext context, IconData icon, String label, ImageSource source) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, source),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withOpacity(0.1),
                shape: BoxShape.circle),
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
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(15),
          border:
              Border.all(color: Colors.grey[300]!, style: BorderStyle.solid)),
      child: image != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.file(image, fit: BoxFit.cover))
          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(LucideIcons.camera, color: Colors.grey[400], size: 40),
              const SizedBox(height: 8),
              Text("Add Medication Photo",
                  style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              Text("(Optional)",
                  style: TextStyle(color: Colors.grey[400], fontSize: 11)),
            ]),
    );
  }
}
