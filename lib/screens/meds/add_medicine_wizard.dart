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
  final List<String> existingMedicineNames;
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
    required List<Map<String, dynamic>> taperSteps,
    required String notes,
    required int dur,
    required DateTime start,
    required int qty,
    required int? refillReminderThreshold,
  }) onSave;

  const AddMedicineWizard({super.key, this.existingMed, this.existingMedicineNames = const [], required this.onSave});

  @override
  State<AddMedicineWizard> createState() => _AddMedicineWizardState();
}

class _AddMedicineWizardState extends State<AddMedicineWizard> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 5;

  // Step 1: Basics
  late TextEditingController nameController;
  late TextEditingController conditionController;
  late TextEditingController strengthController;
  String? strengthUnit = 'mg';
  late TextEditingController takeAmountController;
  String? selectedForm = 'tablet';
  String? selectedColor = 'White';
  File? selectedImage;
  final _imagePicker = ImagePicker();

  // Step 2: Schedule
  String scheduleType = 'daily';
  List<String> specificDates = [];
  List<Map<String, dynamic>> taperSteps = [];
  late TextEditingController everyXDaysController;
  List<String> selectedSlots = [];
  List<TimeOfDay> customAlarmTimes = [];
  bool isAsNeeded = false;
  String scheduleFrequency = 'slot-based';

  // Step 3: Duration & Quantity
  DateTime startDate = DateTime.now();
  late TextEditingController durationController;
  late TextEditingController qtyController;
  late TextEditingController refillReminderController;

  // Step 4: Reminder Setup
  bool useFullscreenAlarm = true;
  int retryMinutes = 10;

  // Step 5: Instructions
  String? foodInstruction;
  late TextEditingController notesController;

  final List<String> forms = ['tablet', 'capsule', 'syrup', 'injection', 'drops', 'powder'];
  final List<String> units = ['mg', 'mcg', 'g', 'ml', '%', 'drops', 'puffs'];
  final List<String> colors = ['White', 'Red', 'Blue', 'Green', 'Yellow', 'Pink', 'Orange', 'Purple'];
  final Map<String, Color> colorMap = {
    'White': Colors.white, 'Red': Colors.redAccent, 'Blue': Colors.blueAccent,
    'Green': Colors.green, 'Yellow': Colors.amber, 'Pink': Colors.pinkAccent,
    'Orange': Colors.orangeAccent, 'Purple': Colors.purpleAccent,
  };

  @override
  void initState() {
    super.initState();
    final m = widget.existingMed;
    
    // Step 1
    nameController = TextEditingController(text: m?.name);
    conditionController = TextEditingController(text: m?.condition ?? '');
    strengthController = TextEditingController(text: m?.strength?.toString() ?? '');
    strengthUnit = m?.strengthUnit ?? 'mg';
    takeAmountController = TextEditingController(text: m?.takeAmount ?? '1');
    selectedForm = m?.form ?? 'tablet';
    if (!forms.contains(selectedForm?.toLowerCase())) selectedForm = 'tablet';
    selectedColor = m?.color ?? 'White';
    if (!colors.contains(selectedColor)) selectedColor = 'White';
    _loadExistingImage();

    // Step 2
    isAsNeeded = m?.isAsNeeded ?? false;
    scheduleType = m?.scheduleType ?? 'daily';
    specificDates = List.from(m?.specificDates ?? []);
    taperSteps = List.from(m?.taperSteps ?? []);
    everyXDaysController = TextEditingController(text: (m?.everyXDays ?? 1).toString());
    selectedSlots = List.from(m?.slotTypes ?? []);
    if (selectedSlots.isEmpty && m != null && !isAsNeeded) {
      if (m.frequency >= 1) selectedSlots.add('morning');
      if (m.frequency >= 2) selectedSlots.add('afternoon');
      if (m.frequency >= 3) selectedSlots.add('night');
    }
    customAlarmTimes = (m?.customTimes ?? []).map((t) => _parseTime(t)).whereType<TimeOfDay>().toList();
    if (isAsNeeded) scheduleFrequency = 'as needed';
    else if (selectedSlots.contains('custom')) scheduleFrequency = 'custom times';
    else scheduleFrequency = 'slot-based';

    // Step 3
    startDate = m?.startDate ?? DateTime.now();
    durationController = TextEditingController(text: (m?.durationDays ?? 30).toString());
    qtyController = TextEditingController(text: (m?.qty ?? 0).toString());
    refillReminderController = TextEditingController(text: m?.refillReminderThreshold?.toString() ?? '5');

    // Step 5
    foodInstruction = m?.foodInstruction;
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
    if (isAsNeeded) return;

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
    } else if (scheduleType == 'tapered') {
      int taperDur = 0;
      for (var s in taperSteps) { taperDur += (s['duration_days'] as int? ?? 1); }
      qty = slotCount * taperDur;
    } else {
      qty = slotCount * dur;
    }
    
    final takeAmt = double.tryParse(takeAmountController.text) ?? 1.0;
    qty = (qty * takeAmt).ceil();
    
    qtyController.text = qty.toString();
  }

  void _proceedToNextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _currentStep++);
    } else {
      _save();
    }
  }

  void _nextStep() {
    if (_currentStep == 0 && nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a medicine name')));
      return;
    }
    if (_currentStep == 0 && widget.existingMedicineNames.contains(nameController.text.trim().toLowerCase())) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Duplicate Medicine'),
          content: const Text('You already have an active medicine with this exact name. Are you sure you want to add it again?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _proceedToNextStep();
              },
              child: const Text('Yes, Continue'),
            ),
          ],
        ),
      );
      return;
    }

    if (_currentStep == 1 && !isAsNeeded && scheduleFrequency == 'slot-based' && selectedSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one time slot')));
      return;
    }
    if (_currentStep == 1 && !isAsNeeded && scheduleFrequency == 'custom times' && customAlarmTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one custom time')));
      return;
    }

    _proceedToNextStep();
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
    // Convert frequency selections into proper format before saving
    if (scheduleFrequency == 'as needed') {
      isAsNeeded = true;
      selectedSlots.clear();
      customAlarmTimes.clear();
    } else {
      isAsNeeded = false;
      if (scheduleFrequency == 'custom times') {
        if (!selectedSlots.contains('custom')) selectedSlots.add('custom');
      } else if (scheduleFrequency == 'slot-based') {
        selectedSlots.remove('custom');
      }
    }

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
      taperSteps: taperSteps,
      notes: notesController.text,
      dur: int.tryParse(durationController.text) ?? 30,
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
        title: Text(widget.existingMed == null ? "Add Medicine" : "Edit Medicine", style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(LucideIcons.x),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cyanAccent),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStep1(),
                _buildStep2(),
                _buildStep3(),
                _buildStep4(),
                _buildStep5(),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _prevStep,
              child: Text(_currentStep == 0 ? "Cancel" : "Back", style: TextStyle(fontSize: 16, color: Colors.grey[700])),
            ),
            ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.cyanAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_currentStep == _totalSteps - 1 ? "Save & Activate" : "Next", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepHeader(String stepText, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(stepText, style: const TextStyle(color: AppTheme.cyanAccent, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  // ==========================================
  // STEP 1: Basic Info
  // ==========================================
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader("Step 1 of 5", "Basic Info", "Let's start with the medicine details."),
          
          TextField(
            controller: nameController,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: "Medicine Name*",
              prefixIcon: const Icon(LucideIcons.pill, color: AppTheme.cyanAccent),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            )
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: conditionController,
            decoration: InputDecoration(
              labelText: "Condition/Purpose (e.g. Blood Pressure) - Optional",
              prefixIcon: const Icon(LucideIcons.activity, color: Colors.grey),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            )
          ),
          const SizedBox(height: 16),
          
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
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                  items: units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                  onChanged: (val) => setState(() => strengthUnit = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          TextField(
            controller: takeAmountController,
            decoration: InputDecoration(
              labelText: "Amount to take per dose",
              hintText: "e.g. 1, 0.5, 2",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => recalcQty(),
          ),
          const SizedBox(height: 24),
          
          const Text("Medicine Type", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: forms.map((f) => ChoiceChip(
              label: Text(f),
              selected: selectedForm?.toLowerCase() == f,
              onSelected: (val) => setState(() => selectedForm = val ? f : selectedForm),
              selectedColor: AppTheme.cyanAccent.withOpacity(0.2),
              labelStyle: TextStyle(color: selectedForm?.toLowerCase() == f ? AppTheme.cyanAccent : Colors.black87),
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
                  border: Border.all(color: selectedColor == c ? AppTheme.cyanAccent : Colors.grey[300]!, width: selectedColor == c ? 3 : 1),
                  boxShadow: [
                    if (selectedColor == c) BoxShadow(color: AppTheme.cyanAccent.withOpacity(0.3), blurRadius: 8)
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
                        Text("Add Medication Photo (Optional)", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      ]
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 2: Schedule
  // ==========================================
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader("Step 2 of 5", "Schedule", "How often do you take this?"),
          
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              children: [
                _buildFreqRadio('slot-based', 'Regular Slots (Morning, Night)'),
                const Divider(height: 1),
                _buildFreqRadio('custom times', 'Specific Times (e.g. 10:00 AM)'),
                const Divider(height: 1),
                _buildFreqRadio('as needed', 'As Needed (PRN)'),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          if (scheduleFrequency == 'slot-based') ...[
            const Text("Select Time Slots", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _buildSlotChip('morning', 'Morning', LucideIcons.sunrise),
                _buildSlotChip('afternoon', 'Afternoon', LucideIcons.sun),
                _buildSlotChip('evening', 'Evening', LucideIcons.sunset),
                _buildSlotChip('night', 'Night', LucideIcons.moon),
              ],
            ),
          ] else if (scheduleFrequency == 'custom times') ...[
            const Text("Select Exact Times", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...customAlarmTimes.asMap().entries.map((entry) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
                child: ListTile(
                  title: Text(entry.value.format(context), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  leading: const Icon(LucideIcons.clock, color: AppTheme.cyanAccent),
                  trailing: IconButton(
                    icon: const Icon(LucideIcons.xCircle, color: Colors.red),
                    onPressed: () => setState(() { customAlarmTimes.removeAt(entry.key); recalcQty(); }),
                  ),
                ),
              );
            }),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                if (picked != null) setState(() { customAlarmTimes.add(picked); recalcQty(); });
              },
              icon: const Icon(LucideIcons.plus),
              label: const Text("Add Custom Time"),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.cyanAccent, padding: const EdgeInsets.symmetric(vertical: 12)),
            )
          ] else if (scheduleFrequency == 'as needed') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.orange[200]!)),
              child: const Row(
                children: [
                  Icon(LucideIcons.info, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(child: Text("You won't receive scheduled alarms, but you can log doses directly from the home screen.", style: TextStyle(color: Colors.orange))),
                ],
              ),
            )
          ],

          if (scheduleFrequency != 'as needed') ...[
            const SizedBox(height: 32),
            const Text("Frequency Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildScheduleRadio('daily', 'Every day')),
                      Expanded(child: _buildScheduleRadio('every_x_days', 'Every X days')),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _buildScheduleRadio('specific_dates', 'Specific dates')),
                      if (scheduleType == 'specific_dates')
                        IconButton(
                          icon: const Icon(LucideIcons.calendar, color: AppTheme.cyanAccent),
                          onPressed: () => _showMultiDatePicker(),
                        ),
                      Expanded(child: _buildScheduleRadio('tapered', 'Tapered Dose')),
                    ],
                  ),
                  if (scheduleType == 'tapered') _buildTaperUI(),
                  if (scheduleType == 'every_x_days')
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          const Text("Interval in days: "),
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
                    ),
                  if (scheduleType == 'specific_dates' && specificDates.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, top: 8),
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
                ],
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildFreqRadio(String value, String label) {
    return RadioListTile<String>(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      value: value,
      groupValue: scheduleFrequency,
      activeColor: AppTheme.cyanAccent,
      onChanged: (val) {
        setState(() {
          scheduleFrequency = val!;
          if (scheduleFrequency == 'as needed') isAsNeeded = true;
          else isAsNeeded = false;
          recalcQty();
        });
      },
    );
  }

  Widget _buildScheduleRadio(String value, String label) {
    return RadioListTile<String>(
      title: Text(label, style: const TextStyle(fontSize: 13)),
      value: value,
      groupValue: scheduleType,
      activeColor: AppTheme.cyanAccent,
      contentPadding: EdgeInsets.zero,
      onChanged: (val) => setState(() { scheduleType = val!; recalcQty(); }),
    );
  }

  Widget _buildTaperUI() {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Taper Steps", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...taperSteps.asMap().entries.map((e) {
            final idx = e.key;
            final step = e.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                children: [
                  Text("Step ${idx+1}:", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("${step['dosage']} for ${step['duration_days']} days", style: const TextStyle(fontSize: 13)),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 18, color: Colors.red),
                    onPressed: () => setState(() { taperSteps.removeAt(idx); recalcQty(); }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                ],
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: _showAddTaperStepDialog,
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text("Add Step"),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.cyanAccent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
            ),
          )
        ],
      ),
    );
  }

  void _showAddTaperStepDialog() {
    final doseCtrl = TextEditingController(text: '1');
    final durCtrl = TextEditingController(text: '3');
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text("Add Taper Step"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: doseCtrl, decoration: const InputDecoration(labelText: "Dosage (e.g. 2)")),
          const SizedBox(height: 12),
          TextField(controller: durCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Duration (Days)")),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () {
            setState(() {
              taperSteps.add({
                'dosage': doseCtrl.text.trim(),
                'duration_days': int.tryParse(durCtrl.text) ?? 1,
              });
              recalcQty();
            });
            Navigator.pop(context);
          },
          child: const Text("Add"),
        )
      ],
    ));
  }

  Widget _buildSlotChip(String value, String label, IconData icon) {
    final isSelected = selectedSlots.contains(value);
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.cyanAccent),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: isSelected,
      selectedColor: AppTheme.cyanAccent,
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
  // STEP 3: Duration & Quantity
  // ==========================================
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader("Step 3 of 5", "Duration & Quantity", "Plan your stock and refills."),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Start Date", style: TextStyle(color: Colors.grey, fontSize: 13)),
              subtitle: Text(DateFormat('dd MMM yyyy').format(startDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
              trailing: const Icon(LucideIcons.calendar, color: AppTheme.cyanAccent),
              onTap: () async {
                final date = await showDatePicker(context: context, initialDate: startDate, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (date != null) setState(() { startDate = date; recalcQty(); });
              },
            ),
          ),
          const SizedBox(height: 24),

          if (!isAsNeeded) ...[
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Duration (Days)",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixText: "Days",
              ),
              onChanged: (_) => recalcQty(),
            ),
            const SizedBox(height: 24),
          ],

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: qtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Current Stock",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  )
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: refillReminderController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Refill Alert At",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  )
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (!isAsNeeded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppTheme.cyanAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.cyanAccent.withOpacity(0.3))),
              child: Row(
                children: [
                  const Icon(LucideIcons.lightbulb, color: AppTheme.cyanAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Smart Assist: At this schedule, ${qtyController.text.isEmpty ? '0' : qtyController.text} doses will last about ${((int.tryParse(qtyController.text) ?? 0) / (double.tryParse(takeAmountController.text) ?? 1) / max(1, (selectedSlots.length == 0 ? 1 : selectedSlots.length))).floor()} days.",
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            )
        ],
      ),
    );
  }

  // ==========================================
  // STEP 4: Reminder Setup
  // ==========================================
  Widget _buildStep4() {
    if (isAsNeeded) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.bellOff, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 20),
              const Text("No Alarms Required", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text("As-needed medicines do not use scheduled alarms.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 16)),
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
          _buildStepHeader("Step 4 of 5", "Reminder Setup", "Customize how you want to be notified."),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Full-Screen Alarm", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text("Wake up the device and show a full-screen alert. Recommended for critical meds.", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Switch(
                  value: useFullscreenAlarm,
                  activeColor: AppTheme.cyanAccent,
                  onChanged: (v) => setState(() => useFullscreenAlarm = v),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          const Text("Retry if Missed", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: retryMinutes,
            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            items: const [
              DropdownMenuItem(value: 0, child: Text("Don't retry")),
              DropdownMenuItem(value: 5, child: Text("Retry after 5 minutes")),
              DropdownMenuItem(value: 10, child: Text("Retry after 10 minutes")),
              DropdownMenuItem(value: 30, child: Text("Retry after 30 minutes")),
            ],
            onChanged: (val) => setState(() => retryMinutes = val ?? 10),
          ),
          
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green[200]!)),
            child: const Row(
              children: [
                Icon(LucideIcons.checkCircle2, color: Colors.green),
                SizedBox(width: 12),
                Expanded(child: Text("Permissions are looking good! Your alarms are set to ring reliably.", style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600))),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ==========================================
  // STEP 5: Instructions & Review
  // ==========================================
  Widget _buildStep5() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepHeader("Step 5 of 5", "Instructions & Review", "Final details before saving."),
          
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
          const SizedBox(height: 24),
          
          TextField(
            controller: notesController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: "Note to self or caregiver",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 32),
          
          const Text("Final Review", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[200]!)),
            child: Column(
              children: [
                _reviewRow(LucideIcons.pill, "Medicine", "${nameController.text.isEmpty ? 'Unnamed' : nameController.text} • ${takeAmountController.text} ${selectedForm?.toLowerCase()}"),
                const Divider(),
                _reviewRow(LucideIcons.calendarClock, "Schedule", isAsNeeded ? "As Needed" : "${scheduleFrequency == 'slot-based' ? selectedSlots.length : customAlarmTimes.length} times a day"),
                const Divider(),
                _reviewRow(LucideIcons.package, "Stock", "${qtyController.text} remaining • alerts at ${refillReminderController.text}"),
                const Divider(),
                _reviewRow(LucideIcons.bell, "Reminders", useFullscreenAlarm ? "Full-screen enabled" : "Notifications only"),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _reviewRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
      selectedColor: AppTheme.cyanAccent,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
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
                                ? AppTheme.cyanAccent
                                : isToday
                                    ? AppTheme.cyanAccent.withOpacity(0.1)
                                    : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: isToday
                                ? Border.all(color: AppTheme.cyanAccent)
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
                        backgroundColor: AppTheme.cyanAccent,
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
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
