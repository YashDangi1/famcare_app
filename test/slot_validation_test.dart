import 'package:flutter_test/flutter_test.dart';
import 'package:famcare_app/utils/slot_validation.dart';

void main() {
  group('Slot Validation Logic Tests', () {
    test('TC-SLOT-03: Save valid slot times succeeds', () {
      final validPrefs = {
        'morning_start': '08:00',
        'morning_end': '09:30',
        'afternoon_start': '12:00',
        'afternoon_end': '14:00',
        'evening_start': '17:00',
        'evening_end': '18:30',
        'night_start': '21:00',
        'night_end': '22:30',
      };
      final error = SlotValidation.validateSlotTimes(validPrefs, 30);
      expect(error, isNull);
    });

    test('TC-SLOT-04: Overlap validation - Afternoon start overlaps with Morning end', () {
      final overlappingPrefs = {
        'morning_start': '08:00',
        'morning_end': '13:00', // Ends at 13:00
        'afternoon_start': '12:00', // Starts at 12:00 (overlaps!)
        'afternoon_end': '14:00',
        'evening_start': '17:00',
        'evening_end': '18:30',
        'night_start': '21:00',
        'night_end': '22:30',
      };
      final error = SlotValidation.validateSlotTimes(overlappingPrefs, 30);
      expect(error, 'Afternoon start must be after morning end');
    });

    test('TC-SLOT-05: Retry interval validation - retry interval must be less than slot range', () {
      final shortRangePrefs = {
        'morning_start': '08:00',
        'morning_end': '08:20', // range is 20 min
        'afternoon_start': '12:00',
        'afternoon_end': '14:00',
        'evening_start': '17:00',
        'evening_end': '18:30',
        'night_start': '21:00',
        'night_end': '22:30',
      };
      // Retry interval is 30 mins, which is greater than the morning slot range (20 mins)
      final error = SlotValidation.validateSlotTimes(shortRangePrefs, 30);
      expect(error, contains('Retry interval (30min) must be less than slot range'));
    });

    test('TC-SLOT-06: Night slot crossing midnight is saved without error', () {
      final crossMidnightPrefs = {
        'morning_start': '08:00',
        'morning_end': '09:30',
        'afternoon_start': '12:00',
        'afternoon_end': '14:00',
        'evening_start': '17:00',
        'evening_end': '18:30',
        'night_start': '23:00',
        'night_end': '01:00', // crosses midnight
      };
      final error = SlotValidation.validateSlotTimes(crossMidnightPrefs, 30);
      expect(error, isNull);
    });

    test('Night end overlaps with Morning start', () {
      final overlapPrefs = {
        'morning_start': '08:00',
        'morning_end': '09:30',
        'afternoon_start': '12:00',
        'afternoon_end': '14:00',
        'evening_start': '17:00',
        'evening_end': '18:30',
        'night_start': '23:00',
        'night_end': '08:30', // Night end overlaps with Morning start!
      };
      final error = SlotValidation.validateSlotTimes(overlapPrefs, 30);
      expect(error, 'Night end overlaps with Morning start — adjust night end or morning start');
    });

    test('Evening end overlaps with Night start (fixed checking)', () {
      final eveningNightOverlapPrefs = {
        'morning_start': '08:00',
        'morning_end': '09:30',
        'afternoon_start': '12:00',
        'afternoon_end': '14:00',
        'evening_start': '17:00',
        'evening_end': '21:30', // Ends at 21:30
        'night_start': '21:00', // Starts at 21:00 (overlaps!)
        'night_end': '22:30',
      };
      final error = SlotValidation.validateSlotTimes(eveningNightOverlapPrefs, 30);
      expect(error, 'Night start must be after evening end');
    });
  });
}
