import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../models/medicine_model.dart';

class AddMedicineBottomSheet extends StatefulWidget {
  final Medicine? existingMed;
  final Future<void> Function({
    required BuildContext dialogContext,
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
  }) onSave;

  const AddMedicineBottomSheet({super.key, this.existingMed, required this.onSave});

  @override
  State<AddMedicineBottomSheet> createState() => _AddMedicineBottomSheetState();
}

class _AddMedicineBottomSheetState extends State<AddMedicineBottomSheet> {
  late TextEditingController nameController;
  late TextEditingController dosageController;
  late TextEditingController durationController;
  late TextEditingController qtyController;
  late TextEditingController notesController;
  late TextEditingController everyXDaysController;

  List<String> selectedSlots = [];
  List<TimeOfDay> customAlarmTimes = [];
  String scheduleType = 'daily';
  List<String> specificDates = [];
  DateTime startDate = DateTime.now();
  File? selectedImage;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final m = widget.existingMed;
    nameController = TextEditingController(text: m?.name);
    dosageController = TextEditingController(text: m?.dosage ?? "1 tablet");
    durationController = TextEditingController(text: (m?.durationDays ?? 7).toString());
    qtyController = TextEditingController(text: (m?.qty ?? 7).toString());
    notesController = TextEditingController(text: m?.notes ?? '');
    everyXDaysController = TextEditingController(text: (m?.everyXDays ?? 1).toString());

    selectedSlots = List.from(m?.slotTypes ?? []);
    if (selectedSlots.isEmpty && m != null) {
      if (m.frequency >= 1) selectedSlots.add('morning');
      if (m.frequency >= 2) selectedSlots.add('afternoon');
      if (m.frequency >= 3) selectedSlots.add('night');
    }

    customAlarmTimes = (m?.customTimes ?? []).map((t) => _parseTime(t)).whereType<TimeOfDay>().toList();
    scheduleType = m?.scheduleType ?? 'daily';
    specificDates = List.from(m?.specificDates ?? []);
    startDate = m?.startDate ?? DateTime.now();

    _loadExistingImage();
  }

  Future<void> _loadExistingImage() async {
    final path = widget.existingMed?.imagePath;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (await file.exists()) {
        setState(() => selectedImage = file);
      }
    }
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null) return null;
    try {
      final parts = timeStr.split(':');
      if (parts.length < 2) return null;
      final hour = int.tryParse(parts[0]);
      final min = int.tryParse(parts[1].split(' ')[0]);
      if (hour == null || min == null) return null;
      return TimeOfDay(hour: hour, minute: min);
    } catch (_) { return null; }
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

  @override
  Widget build(BuildContext context) {
    final durDays = int.tryParse(durationController.text) ?? 1;
    final everyX = max(1, int.tryParse(everyXDaysController.text) ?? 1);
    DateTime endDate;
    if (scheduleType == 'specific_dates' && specificDates.isNotEmpty) {
      endDate = DateTime.parse(specificDates.last);
    } else if (scheduleType == 'every_x_days') {
      final doses = (durDays / everyX).ceil();
      final totalDays = doses > 0 ? (doses - 1) * everyX : 0;
      endDate = startDate.add(Duration(days: totalDays));
    } else {
      endDate = startDate.add(Duration(days: durDays)).subtract(const Duration(days: 1));
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      title: Text(widget.existingMed == null ? "Add Medicine" : "Edit Medicine",
          style: const TextStyle(fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () async {
                  final source = await _showImageSourceSheet(context);
                  if (source != null) {
                    final image = await _imagePicker.pickImage(source: source, imageQuality: 50);
                    if (image != null) setState(() => selectedImage = File(image.path));
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
                child: Text("When to take", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSlotChip('morning', 'Morning', LucideIcons.sunrise),
                  _buildSlotChip('afternoon', 'Afternoon', LucideIcons.sun),
                  _buildSlotChip('evening', 'Evening', LucideIcons.sunset),
                  _buildSlotChip('night', 'Night', LucideIcons.moon),
                  _buildSlotChip('custom', 'Custom', LucideIcons.clock),
                ],
              ),
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
                                  onTap: () => setState(() {
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
                            final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                            if (picked != null) {
                              setState(() {
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
              const SizedBox(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Schedule", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 4),
              _buildScheduleRadio(
                value: 'daily',
                groupValue: scheduleType,
                label: 'Daily (take every day)',
                onChanged: (val) => setState(() {
                  scheduleType = val!;
                  recalcQty();
                }),
              ),
              _buildScheduleRadio(
                value: 'every_x_days',
                groupValue: scheduleType,
                label: 'Every X days',
                onChanged: (val) => setState(() {
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
                          onChanged: (_) => setState(() => recalcQty()),
                        ),
                      )
                    : null,
              ),
              _buildScheduleRadio(
                value: 'specific_dates',
                groupValue: scheduleType,
                label: 'Specific dates',
                onChanged: (val) => setState(() {
                  scheduleType = val!;
                  recalcQty();
                }),
                trailing: scheduleType == 'specific_dates'
                    ? IconButton(
                        icon: const Icon(LucideIcons.calendar, size: 20, color: Color(0xFF0EA5E9)),
                        onPressed: () async {
                          await _showMultiDatePicker();
                        },
                      )
                    : null,
              ),
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
                      onDeleted: () => setState(() {
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
                        onChanged: (_) => setState(() => recalcQty()),
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
                    context: context,
                    initialDate: startDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365))
                  );
                  if (date != null) setState(() => startDate = date);
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
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: selectedSlots.isEmpty ? Colors.grey : const Color(0xFF0EA5E9),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: selectedSlots.isEmpty ? null : () => widget.onSave(
            dialogContext: context,
            existingMed: widget.existingMed,
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
  }

  Widget _buildSlotChip(String value, String label, IconData icon) {
    final isSelected = selectedSlots.contains(value);
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
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? const Color(0xFF0EA5E9) : Colors.grey[300]!),
      ),
      onSelected: (val) {
        setState(() {
          if (val) {
            selectedSlots.add(value);
          } else {
            selectedSlots.remove(value);
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

  Future<void> _showMultiDatePicker() async {
    final selected = specificDates.map((d) => DateTime.parse(d)).toSet();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, sheetState) {
          final dates = List.generate(90, (i) => DateTime.now().add(Duration(days: i)));
          return DraggableScrollableSheet(
            initialChildSize: 0.6, maxChildSize: 0.9, minChildSize: 0.4, expand: false,
            builder: (_, scrollCtrl) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text('Select Dates', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      Text('${selected.length} selected', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4, childAspectRatio: 1,
                    ),
                    itemCount: dates.length,
                    itemBuilder: (_, i) {
                      final date = dates[i];
                      final isSelected = selected.any((s) => s.year == date.year && s.month == date.month && s.day == date.day);
                      final isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;
                      return GestureDetector(
                        onTap: () => sheetState(() {
                          if (isSelected) {
                            selected.removeWhere((s) => s.year == date.year && s.month == date.month && s.day == date.day);
                          } else {
                            selected.add(DateTime(date.year, date.month, date.day));
                          }
                        }),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF0EA5E9) : isToday ? Colors.blue[50] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: isToday ? Border.all(color: const Color(0xFF0EA5E9)) : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(DateFormat('d').format(date), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.black87)),
                              Text(DateFormat('MMM').format(date), style: TextStyle(fontSize: 9, color: isSelected ? Colors.white70 : Colors.grey[600])),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selected.isEmpty ? null : () {
                        final sorted = selected.toList()..sort();
                        setState(() {
                          specificDates.clear();
                          specificDates.addAll(sorted.map((d) => DateFormat('yyyy-MM-dd').format(d)));
                          recalcQty();
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: Text(selected.isEmpty ? 'Select dates' : 'Confirm ${selected.length} dates'),
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
