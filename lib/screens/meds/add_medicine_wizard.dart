import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../models/medicine_model.dart';
import '../../../theme/app_theme.dart';

class AddMedicineWizard extends StatefulWidget {
  final Medicine? existingMed;
  final Future<void> Function({
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
  }) onSave;

  const AddMedicineWizard({super.key, this.existingMed, required this.onSave});

  @override
  State<AddMedicineWizard> createState() => _AddMedicineWizardState();
}

class _AddMedicineWizardState extends State<AddMedicineWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 4;

  // Step 1: Basics
  late TextEditingController nameController;
  late TextEditingController conditionController;
  String? selectedForm = 'Pill';
  String? selectedColor = 'White';
  File? selectedImage;
  final _imagePicker = ImagePicker();

  // Step 2: Dosage
  late TextEditingController strengthController;
  String? strengthUnit = 'mg';
  late TextEditingController takeAmountController;
  String? foodInstruction;
  bool isAsNeeded = false;

  // Step 3: Schedule
  String scheduleType = 'daily';
  List<String> specificDates = [];
  late TextEditingController everyXDaysController;
  List<String> selectedSlots = [];
  List<TimeOfDay> customAlarmTimes = [];
  DateTime startDate = DateTime.now();

  // Step 4: Inventory
  late TextEditingController durationController;
  late TextEditingController qtyController;
  late TextEditingController refillReminderController;
  late TextEditingController notesController;

  final List<String> forms = ['Pill', 'Capsule', 'Liquid', 'Drops', 'Inhaler', 'Injection', 'Patch', 'Ointment'];
  final List<String> colors = ['White', 'Red', 'Blue', 'Green', 'Yellow', 'Pink', 'Orange', 'Purple'];
  final List<String> units = ['mg', 'mcg', 'g', 'ml', '%', 'drops', 'puffs'];

  Map<String, Color> colorMap = {
    'White': Colors.white,
    'Red': Colors.redAccent,
    'Blue': Colors.blueAccent,
    'Green': Colors.green,
    'Yellow': Colors.amber,
    'Pink': Colors.pinkAccent,
    'Orange': Colors.orangeAccent,
    'Purple': Colors.purpleAccent,
  };

  @override
  void initState() {
    super.initState();
    final m = widget.existingMed;
    
    nameController = TextEditingController(text: m?.name);
    conditionController = TextEditingController(text: m?.condition ?? '');
    selectedForm = m?.form ?? 'Pill';
    selectedColor = m?.color ?? 'White';
    _loadExistingImage();

    strengthController = TextEditingController(text: m?.strength?.toString() ?? '');
    strengthUnit = m?.strengthUnit ?? 'mg';
    takeAmountController = TextEditingController(text: m?.takeAmount ?? '1');
    foodInstruction = m?.foodInstruction;
    isAsNeeded = m?.isAsNeeded ?? false;

    scheduleType = m?.scheduleType ?? 'daily';
    specificDates = List.from(m?.specificDates ?? []);
    everyXDaysController = TextEditingController(text: (m?.everyXDays ?? 1).toString());
    selectedSlots = List.from(m?.slotTypes ?? []);
    if (selectedSlots.isEmpty && m != null) {
      if (m.frequency >= 1) selectedSlots.add('morning');
      if (m.frequency >= 2) selectedSlots.add('afternoon');
      if (m.frequency >= 3) selectedSlots.add('night');
    }
    customAlarmTimes = (m?.customTimes ?? []).map((t) => _parseTime(t)).whereType<TimeOfDay>().toList();
    startDate = m?.startDate ?? DateTime.now();

    durationController = TextEditingController(text: (m?.durationDays ?? 7).toString());
    qtyController = TextEditingController(text: (m?.qty ?? 7).toString());
    refillReminderController = TextEditingController(text: m?.refillReminderThreshold?.toString() ?? '');
    notesController = TextEditingController(text: m?.notes ?? '');
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
    
    // For PRN medications, let the user define qty without auto calc.
    if (isAsNeeded) return;

    int qty;
    if (scheduleType == 'specific_dates') {
      qty = slotCount * specificDates.length;
    } else if (scheduleType == 'every_x_days') {
      qty = slotCount * (dur / everyX).ceil();
    } else {
      qty = slotCount * dur;
    }
    
    // Multiply by take amount if it's a simple number
    final takeAmt = double.tryParse(takeAmountController.text) ?? 1.0;
    qty = (qty * takeAmt).ceil();
    
    qtyController.text = qty.toString();
  }

  void _nextStep() {
    // Validation before moving next
    if (_currentStep == 0 && nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a medicine name')));
      return;
    }
    if (_currentStep == 2 && !isAsNeeded && selectedSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one time slot')));
      return;
    }

    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    } else {
      _save();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  void _save() {
    widget.onSave(
      dialogContext: context,
      existingMed: widget.existingMed,
      name: nameController.text,
      condition: conditionController.text,
      form: selectedForm,
      color: selectedColor,
      image: selectedImage,
      strength: double.tryParse(strengthController.text),
      strengthUnit: strengthUnit,
      takeAmount: takeAmountController.text,
      foodInstruction: foodInstruction,
      isAsNeeded: isAsNeeded,
      selectedSlots: selectedSlots,
      customAlarmTimes: customAlarmTimes,
      scheduleType: scheduleType,
      everyXDays: int.tryParse(everyXDaysController.text) ?? 1,
      specificDates: specificDates,
      notes: notesController.text,
      dur: int.tryParse(durationController.text) ?? 7,
      start: startDate,
      qty: int.tryParse(qtyController.text) ?? 0,
      refillReminderThreshold: int.tryParse(refillReminderController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.existingMed == null ? "Add Medicine" : "Edit Medicine"),
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(), // Disable swipe
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStep4(),
              ],
            ),
          ),
          _buildBottomNav(),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
        ]
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _prevStep,
              child: Text(_currentStep == 0 ? "Cancel" : "Back", style: const TextStyle(fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_currentStep == _totalSteps - 1 ? "Save" : "Next", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // STEP 1: Basics & Appearance
  // ==========================================
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Step 1 of 4", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Basics & Appearance", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          
          TextField(
            controller: nameController,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              labelText: "Medicine Name*",
              prefixIcon: const Icon(LucideIcons.pill),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            )
          ),
          const SizedBox(height: 16),
          TextField(
            controller: conditionController,
            decoration: InputDecoration(
              labelText: "Condition (e.g. Blood Pressure) - Optional",
              prefixIcon: const Icon(LucideIcons.activity),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            )
          ),
          const SizedBox(height: 24),
          
          const Text("Shape / Form", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: forms.map((f) => ChoiceChip(
              label: Text(f),
              selected: selectedForm == f,
              onSelected: (val) => setState(() => selectedForm = val ? f : selectedForm),
              selectedColor: AppTheme.primaryBlue.withOpacity(0.2),
            )).toList(),
          ),
          const SizedBox(height: 24),

          const Text("Color", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12, runSpacing: 12,
            children: colors.map((c) => GestureDetector(
              onTap: () => setState(() => selectedColor = c),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: colorMap[c],
                  shape: BoxShape.circle,
                  border: Border.all(color: selectedColor == c ? AppTheme.primaryBlue : Colors.grey[300]!, width: selectedColor == c ? 3 : 1),
                  boxShadow: [
                    if (selectedColor == c) BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.3), blurRadius: 8)
                  ]
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 24),
          
          GestureDetector(
            onTap: () async {
              final image = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 50);
              if (image != null) setState(() => selectedImage = File(image.path));
            },
            child: Container(
              height: 120, width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50], 
                borderRadius: BorderRadius.circular(15), 
                border: Border.all(color: Colors.grey[300]!)
              ),
              child: selectedImage != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(selectedImage!, fit: BoxFit.cover))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center, 
                      children: [
                        Icon(LucideIcons.camera, color: Colors.grey[400], size: 40),
                        const SizedBox(height: 8),
                        Text("Add Medication Photo", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      ]
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 2: Dosage & Instructions
  // ==========================================
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Step 2 of 4", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Dosage & Instructions", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: strengthController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "Strength",
                    hintText: "e.g. 500",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  )
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<String>(
                  value: strengthUnit,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (val) => setState(() => strengthUnit = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          TextField(
            controller: takeAmountController,
            decoration: InputDecoration(
              labelText: "Amount per dose",
              hintText: "e.g. 1 pill, 2 puffs",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => recalcQty(),
          ),
          const SizedBox(height: 24),

          const Text("Food Instructions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _foodChip('before_food', 'Before Food', LucideIcons.coffee),
              _foodChip('with_food', 'With Food', LucideIcons.utensils),
              _foodChip('after_food', 'After Food', LucideIcons.utensilsCrossed),
              _foodChip('no_matter', 'No Matter', LucideIcons.minusCircle),
            ],
          ),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange[200]!)
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Take as needed (PRN)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 4),
                      Text("For pain or symptom relief, not on a strict schedule.", style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                Switch(
                  value: isAsNeeded,
                  activeColor: AppTheme.orangeAccent,
                  onChanged: (val) {
                    setState(() {
                      isAsNeeded = val;
                      recalcQty();
                    });
                  },
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _foodChip(String value, String label, IconData icon) {
    final isSelected = foodInstruction == value;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.black87),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (val) => setState(() => foodInstruction = val ? value : null),
      selectedColor: AppTheme.primaryBlue,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
    );
  }

  // ==========================================
  // STEP 3: Schedule
  // ==========================================
  Widget _buildStep3() {
    if (isAsNeeded) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.calendarCheck, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 20),
              const Text("No Schedule Required", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text("You marked this medicine as 'Take as needed'. It won't have scheduled alarms, but you can log it anytime.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Step 3 of 4", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Schedule & Reminders", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          _buildScheduleRadio('daily', 'Daily (take every day)'),
          Row(
            children: [
              Expanded(child: _buildScheduleRadio('every_x_days', 'Every X days')),
              if (scheduleType == 'every_x_days')
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: everyXDaysController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                    onChanged: (_) => recalcQty(),
                  ),
                ),
            ],
          ),
          Row(
            children: [
              Expanded(child: _buildScheduleRadio('specific_dates', 'Specific dates')),
              if (scheduleType == 'specific_dates')
                IconButton(
                  icon: const Icon(LucideIcons.calendar, color: AppTheme.primaryBlue),
                  onPressed: () => _showMultiDatePicker(),
                )
            ],
          ),
          if (scheduleType == 'specific_dates' && specificDates.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 8),
              child: Wrap(
                spacing: 6, runSpacing: 6,
                children: specificDates.map((d) {
                  final display = DateFormat('dd MMM').format(DateTime.parse(d));
                  return Chip(
                    label: Text(display, style: const TextStyle(fontSize: 12)),
                    deleteIcon: const Icon(LucideIcons.x, size: 14),
                    onDeleted: () => setState(() {
                      specificDates.remove(d);
                      recalcQty();
                    }),
                  );
                }).toList(),
              ),
            ),
          
          const Divider(height: 48),
          
          const Text("When to take", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              _buildSlotChip('morning', 'Morning', LucideIcons.sunrise),
              _buildSlotChip('afternoon', 'Afternoon', LucideIcons.sun),
              _buildSlotChip('evening', 'Evening', LucideIcons.sunset),
              _buildSlotChip('night', 'Night', LucideIcons.moon),
              _buildSlotChip('custom', 'Custom', LucideIcons.clock),
            ],
          ),
          if (selectedSlots.contains('custom')) ...[
            const SizedBox(height: 16),
            ...customAlarmTimes.asMap().entries.map((entry) {
              return ListTile(
                title: Text(entry.value.format(context), style: const TextStyle(fontWeight: FontWeight.bold)),
                leading: const Icon(LucideIcons.clock, color: AppTheme.primaryBlue),
                trailing: IconButton(
                  icon: const Icon(LucideIcons.trash2, color: Colors.red),
                  onPressed: () => setState(() {
                    customAlarmTimes.removeAt(entry.key);
                    recalcQty();
                  }),
                ),
              );
            }),
            TextButton.icon(
              onPressed: () async {
                final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                if (picked != null) setState(() {
                  customAlarmTimes.add(picked);
                  recalcQty();
                });
              },
              icon: const Icon(LucideIcons.plus),
              label: const Text("Add Custom Time"),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildScheduleRadio(String value, String label) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: scheduleType,
      activeColor: AppTheme.primaryBlue,
      contentPadding: EdgeInsets.zero,
      onChanged: (val) => setState(() {
        scheduleType = val!;
        recalcQty();
      }),
    );
  }

  Widget _buildSlotChip(String value, String label, IconData icon) {
    final isSelected = selectedSlots.contains(value);
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.primaryBlue),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      selectedColor: AppTheme.primaryBlue,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
      onSelected: (val) {
        setState(() {
          val ? selectedSlots.add(value) : selectedSlots.remove(value);
          recalcQty();
        });
      },
    );
  }

  // ==========================================
  // STEP 4: Inventory
  // ==========================================
  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Step 4 of 4", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text("Inventory & Notes", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text("Start Date: ${DateFormat('dd MMM yyyy').format(startDate)}", style: const TextStyle(fontWeight: FontWeight.w500)),
            trailing: const Icon(LucideIcons.calendar, color: AppTheme.primaryBlue),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: startDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365))
              );
              if (date != null) setState(() {
                startDate = date;
                recalcQty();
              });
            },
          ),
          const SizedBox(height: 16),

          if (scheduleType != 'specific_dates' && !isAsNeeded) ...[
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Duration (Days)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) => recalcQty(),
            ),
            const SizedBox(height: 16),
          ],

          TextField(
            controller: qtyController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Total Quantity (Pills/Doses remaining)",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            )
          ),
          const SizedBox(height: 16),

          TextField(
            controller: refillReminderController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: "Refill Reminder",
              hintText: "Remind me when X pills left",
              prefixIcon: const Icon(LucideIcons.bell),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            )
          ),
          const SizedBox(height: 24),

          TextField(
            controller: notesController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: "Doctor's instructions / Notes",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMultiDatePicker() async {
    final selectedDates = Set<DateTime>.from(specificDates.map((d) => DateTime.parse(d)));
    
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, sheetState) {
          final dates = List.generate(365, (i) => DateTime.now().add(Duration(days: i)));

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
                        '${selectedDates.length} selected',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Today'),
                        onPressed: () {
                          sheetState(() {
                            selectedDates.add(DateTime.now());
                          });
                        },
                      ),
                      ActionChip(
                        label: const Text('Next 7 Days'),
                        onPressed: () {
                          sheetState(() {
                            for (int i = 0; i < 7; i++) {
                              selectedDates.add(DateTime.now().add(Duration(days: i)));
                            }
                          });
                        },
                      ),
                      ActionChip(
                        label: const Text('Next 30 Days'),
                        onPressed: () {
                          sheetState(() {
                            for (int i = 0; i < 30; i++) {
                              selectedDates.add(DateTime.now().add(Duration(days: i)));
                            }
                          });
                        },
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
                      final isSelected = selectedDates.any((d) => d.year == date.year && d.month == date.month && d.day == date.day);
                      final isToday = DateTime.now().year == date.year && DateTime.now().month == date.month && DateTime.now().day == date.day;
                      return GestureDetector(
                        onTap: () {
                          sheetState(() {
                            if (isSelected) {
                              selectedDates.removeWhere((d) => d.year == date.year && d.month == date.month && d.day == date.day);
                            } else {
                              selectedDates.add(date);
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
                      onPressed: selectedDates.isEmpty
                          ? null
                          : () {
                              final sorted = selectedDates.toList()..sort();
                              setState(() {
                                specificDates = sorted.map((d) => DateFormat('yyyy-MM-dd').format(d)).toList();
                                recalcQty();
                              });
                              Navigator.pop(ctx);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        selectedDates.isEmpty
                            ? 'Select dates'
                            : 'Confirm ${selectedDates.length} dates',
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
}
