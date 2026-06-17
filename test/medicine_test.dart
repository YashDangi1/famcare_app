import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:famcare_app/models/medicine_model.dart';

void main() {
  group('Medicine Model JSON Parsing', () {
    test('TC-MED-16: Legacy medicine data fallback parsing', () {
      final legacyJson = {
        'id': 'legacy-id-123',
        'user_id': 'user-abc',
        'name': 'Dolo 650',
        'dosage': '1 tablet',
        'frequency': '3',
        'time1': '08:00 AM',
        'time2': '02:00 PM',
        'time3': '08:00 PM',
        'alarm_id1': '101',
        'alarm_id2': '102',
        'alarm_id3': '103',
        'start_date': '2026-06-01',
        'duration_days': '5',
        'qty': '15',
        'counter': '0',
        'is_active': 'true',
        'is_taken': 'false',
        // New fields missing from legacy DB row
      };

      final med = Medicine.fromJson(legacyJson);

      expect(med.id, 'legacy-id-123');
      expect(med.name, 'Dolo 650');
      expect(med.dosage, '1 tablet');
      expect(med.frequency, 3);
      expect(med.alarmId1, 101);
      expect(med.alarmId2, 102);
      expect(med.alarmId3, 103);
      expect(med.startDate, DateTime(2026, 6, 1));
      expect(med.durationDays, 5);
      expect(med.qty, 15);
      expect(med.isActive, true);
      expect(med.isTaken, false);
      expect(med.slotTypes, isEmpty);
      expect(med.customTimes, isEmpty);
      expect(med.scheduleType, 'daily');
      expect(med.everyXDays, 1);
      expect(med.notes, '');
      expect(med.isPaused, false);
    });

    test('Modern format JSON parsing and serialization roundtrip', () {
      final med = Medicine(
        id: 'modern-id-123',
        userId: 'user-xyz',
        name: 'Pantocid',
        dosage: '1 capsule',
        frequency: 2,
        time1: '08:00 AM',
        time2: '08:00 PM',
        startDate: DateTime(2026, 6, 11),
        durationDays: 7,
        qty: 14,
        counter: 1,
        slotTypes: ['morning', 'evening'],
        customTimes: [],
        scheduleType: 'every_x_days',
        everyXDays: 2,
        specificDates: [],
        notes: 'Take before breakfast',
        isPaused: true,
        lowStockAlerted: true,
      );

      final json = med.toJson();
      expect(json['id'], 'modern-id-123');
      expect(json['user_id'], 'user-xyz');
      expect(json['name'], 'Pantocid');
      expect(json['frequency'], 2);
      expect(json['slot_types'], ['morning', 'evening']);
      expect(json['schedule_type'], 'every_x_days');
      expect(json['every_x_days'], 2);
      expect(json['is_paused'], true);
      expect(json['low_stock_alerted'], true);
      expect(json['start_date'], '2026-06-11');
      expect(json['end_date'], '2026-06-17'); // 11 + 7 - 1 = 17

      final parsed = Medicine.fromJson(json);
      expect(parsed.name, 'Pantocid');
      expect(parsed.everyXDays, 2);
      expect(parsed.isPaused, true);
      expect(parsed.lowStockAlerted, true);
    });
  });

  group('Medicine Date and Active Logic', () {
    test('Daily scheduling activity checks', () {
      final med = Medicine(
        name: 'DailyMed',
        dosage: '1 pill',
        frequency: 1,
        startDate: DateTime(2026, 6, 11),
        durationDays: 5,
        qty: 5,
        counter: 0,
        scheduleType: 'daily',
      );

      expect(med.isActiveOnDate(DateTime(2026, 6, 11)), true);
      expect(med.isActiveOnDate(DateTime(2026, 6, 12)), true);
      expect(med.isActiveOnDate(DateTime(2026, 6, 15)), true);
    });

    test('TC-MED-04: Every X days scheduling checks', () {
      final med = Medicine(
        name: 'Every3DaysMed',
        dosage: '1 pill',
        frequency: 1,
        startDate: DateTime(2026, 6, 11),
        durationDays: 10,
        qty: 4,
        counter: 0,
        scheduleType: 'every_x_days',
        everyXDays: 3,
      );

      // 2026-06-11 is Day 0 (active)
      expect(med.isActiveOnDate(DateTime(2026, 6, 11)), true, reason: 'Start date should be active');
      // 2026-06-12 is Day 1 (inactive)
      expect(med.isActiveOnDate(DateTime(2026, 6, 12)), false);
      // 2026-06-13 is Day 2 (inactive)
      expect(med.isActiveOnDate(DateTime(2026, 6, 13)), false);
      // 2026-06-14 is Day 3 (active)
      expect(med.isActiveOnDate(DateTime(2026, 6, 14)), true);
      // 2026-06-20 is Day 9 (active)
      expect(med.isActiveOnDate(DateTime(2026, 6, 20)), true);
    });

    test('TC-MED-05: Specific dates scheduling checks', () {
      final med = Medicine(
        name: 'SpecificDatesMed',
        dosage: '1 pill',
        frequency: 1,
        startDate: DateTime(2026, 6, 11),
        durationDays: 5,
        qty: 3,
        counter: 0,
        scheduleType: 'specific_dates',
        specificDates: ['2026-06-12', '2026-06-15', '2026-06-20'],
      );

      expect(med.isActiveOnDate(DateTime(2026, 6, 11)), false);
      expect(med.isActiveOnDate(DateTime(2026, 6, 12)), true);
      expect(med.isActiveOnDate(DateTime(2026, 6, 15)), true);
      expect(med.isActiveOnDate(DateTime(2026, 6, 20)), true);
      expect(med.isActiveOnDate(DateTime(2026, 6, 21)), false);
    });

    test('TC-MED-14: Paused medicine never active', () {
      final med = Medicine(
        name: 'PausedMed',
        dosage: '1 pill',
        frequency: 1,
        startDate: DateTime(2026, 6, 11),
        durationDays: 5,
        qty: 5,
        counter: 0,
        scheduleType: 'daily',
        isPaused: true,
      );

      expect(med.isActiveOnDate(DateTime(2026, 6, 11)), false);
      expect(med.isActiveOnDate(DateTime(2026, 6, 12)), false);
    });

    test('TC-MED-10: everyXDays = 0 divide-by-zero check defaults to 1 safely', () {
      final med = Medicine(
        name: 'ZeroIntervalMed',
        dosage: '1 pill',
        frequency: 1,
        startDate: DateTime(2026, 6, 11),
        durationDays: 5,
        qty: 5,
        counter: 0,
        scheduleType: 'every_x_days',
        everyXDays: 0,
      );

      // Verify that this is handled safely (defaults to daily behavior / 1 day interval) and does not throw
      expect(med.isActiveOnDate(DateTime(2026, 6, 12)), true);
    });

    test('TC-EDGE-04: Medicine expiry math', () {
      final med = Medicine(
        name: 'ExpiryMed',
        dosage: '1 pill',
        frequency: 1,
        startDate: DateTime(2026, 6, 11),
        durationDays: 2, // ends 2026-06-12
        qty: 2,
        counter: 0,
      );

      expect(med.endDate, DateTime(2026, 6, 12));
    });
  });
}
