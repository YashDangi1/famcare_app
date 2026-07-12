class AlarmContext {
  final int alarmId;
  final int originalAlarmId;
  final bool isSnooze;
  final bool isRetry;
  final String alarmType; // "single" | "group"
  final String mode; // "fullscreen" | "notification"
  final DateTime scheduledTime;
  final String? slotKey;
  final int? slotIndex;
  final List<String> medicationIds;
  final List<String> medicineNames;
  final List<String> dosages;
  final List<String?> imagePaths;
  final bool fromCache;
  final bool fromDb;

  AlarmContext({
    required this.alarmId,
    required this.originalAlarmId,
    required this.isSnooze,
    required this.isRetry,
    required this.alarmType,
    required this.mode,
    required this.scheduledTime,
    this.slotKey,
    this.slotIndex,
    required this.medicationIds,
    required this.medicineNames,
    required this.dosages,
    required this.imagePaths,
    required this.fromCache,
    required this.fromDb,
  });

  bool get isSingle => alarmType == 'single';
  bool get isGroup => alarmType == 'group';
}
