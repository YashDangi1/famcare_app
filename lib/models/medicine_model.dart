import 'dart:convert';
import 'package:intl/intl.dart';

import 'medicine_entity.dart';

class Medicine {
  final String? id;
  final String? userId;
  final String name;
  final String dosage;
  final int frequency; // 1, 2, or 3 times per day
  final String? time1; // HH:MM AM/PM
  final String? time2;
  final String? time3;
  final int? alarmId1;
  final int? alarmId2;
  final int? alarmId3;
  final DateTime startDate;
  final int durationDays;
  final int qty; // Total remaining quantity
  final int counter; // Manual refill counter
  final bool isActive;
  final bool isTaken;
  final String? imagePath;
  final DateTime? createdAt;

  // New fields — scheduling & metadata
  final List<String> slotTypes;     // ['morning', 'evening'] etc.
  final List<String> customTimes;   // For custom slot: ['09:15 AM', '03:30 PM']
  final String scheduleType;        // 'daily' | 'every_x_days' | 'specific_dates'
  final int everyXDays;             // Default 1
  final List<String> specificDates; // ['2026-05-20', '2026-05-22']
  final List<Map<String, dynamic>> taperSteps; // [{'duration_days': 3, 'dosage': '10mg'}]
  final String notes;               // Doctor instructions
  final bool isPaused;
  final bool lowStockAlerted;              // Pause feature

  // New fields for senior-friendly UI
  final String? form;
  final String? color;
  final double? strength;
  final String? strengthUnit;
  final String? takeAmount;
  final String? foodInstruction;
  final bool isAsNeeded;
  final int? refillReminderThreshold;
  final String? condition;

  Medicine({
    this.id,
    this.userId,
    required this.name,
    required this.dosage,
    required this.frequency,
    this.time1,
    this.time2,
    this.time3,
    this.alarmId1,
    this.alarmId2,
    this.alarmId3,
    required this.startDate,
    required this.durationDays,
    required this.qty,
    required this.counter,
    this.isActive = true,
    this.isTaken = false,
    this.imagePath,
    this.createdAt,
    this.slotTypes = const [],
    this.customTimes = const [],
    this.scheduleType = 'daily',
    this.everyXDays = 1,
    this.specificDates = const [],
    this.taperSteps = const [],
    this.notes = '',
    this.isPaused = false,
    this.lowStockAlerted = false,
    this.form,
    this.color,
    this.strength,
    this.strengthUnit,
    this.takeAmount,
    this.foodInstruction,
    this.isAsNeeded = false,
    this.refillReminderThreshold,
    this.condition,
  });

  Medicine copyWith({
    String? id,
    String? userId,
    String? name,
    String? dosage,
    int? frequency,
    String? time1,
    String? time2,
    String? time3,
    int? alarmId1,
    int? alarmId2,
    int? alarmId3,
    DateTime? startDate,
    int? durationDays,
    int? qty,
    int? counter,
    bool? isActive,
    bool? isTaken,
    String? imagePath,
    DateTime? createdAt,
    List<String>? slotTypes,
    List<String>? customTimes,
    String? scheduleType,
    int? everyXDays,
    List<String>? specificDates,
    List<Map<String, dynamic>>? taperSteps,
    String? notes,
    bool? isPaused,
    bool? lowStockAlerted,
    String? form,
    String? color,
    double? strength,
    String? strengthUnit,
    String? takeAmount,
    String? foodInstruction,
    bool? isAsNeeded,
    int? refillReminderThreshold,
    String? condition,
  }) {
    return Medicine(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      time1: time1 ?? this.time1,
      time2: time2 ?? this.time2,
      time3: time3 ?? this.time3,
      alarmId1: alarmId1 ?? this.alarmId1,
      alarmId2: alarmId2 ?? this.alarmId2,
      alarmId3: alarmId3 ?? this.alarmId3,
      startDate: startDate ?? this.startDate,
      durationDays: durationDays ?? this.durationDays,
      qty: qty ?? this.qty,
      counter: counter ?? this.counter,
      isActive: isActive ?? this.isActive,
      isTaken: isTaken ?? this.isTaken,
      imagePath: imagePath ?? this.imagePath,
      createdAt: createdAt ?? this.createdAt,
      slotTypes: slotTypes ?? this.slotTypes,
      customTimes: customTimes ?? this.customTimes,
      scheduleType: scheduleType ?? this.scheduleType,
      everyXDays: everyXDays ?? this.everyXDays,
      specificDates: specificDates ?? this.specificDates,
      taperSteps: taperSteps ?? this.taperSteps,
      notes: notes ?? this.notes,
      isPaused: isPaused ?? this.isPaused,
      lowStockAlerted: lowStockAlerted ?? this.lowStockAlerted,
      form: form ?? this.form,
      color: color ?? this.color,
      strength: strength ?? this.strength,
      strengthUnit: strengthUnit ?? this.strengthUnit,
      takeAmount: takeAmount ?? this.takeAmount,
      foodInstruction: foodInstruction ?? this.foodInstruction,
      isAsNeeded: isAsNeeded ?? this.isAsNeeded,
      refillReminderThreshold: refillReminderThreshold ?? this.refillReminderThreshold,
      condition: condition ?? this.condition,
    );
  }

  // startDate + durationDays - 1
  DateTime get endDate => startDate.add(Duration(days: durationDays - 1));

  // returns true if DateTime.now() is after endDate
  bool get isExpired {
    final now = DateTime.now();
    final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    return now.isAfter(endOfDay);
  }

  // returns non-null time strings based on frequency
  List<String> get activeTimes {
    final List<String> times = [];
    if (frequency >= 1 && time1 != null) times.add(time1!);
    if (frequency >= 2 && time2 != null) times.add(time2!);
    if (frequency >= 3 && time3 != null) times.add(time3!);
    return times;
  }

  String getCurrentDosage(DateTime targetDate) {
    if (scheduleType != 'tapered' || taperSteps.isEmpty) {
      return dosage;
    }
    
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    
    if (target.isBefore(start)) return dosage;

    int daysPassed = target.difference(start).inDays;
    int accumulatedDays = 0;
    
    for (final step in taperSteps) {
      final stepDuration = step['duration_days'] as int? ?? 1;
      accumulatedDays += stepDuration;
      if (daysPassed < accumulatedDays) {
        return step['dosage']?.toString() ?? dosage;
      }
    }
    
    return taperSteps.last['dosage']?.toString() ?? dosage;
  }

  MedicineEntity toEntity() {
    return MedicineEntity()
      ..supabaseId = id
      ..userId = userId
      ..name = name
      ..dosage = dosage
      ..frequency = frequency
      ..time1 = time1
      ..time2 = time2
      ..time3 = time3
      ..alarmId1 = alarmId1
      ..alarmId2 = alarmId2
      ..alarmId3 = alarmId3
      ..startDate = startDate
      ..durationDays = durationDays
      ..qty = qty
      ..counter = counter
      ..isActive = isActive
      ..isTaken = isTaken
      ..imagePath = imagePath
      ..createdAt = createdAt
      ..slotTypes = slotTypes
      ..customTimes = customTimes
      ..scheduleType = scheduleType
      ..everyXDays = everyXDays
      ..specificDates = specificDates
      ..taperStepsJson = jsonEncode(taperSteps)
      ..notes = notes
      ..isPaused = isPaused
      ..lowStockAlerted = lowStockAlerted
      ..form = form
      ..color = color
      ..strength = strength
      ..strengthUnit = strengthUnit
      ..takeAmount = takeAmount
      ..foodInstruction = foodInstruction
      ..isAsNeeded = isAsNeeded
      ..refillReminderThreshold = refillReminderThreshold
      ..condition = condition;
  }

  factory Medicine.fromEntity(MedicineEntity entity) {
    return Medicine(
      id: entity.supabaseId,
      userId: entity.userId,
      name: entity.name,
      dosage: entity.dosage,
      frequency: entity.frequency,
      time1: entity.time1,
      time2: entity.time2,
      time3: entity.time3,
      alarmId1: entity.alarmId1,
      alarmId2: entity.alarmId2,
      alarmId3: entity.alarmId3,
      startDate: entity.startDate,
      durationDays: entity.durationDays,
      qty: entity.qty,
      counter: entity.counter,
      isActive: entity.isActive,
      isTaken: entity.isTaken,
      imagePath: entity.imagePath,
      createdAt: entity.createdAt,
      slotTypes: entity.slotTypes,
      customTimes: entity.customTimes,
      scheduleType: entity.scheduleType,
      everyXDays: entity.everyXDays,
      specificDates: entity.specificDates,
      taperSteps: _parseTaperSteps(entity.taperStepsJson),
      notes: entity.notes,
      isPaused: entity.isPaused,
      lowStockAlerted: entity.lowStockAlerted,
      form: entity.form,
      color: entity.color,
      strength: entity.strength,
      strengthUnit: entity.strengthUnit,
      takeAmount: entity.takeAmount,
      foodInstruction: entity.foodInstruction,
      isAsNeeded: entity.isAsNeeded,
      refillReminderThreshold: entity.refillReminderThreshold,
      condition: entity.condition,
    );
  }

  // returns frequency as the dose count per day
  int get dailyDose => frequency;

  static List<Map<String, dynamic>> _parseTaperSteps(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final parsed = jsonDecode(jsonString) as List;
      return parsed.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  factory Medicine.fromJson(Map<String, dynamic> json) {
    try {
      return Medicine(
        id: json['id']?.toString(),
        userId: json['user_id']?.toString(),
        name: json['name']?.toString() ?? 'Unnamed',
        dosage: json['dosage']?.toString() ?? '',
        frequency: int.tryParse(json['frequency']?.toString() ?? '1') ?? 1,
        time1: json['time1']?.toString(),
        time2: json['time2']?.toString(),
        time3: json['time3']?.toString(),
        alarmId1: int.tryParse(json['alarm_id1']?.toString() ?? ''),
        alarmId2: int.tryParse(json['alarm_id2']?.toString() ?? ''),
        alarmId3: int.tryParse(json['alarm_id3']?.toString() ?? ''),
        startDate: json['start_date'] != null 
            ? (DateTime.tryParse(json['start_date'].toString()) ?? DateTime.now())
            : DateTime.now(),
        durationDays: int.tryParse(json['duration_days']?.toString() ?? '7') ?? 7,
        qty: int.tryParse(json['qty']?.toString() ?? '0') ?? 0,
        counter: int.tryParse(json['counter']?.toString() ?? '0') ?? 0,
        isActive: json['is_active'] == true || json['is_active'] == 1 || json['is_active']?.toString() == 'true',
        isTaken: json['is_taken'] == true || json['is_taken']?.toString() == 'true',
        imagePath: json['image_path']?.toString(),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
        slotTypes: List<String>.from(json['slot_types'] ?? []),
        customTimes: List<String>.from(json['custom_times'] ?? []),
        scheduleType: json['schedule_type']?.toString() ?? 'daily',
        everyXDays: int.tryParse(json['every_x_days']?.toString() ?? '1') ?? 1,
        specificDates: List<String>.from(json['specific_dates'] ?? []),
        taperSteps: json['taper_steps'] != null ? List<Map<String, dynamic>>.from((json['taper_steps'] as List).map((e) => Map<String, dynamic>.from(e))) : [],
        notes: json['notes']?.toString() ?? '',
        isPaused: json['is_paused'] == true || json['is_paused'] == 1,
        lowStockAlerted: json['low_stock_alerted'] == true || json['low_stock_alerted'] == 1,
        form: json['form']?.toString(),
        color: json['color']?.toString(),
        strength: double.tryParse(json['strength']?.toString() ?? ''),
        strengthUnit: json['strength_unit']?.toString(),
        takeAmount: json['take_amount']?.toString(),
        foodInstruction: json['food_instruction']?.toString(),
        isAsNeeded: json['is_as_needed'] == true || json['is_as_needed'] == 1,
        refillReminderThreshold: int.tryParse(json['refill_reminder_threshold']?.toString() ?? ''),
        condition: json['condition']?.toString(),
      );
    } catch (e) {
      print("Medicine parsing error: $e");
      // Return a basic object with a fallback ID to prevent null crashes downstream
      return Medicine(
        id: 'parsing-error-${DateTime.now().millisecondsSinceEpoch}',
        name: "Parsing Error",
        dosage: "",
        frequency: 1,
        startDate: DateTime.now(),
        durationDays: 1,
        qty: 0,
        counter: 0,
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'time1': time1,
      'time2': time2,
      'time3': time3,
      'alarm_id1': alarmId1,
      'alarm_id2': alarmId2,
      'alarm_id3': alarmId3,
      'start_date': startDate.toIso8601String().split('T')[0], // ✅ Naya — sirf date part bhejo
      'end_date': endDate.toIso8601String().split('T')[0], // ✅ Naya — DB filter ke liye
      'duration_days': durationDays,
      'qty': qty,
      'counter': counter,
      'is_active': isActive,
      'is_taken': isTaken,
      'image_path': imagePath,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'slot_types': slotTypes,
      'custom_times': customTimes,
      'schedule_type': scheduleType,
      'every_x_days': everyXDays,
      'specific_dates': specificDates,
      'taper_steps': taperSteps,
      'notes': notes,
      'is_paused': isPaused,
      'low_stock_alerted': lowStockAlerted,
      'form': form,
      'color': color,
      'strength': strength,
      'strength_unit': strengthUnit,
      'take_amount': takeAmount,
      'food_instruction': foodInstruction,
      'is_as_needed': isAsNeeded,
      'refill_reminder_threshold': refillReminderThreshold,
      'condition': condition,
    };
  }

  /// Returns true if medicine should be active on given date
  bool isActiveOnDate(DateTime date) {
    if (isPaused || qty <= 0 || isAsNeeded) return false;
    if (scheduleType == 'specific_dates') {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      return specificDates.contains(dateStr);
    }
    if (scheduleType == 'every_x_days') {
      final daysDiff = date.difference(startDate).inDays;
      final interval = everyXDays > 0 ? everyXDays : 1;
      return daysDiff >= 0 && daysDiff % interval == 0;
    }
    return true; // daily
  }

}
