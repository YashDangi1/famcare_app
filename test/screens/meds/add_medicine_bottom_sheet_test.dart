import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:famcare_app/screens/meds/add_medicine_bottom_sheet.dart';

void main() {
  testWidgets('AddMedicineBottomSheet renders correctly and calculates qty', (WidgetTester tester) async {
    bool didSave = false;
    
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (ctx) => AddMedicineBottomSheet(
                  onSave: ({
                    required dialogContext,
                    existingMed,
                    required name,
                    required dosage,
                    required selectedSlots,
                    required customAlarmTimes,
                    required scheduleType,
                    required everyXDays,
                    required specificDates,
                    required notes,
                    required dur,
                    required start,
                    required qty,
                    image,
                  }) async {
                    didSave = true;
                    expect(name, 'Ibuprofen');
                    expect(dosage, '2 pills');
                    expect(selectedSlots.contains('morning'), true);
                    expect(qty, 14); // 7 days * 2 slots (morning + night)
                  },
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ));

    // Tap to open bottom sheet
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    // Verify UI elements are present
    expect(find.text('Add Medicine'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);

    // Enter medicine name
    await tester.enterText(find.widgetWithText(TextField, 'Medicine Name*'), 'Ibuprofen');
    
    // Enter dosage
    await tester.enterText(find.widgetWithText(TextField, 'Dosage (e.g. 1 tablet)'), '2 pills');

    // Select slots
    final morningFinder = find.text('Morning');
    await tester.ensureVisible(morningFinder);
    await tester.tap(morningFinder);
    await tester.pumpAndSettle();
    
    final nightFinder = find.text('Night');
    await tester.ensureVisible(nightFinder);
    await tester.tap(nightFinder);
    await tester.pumpAndSettle();

    // Verify quantity auto-calculated (duration is 7 by default, 2 slots = 14)
    final qtyField = tester.widget<TextField>(find.widgetWithText(TextField, 'Total Qty'));
    expect(qtyField.controller?.text, '14');

    // Tap Save
    final saveFinder = find.text('Save');
    await tester.ensureVisible(saveFinder);
    await tester.tap(saveFinder);
    await tester.pumpAndSettle();

    expect(didSave, true);
  });
}
