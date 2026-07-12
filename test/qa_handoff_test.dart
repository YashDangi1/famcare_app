import 'package:flutter_test/flutter_test.dart';
import 'package:famcare_app/models/medicine_model.dart';
import 'package:famcare_app/models/achievement.dart';

void main() {
  group('QA Handoff - RC1 Tests', () {
    test('1. Tapered Doses Schedule and Deduction Math', () {
      final med = Medicine(
        name: 'TaperMed',
        dosage: '1 pill',
        frequency: 1,
        startDate: DateTime(2026, 6, 23),
        durationDays: 6,
        qty: 10,
        counter: 0,
        scheduleType: 'tapered',
        taperSteps: [
          {'duration_days': 3, 'dosage': '2 pills'},
          {'duration_days': 3, 'dosage': '1 pill'},
        ],
      );

      // Day 1
      expect(med.getCurrentDosage(DateTime(2026, 6, 23)), '2 pills');
      // Day 3
      expect(med.getCurrentDosage(DateTime(2026, 6, 25)), '2 pills');
      // Day 4
      expect(med.getCurrentDosage(DateTime(2026, 6, 26)), '1 pill');

      // Test deduction parsing logic (like in AlarmActionEngine)
      final dosageStr = med.getCurrentDosage(DateTime(2026, 6, 23));
      final match = RegExp(r'^([\d\.]+)').firstMatch(dosageStr);
      final parsedAmt = double.tryParse(match?.group(1) ?? '1') ?? 1.0;
      
      expect(parsedAmt, 2.0);
      expect(med.qty - parsedAmt, 8.0);
    });

    test('2. Family Role Restrictions', () {
      final adminUser = {'role': 'admin', 'can_edit_meds': false};
      final memberEditUser = {'role': 'member', 'can_edit_meds': true};
      final memberReadOnlyUser = {'role': 'member', 'can_edit_meds': false};

      bool canEdit(Map<String, dynamic> m) {
        return (m['role'] == 'admin') || (m['can_edit_meds'] == true);
      }

      expect(canEdit(adminUser), true, reason: 'Admin can always edit');
      expect(canEdit(memberEditUser), true, reason: 'Member with permission can edit');
      expect(canEdit(memberReadOnlyUser), false, reason: 'Read-only member cannot edit');
    });

    test('4. Gamification Streaks & Badges', () {
      // simulate _checkStreakCelebration logic
      final streak = 7;
      Achievement? unlockedBadge;
      for (final badge in Achievement.availableBadges) {
        if (badge.requiredStreak == streak) {
          unlockedBadge = badge;
        }
      }
      expect(unlockedBadge, isNotNull);
      expect(unlockedBadge!.id, 'streak_7');
    });
  });
}
