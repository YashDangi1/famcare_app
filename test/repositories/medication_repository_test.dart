import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:famcare_app/repositories/medication_repository.dart';
import 'package:famcare_app/models/medicine_model.dart';
import 'package:famcare_app/models/medicine_entity.dart';

// Mock Classes
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockUser extends Mock implements User {}
class MockPostgrestFilterBuilder<T> extends Mock implements PostgrestFilterBuilder<T> {}
class MockPostgrestTransformBuilder<T> extends Mock implements PostgrestTransformBuilder<T> {}
class MockPostgrestQueryBuilder<T> extends Mock implements SupabaseQueryBuilder {}

void main() {
  late Isar isar;
  late MockSupabaseClient mockSupabaseClient;
  late MedicationRepository repository;
  const userId = 'test_user_123';

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
  });

  setUp(() async {
    // Create a temporary directory for Isar tests to avoid conflicts
    final tempDir = Directory.systemTemp.createTempSync('isar_test');
    isar = await Isar.open(
      [MedicineEntitySchema],
      directory: tempDir.path,
    );
    mockSupabaseClient = MockSupabaseClient();
    repository = MedicationRepository(mockSupabaseClient, isar);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  group('MedicationRepository', () {
    final testMedicine = Medicine(
      id: 'med_1',
      userId: userId,
      name: 'Aspirin',
      dosage: '1 pill',
      frequency: 1,
      durationDays: 7,
      qty: 7,
      counter: 0,
      isActive: true,
      startDate: DateTime.now(),
      scheduleType: 'daily',
        createdAt: DateTime.now(),
    );

    test('fetchLocalMedications returns empty list when Isar is empty', () async {
      final meds = await repository.fetchLocalMedications(userId);
      expect(meds, isEmpty);
    });

    test('fetchLocalMedications returns saved medications', () async {
      await isar.writeTxn(() async {
        await isar.medicineEntitys.put(testMedicine.toEntity());
      });

      final meds = await repository.fetchLocalMedications(userId);
      expect(meds.length, 1);
      expect(meds.first.name, 'Aspirin');
      expect(meds.first.id, 'med_1');
    });

    test('addMedication saves locally with local_ prefix when remote fails', () async {
      final newMed = Medicine(
        userId: userId,
        name: 'Tylenol',
        dosage: '2 pills',
        frequency: 2,
        durationDays: 5,
        qty: 10,
        counter: 0,
        isActive: true,
        startDate: DateTime.now(),
        scheduleType: 'daily',
          createdAt: DateTime.now(),
      );

      // Mock Supabase to throw an exception to simulate offline mode
      final mockQueryBuilder = MockPostgrestQueryBuilder<List<Map<String, dynamic>>>();
      when(() => mockSupabaseClient.from('medications')).thenReturn(mockQueryBuilder);
      when(() => mockQueryBuilder.insert(any())).thenThrow(Exception('Network Error'));

      await repository.addMedication(newMed, userId);

      // Verify it was saved locally
      final meds = await repository.fetchLocalMedications(userId);
      expect(meds.length, 1);
      expect(meds.first.name, 'Tylenol');
      expect(meds.first.id?.startsWith('local_'), true);
    });
  });
}
