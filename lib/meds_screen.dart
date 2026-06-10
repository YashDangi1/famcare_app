import 'dart:math';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
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

  // Slot-based grouping
  Map<String, dynamic> _slotPrefs = {};
  final Set<String> _expandedSlots = {'morning', 'afternoon', 'evening', 'night', 'custom'};

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

      // Load slot preferences for card headers
      final slotPrefs = await SlotPreferencesService().getPreferences();

      // Cache image existence to avoid sync I/O in build()
      final List<Medicine> meds = (data as List).map((m) => Medicine.fromJson(m)).toList();
      final Set<String> existingPaths = {};
      for (final m in meds) {
        if (m.imagePath != null && m.imagePath!.isNotEmpty && await File(m.imagePath!).exists()) {
          existingPaths.add(m.imagePath!);
        }
      }

      if (mounted) {
        setState(() {
          _medications = meds;
          _slotPrefs = slotPrefs;
          _existingImagePaths.clear();
          _existingImagePaths.addAll(existingPaths);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Fetch Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // ➕ ADD/EDIT MEDICINE DIALOG (Redesigned)
  // ==========================================
  Future<void> _showAddEditDialog({Medicine? existingMed}) async {
    final nameController = TextEditingController(text: existingMed?.name);
    final dosageController = TextEditingController(text: existingMed?.dosage ?? "1 tablet");
    final durationController = TextEditingController(text: (existingMed?.durationDays ?? 7).toString());
    final qtyController = TextEditingController(text: (existingMed?.qty ?? 7).toString());
    final notesController = TextEditingController(text: existingMed?.notes ?? '');
    final everyXDaysController = TextEditingController(text: (existingMed?.everyXDays ?? 1).toString());

    // 4A — Slot selector state
    List<String> selectedSlots = List.from(existingMed?.slotTypes ?? []);
    if (selectedSlots.isEmpty && existingMed != null) {
      // Migration: infer from old frequency
      if (existingMed.frequency >= 1) selectedSlots.add('morning');
      if (existingMed.frequency >= 2) selectedSlots.add('afternoon');
      if (existingMed.frequency >= 3) selectedSlots.add('night');
    }

    // 4B — Custom times state
    List<TimeOfDay> customAlarmTimes = (existingMed?.customTimes ?? [])
        .map((t) => _parseTime(t))
        .whereType<TimeOfDay>()
        .toList();

    // 4C — Schedule type state
    String scheduleType = existingMed?.scheduleType ?? 'daily';
    List<String> specificDates = List.from(existingMed?.specificDates ?? []);

    DateTime startDate = existingMed?.startDate ?? DateTime.now();
    File? selectedImage;
    if (existingMed?.imagePath != null && await File(existingMed!.imagePath!).exists()) {
      selectedImage = File(existingMed.imagePath!);
    }

    void recalcQty() {
      final standardSlotCount = selectedSlots.where((s) => s != 'custom').length;
      final customSlotCount = selectedSlots.contains('custom') ? customAlarmTimes.length : 0;
      final slotCount = (standardSlotCount + customSlotCount).clamp(1, 999);
      final dur = int.tryParse(durationController.text) ?? 1;
      final everyX = max(1, int.tryParse(everyXDaysController.text) ?? 1);
      int qty;
      if (scheduleType == 'specific_dates') {
        qty = slotCount * specificDates.length;
      } else if (scheduleType == 'every_x_days') {
        qty = slotCount * (dur / everyX).ceil();
      } else {
        qty = slotCount * dur;
      }
      qtyController.text = qty.toString();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final durDays = int.tryParse(durationController.text) ?? 1;
          final everyX = max(1, int.tryParse(everyXDaysController.text) ?? 1);
          DateTime endDate;
          if (scheduleType == 'specific_dates' && specificDates.isNotEmpty) {
            endDate = DateTime.parse(specificDates.last);
          } else if (scheduleType == 'every_x_days') {
            // Number of "every X days" doses that fit in the duration window,
            // then add the final gap so the last dose falls inside the window.
            final doses = (durDays / everyX).ceil();
            final totalDays = doses > 0 ? (doses - 1) * everyX : 0;
            endDate = startDate.add(Duration(days: totalDays));
          } else {
            endDate = startDate.add(Duration(days: durDays)).subtract(const Duration(days: 1));
          }

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
                    // ── Image Picker ──
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

                    // ── Name ──
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

                    // ── Dosage ──
                    TextField(
                      controller: dosageController,
                      decoration: const InputDecoration(
                        labelText: "Dosage (e.g. 1 tablet)",
                        prefixIcon: Icon(LucideIcons.scale),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      )
                    ),

                    // ══════════════════════════════════
                    // 4A — SLOT SELECTOR
                    // ══════════════════════════════════
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("When to take", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildSlotChip('morning', 'Morning', LucideIcons.sunrise, selectedSlots, setDialogState, recalcQty),
                        _buildSlotChip('afternoon', 'Afternoon', LucideIcons.sun, selectedSlots, setDialogState, recalcQty),
                        _buildSlotChip('evening', 'Evening', LucideIcons.sunset, selectedSlots, setDialogState, recalcQty),
                        _buildSlotChip('night', 'Night', LucideIcons.moon, selectedSlots, setDialogState, recalcQty),
                        _buildSlotChip('custom', 'Custom', LucideIcons.clock, selectedSlots, setDialogState, recalcQty),
                      ],
                    ),

                    // ══════════════════════════════════
                    // 4B — CUSTOM TIME PICKER
                    // ══════════════════════════════════
                    if (selectedSlots.contains('custom')) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[100]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Custom Times", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 8),
                            ...customAlarmTimes.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final tod = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(LucideIcons.clock, size: 16, color: Color(0xFF0EA5E9)),
                                      const SizedBox(width: 8),
                                      Text(tod.format(context), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                      const Spacer(),
                                      GestureDetector(
                                        onTap: () => setDialogState(() {
                                          customAlarmTimes.removeAt(idx);
                                          recalcQty();
                                        }),
                                        child: const Icon(LucideIcons.x, size: 18, color: Colors.redAccent),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await showTimePicker(context: dialogContext, initialTime: TimeOfDay.now());
                                  if (picked != null) {
                                    setDialogState(() {
                                      customAlarmTimes.add(picked);
                                      recalcQty();
                                    });
                                  }
                                },
                                icon: const Icon(LucideIcons.plus, size: 16),
                                label: const Text("Add Time"),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ══════════════════════════════════
                    // 4C — SCHEDULE TYPE SELECTOR
                    // ══════════════════════════════════
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text("Schedule", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(height: 4),
                    // Daily
                    _buildScheduleRadio(
                      value: 'daily',
                      groupValue: scheduleType,
                      label: 'Daily (take every day)',
                      onChanged: (val) => setDialogState(() {
                        scheduleType = val!;
                        recalcQty();
                      }),
                    ),
                    // Every X days
                    _buildScheduleRadio(
                      value: 'every_x_days',
                      groupValue: scheduleType,
                      label: 'Every X days',
                      onChanged: (val) => setDialogState(() {
                        scheduleType = val!;
                        recalcQty();
                      }),
                      trailing: scheduleType == 'every_x_days'
                          ? SizedBox(
                              width: 60,
                              height: 36,
                              child: TextFormField(
                                controller: everyXDaysController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 14),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  isDense: true,
                                ),
                                validator: (v) {
                                  final n = int.tryParse(v ?? '');
                                  if (n == null || n <= 0) return 'Must be 1 or more';
                                  return null;
                                },
                                onChanged: (_) => setDialogState(() => recalcQty()),
                              ),
                            )
                          : null,
                    ),
                    // Specific dates
                    _buildScheduleRadio(
                      value: 'specific_dates',
                      groupValue: scheduleType,
                      label: 'Specific dates',
                      onChanged: (val) => setDialogState(() {
                        scheduleType = val!;
                        recalcQty();
                      }),
                      trailing: scheduleType == 'specific_dates'
                          ? IconButton(
                              icon: const Icon(LucideIcons.calendar, size: 20, color: Color(0xFF0EA5E9)),
                              onPressed: () async {
                                await _showMultiDatePicker(
                                  dialogContext,
                                  specificDates,
                                  setDialogState,
                                  recalcQty,
                                );
                              },
                            )
                          : null,
                    ),
                    // Show selected dates as chips
                    if (scheduleType == 'specific_dates' && specificDates.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: specificDates.map((d) {
                          final display = DateFormat('dd MMM').format(DateTime.parse(d));
                          return Chip(
                            label: Text(display, style: const TextStyle(fontSize: 12)),
                            deleteIcon: const Icon(LucideIcons.x, size: 14),
                            onDeleted: () => setDialogState(() {
                              specificDates.remove(d);
                              recalcQty();
                            }),
                            backgroundColor: Colors.blue[50],
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          );
                        }).toList(),
                      ),
                    ],

                    // ── Duration (for daily and every_x_days) ──
                    if (scheduleType != 'specific_dates') ...[
                      const SizedBox(height: 12),
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
                              onChanged: (_) => setDialogState(() => recalcQty()),
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
                    ] else ...[
                      // Specific dates: show auto-calculated qty
                      const SizedBox(height: 12),
                      TextField(
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Total Qty (auto-calculated)",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        )
                      ),
                    ],

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
                    if (scheduleType != 'specific_dates')
                      Container(
                        padding: const EdgeInsets.all(10),
                        width: double.infinity,
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                        child: Text("Auto-calculated End Date: ${DateFormat('dd MMM yyyy').format(endDate)}",
                          style: const TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),

                    // ══════════════════════════════════
                    // 4D — NOTES FIELD
                    // ══════════════════════════════════
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: "Doctor's instructions (optional)",
                        hintText: "e.g. Take after meals, with water",
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: const Icon(LucideIcons.fileText, size: 20),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
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
                  backgroundColor: selectedSlots.isEmpty ? Colors.grey : const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: selectedSlots.isEmpty ? null : () => _handleSave(
                  dialogContext: dialogContext,
                  existingMed: existingMed,
                  name: nameController.text,
                  dosage: dosageController.text,
                  selectedSlots: selectedSlots,
                  customAlarmTimes: customAlarmTimes,
                  scheduleType: scheduleType,
                  everyXDays: int.tryParse(everyXDaysController.text) ?? 1,
                  specificDates: specificDates,
                  notes: notesController.text,
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

  Widget _buildSlotChip(String value, String label, IconData icon, List<String> selected,
      StateSetter setDialogState, VoidCallback recalcQty) {
    final isSelected = selected.contains(value);
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFF0EA5E9)),
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
          final dates = List.generate(90, (i) => DateTime.now().add(Duration(days: i)));

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
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      _quickSelectChip('Today', [DateTime.now()], selected, sheetState),
                      _quickSelectChip(
                        'This week',
                        List.generate(7, (i) => DateTime.now().add(Duration(days: i))),
                        selected,
                        sheetState,
                      ),
                      _quickSelectChip(
                        'Next 30 days',
                        List.generate(30, (i) => DateTime.now().add(Duration(days: i))),
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      childAspectRatio: 1,
                    ),
                    itemCount: dates.length,
                    itemBuilder: (_, i) {
                      final date = dates[i];
                      final isSelected = selected.any((s) => _isSameDate(s, date));
                      final isToday = _isSameDate(date, DateTime.now());
                      return GestureDetector(
                        onTap: () {
                          sheetState(() {
                            if (isSelected) {
                              selected.removeWhere((s) => _isSameDate(s, date));
                            } else {
                              selected.add(DateTime(date.year, date.month, date.day));
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
                                  color: isSelected ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                DateFormat('MMM').format(date),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isSelected ? Colors.white70 : Colors.grey[600],
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
                                  ..addAll(sorted.map((d) => DateFormat('yyyy-MM-dd').format(d)));
                                recalcQty();
                              });
                              Navigator.pop(ctx);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        selected.isEmpty ? 'Select dates' : 'Confirm ${selected.length} dates',
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
    BuildContext? dialogContext,
    Medicine? existingMed,
    required String name,
    required String dosage,
    required List<String> selectedSlots,
    required List<TimeOfDay> customAlarmTimes,
    required String scheduleType,
    required int everyXDays,
    required List<String> specificDates,
    required String notes,
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

    if (selectedSlots.isEmpty) {
      AppSnackBar.showError(context, "Select at least one time slot");
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


      final durationDays = scheduleType == 'specific_dates' ? specificDates.length : dur;
      DateTime end;
      if (scheduleType == 'specific_dates' && specificDates.isNotEmpty) {
        end = DateTime.parse(specificDates.last);
      } else {
        end = start.add(Duration(days: durationDays - 1));
      }
      final medData = {
        'user_id': userId,
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'time1': time1,
        'time2': time2,
        'time3': time3,
        'alarm_id1': null,
        'alarm_id2': null,
        'alarm_id3': null,
        'start_date': start.toIso8601String().split('T')[0],
        'end_date': end.toIso8601String().split('T')[0],
        'duration_days': durationDays,
        'qty': qty,
        'counter': existingMed?.counter ?? 0,
        'is_active': true,
        'is_taken': existingMed?.isTaken ?? false,
        'image_path': imagePath,
        'slot_types': selectedSlots,
        'custom_times': customAlarmTimes.map((t) {
          final h = t.hour.toString().padLeft(2, '0');
          final m = t.minute.toString().padLeft(2, '0');
          return '$h:$m'; // "08:00" — 24hr, locale-independent
        }).toList(),
        'schedule_type': scheduleType,
        'every_x_days': everyXDays,
        'specific_dates': specificDates,
        'notes': notes,
        'is_paused': existingMed?.isPaused ?? false,
        'low_stock_alerted': existingMed?.lowStockAlerted ?? false,
        'group_alarm_ids': {},
      };

      String realMedId;
      if (existingMed?.id != null) {
        await _supabase.from('medications').update(medData).eq('id', existingMed!.id!);
        realMedId = existingMed.id!;
      } else {
        final response = await _supabase
            .from('medications')
            .insert(medData)
            .select('id')
            .maybeSingle();
        if (response == null) {
          throw Exception('Save failed — please retry');
        }
        realMedId = response['id']?.toString() ?? '';
        if (realMedId.isEmpty) {
          throw Exception('Save returned no ID');
        }
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
        for (final slot in existingMed.slotTypes) {
          if (slot == 'custom') {
            for (int i = 0; i < existingMed.customTimes.length; i++) {
              await _alarmService.cancelSlotAlarms('custom_${existingMed.id}_$i');
            }
          } else {
            await _alarmService.cancelSlotAlarms(slot);
          }
        }
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
      debugPrint('Medicine saved with ID=$realMedId; group alarm reschedule requested');
    } catch (e) {
      debugPrint("Save Error: $e");
      if (mounted) AppSnackBar.showError(context, "Failed to save: $e");
    } finally {
      _isSaving = false;
    }
  }

  String _defaultSlotStart(String slot) {
    switch (slot) {
      case 'morning': return '08:00';
      case 'afternoon': return '12:00';
      case 'evening': return '16:00';
      case 'night': return '21:00';
      default: return '08:00';
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
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
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
              title: const Text('Delete Medicine', style: TextStyle(color: Colors.red)),
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
      await _supabase
          .from('medications')
          .update({'is_paused': newPaused})
          .eq('id', med.id!);

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

      _fetchMedications();
    } catch (e) {
      debugPrint('Pause toggle error: $e');
      AppSnackBar.showError(context, "Failed to ${newPaused ? 'pause' : 'resume'} medicine");
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
                  : _buildGroupedSlotView(),
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

  Widget _buildGroupedSlotView() {
    final activeMeds = _medications.where((m) => m.isActive).toList();
    final inactiveMeds = _medications.where((m) => !m.isActive).toList();
    final groups = _groupMedicinesBySlot(activeMeds);

    final slotOrder = ['morning', 'afternoon', 'evening', 'night', 'custom'];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: slotOrder.where((s) => groups[s]!.isNotEmpty).length
          + (inactiveMeds.isNotEmpty ? 1 : 0),
      itemBuilder: (ctx, i) {
        // Filter to non-empty slots
        final nonEmptySlots = slotOrder.where((s) => groups[s]!.isNotEmpty).toList();

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
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: slotConfig['color'].withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: slotConfig['color'].withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Card Header ──
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() {
              isExpanded ? _expandedSlots.remove(slot) : _expandedSlots.add(slot);
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: slotConfig['color'].withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(slotConfig['icon'], size: 20, color: slotConfig['color']),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              slotConfig['label'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: slotConfig['color'].withOpacity(0.12),
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
                            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(LucideIcons.chevronDown, size: 20, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          ),

          // ── Medicine List ──
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: meds.map((med) {
                  final isPrimarySlot = med.slotTypes.isEmpty || med.slotTypes.first == slot;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildMedicineCard(med, isPrimarySlot: isPrimarySlot),
                  );
                }).toList(),
              ),
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _slotCardConfig(String slot) {
    switch (slot) {
      case 'morning':
        return {'icon': LucideIcons.sunrise, 'label': 'Morning', 'color': const Color(0xFFF59E0B)};
      case 'afternoon':
        return {'icon': LucideIcons.sun, 'label': 'Afternoon', 'color': const Color(0xFFF97316)};
      case 'evening':
        return {'icon': LucideIcons.sunset, 'label': 'Evening', 'color': const Color(0xFF8B5CF6)};
      case 'night':
        return {'icon': LucideIcons.moon, 'label': 'Night', 'color': const Color(0xFF3B82F6)};
      case 'custom':
        return {'icon': LucideIcons.clock, 'label': 'Custom', 'color': const Color(0xFF10B981)};
      default:
        return {'icon': LucideIcons.clock, 'label': slot, 'color': Colors.grey};
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
      return DateFormat('hh:mm a').format(dt);
    }
    // Try 24-hour format
    final parts = trimmed.split(':');
    if (parts.length >= 2) {
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final dt = DateTime(2000, 1, 1, h, m);
      return DateFormat('hh:mm a').format(dt);
    }
    return trimmed;
  } catch (_) {
    // Strip seconds if present (e.g. "08:00:00" → "08:00 AM")
    final stripped = timeStr.replaceAll(RegExp(r':\d{2}$'), '').trim();
    try {
      final parts = stripped.split(':');
      if (parts.length == 2) {
        final dt = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
        return DateFormat('hh:mm a').format(dt);
      }
    } catch (_) {}
    return timeStr; // Last resort
  }
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
      child: Opacity(
        opacity: med.isPaused ? 0.5 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ===== 1. ORIGINAL CARD CONTENT (untouched) =====
              InkWell(
              borderRadius: BorderRadius.circular(20),
              onLongPress: () => _showMedicineOptions(med),
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
                          // ignore: avoid_slow_async_io — inside build, sync required
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
                              if (med.isPaused)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text("Paused",
                                    style: TextStyle(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              const SizedBox(width: 6),
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
                                  Text(
                                    _formatMedicineChipTime(t, context),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold),
                                  ),
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
    } catch (_) { return null; }
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
