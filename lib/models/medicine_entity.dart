import 'package:isar/isar.dart';

part 'medicine_entity.g.dart';

@collection
class MedicineEntity {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  String? supabaseId;

  String? userId;
  late String name;
  late String dosage;
  late int frequency;

  String? time1;
  String? time2;
  String? time3;

  int? alarmId1;
  int? alarmId2;
  int? alarmId3;

  late DateTime startDate;
  late int durationDays;
  late int qty;
  late int counter;

  bool isActive = true;
  bool isTaken = false;
  String? imagePath;
  DateTime? createdAt;

  List<String> slotTypes = [];
  List<String> customTimes = [];

  String scheduleType = 'daily';
  int everyXDays = 1;
  List<String> specificDates = [];

  String notes = '';
  bool isPaused = false;
  bool lowStockAlerted = false;
}
