import 'dart:io';

void main() {
  final file = File('lib/meds_screen.dart');
  String content = file.readAsStringSync();

  // 1. Add Riverpod imports
  if (!content.contains("import 'package:flutter_riverpod/flutter_riverpod.dart';")) {
    content = content.replaceFirst(
      "import 'package:flutter/material.dart';", 
      "import 'package:flutter/material.dart';\nimport 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'providers/medication_provider.dart';"
    );
  }

  // 2. Change to ConsumerStatefulWidget
  content = content.replaceFirst("class MedsScreen extends StatefulWidget {", "class MedsScreen extends ConsumerStatefulWidget {");
  content = content.replaceFirst("State<MedsScreen> createState() => _MedsScreenState();", "ConsumerState<MedsScreen> createState() => _MedsScreenState();");
  content = content.replaceFirst("class _MedsScreenState extends State<MedsScreen> {", "class _MedsScreenState extends ConsumerState<MedsScreen> {");

  // 3. Remove local state variables
  content = content.replaceAll("List<Medicine> _medications = [];", "");
  content = content.replaceAll("bool _isLoading = true;", "");

  // 4. Update _fetchMedications
  // We'll just replace the inner body to trigger the provider and slot prefs
  final fetchMatch = RegExp(r'Future<void> _fetchMedications\(\) async \{([\s\S]*?)// ==========================================').firstMatch(content);
  if (fetchMatch != null) {
    final newFetch = '''
  Future<void> _fetchMedications() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      // Load slot preferences for card headers
      final slotPrefs = await SlotPreferencesService().getPreferences();

      // Trigger Riverpod fetch (it updates the UI automatically)
      await ref.read(medicationsProvider.notifier).fetchMedications(userId);

      if (mounted) {
        setState(() {
          _slotPrefs = slotPrefs;
        });
      }
    } catch (e) {
      print('Fetch Error: \$e');
    }
  }

  // ==========================================''';
    content = content.replaceRange(fetchMatch.start, fetchMatch.end, newFetch);
  }

  // Write changes
  file.writeAsStringSync(content);
  print("Refactored MedsScreen - Part 1");
}
