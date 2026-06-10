import 'package:intl/intl.dart';

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
  final String notes;               // Doctor instructions
  final bool isPaused;
  final bool lowStockAlerted;              // Pause feature

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
    this.notes = '',
    this.isPaused = false,
    this.lowStockAlerted = false,
  });

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

  // returns frequency as the dose count per day
  int get dailyDose => frequency;

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
        notes: json['notes']?.toString() ?? '',
        isPaused: json['is_paused'] == true || json['is_paused'] == 1,
        lowStockAlerted: json['low_stock_alerted'] == true || json['low_stock_alerted'] == 1,
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
      'notes': notes,
      'is_paused': isPaused,
      'low_stock_alerted': lowStockAlerted,
    };
  }

  /// Returns true if medicine should be active on given date
  bool isActiveOnDate(DateTime date) {
    if (isPaused) return false;
    if (scheduleType == 'specific_dates') {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      return specificDates.contains(dateStr);
    }
    if (scheduleType == 'every_x_days') {
      final daysDiff = date.difference(startDate).inDays;
      return daysDiff >= 0 && daysDiff % everyXDays == 0;
    }
    return true; // daily
  }

}
