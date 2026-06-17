import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:famcare_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('End-to-End: Add a medicine and see it in MedsScreen', (tester) async {
    // Start the app
    app.main();
    await tester.pumpAndSettle();

    // Verify we are on the Meds Screen (or navigate to it if needed)
    // Assuming the bottom navigation has a "Meds" tab with an icon
    final medsTab = find.byIcon(Icons.medication);
    if (medsTab.evaluate().isNotEmpty) {
      await tester.tap(medsTab);
      await tester.pumpAndSettle();
    }

    // Tap the FAB to add a medicine
    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    await tester.tap(fab);
    await tester.pumpAndSettle();

    // Bottom sheet is open, find "Add Medicine"
    expect(find.text('Add Medicine'), findsOneWidget);

    // Enter Medicine details
    await tester.enterText(find.widgetWithText(TextField, 'Medicine Name*'), 'TestIntegrationMed');
    await tester.enterText(find.widgetWithText(TextField, 'Dosage (e.g. 1 tablet)'), '1 pill');
    
    // Select a slot
    await tester.tap(find.text('Morning'));
    await tester.pumpAndSettle();

    // Tap Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify it was added to the list
    expect(find.text('TestIntegrationMed'), findsWidgets);
  });
}
