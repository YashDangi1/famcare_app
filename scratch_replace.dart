import 'dart:io';

void main() {
  final file = File('lib/meds_screen.dart');
  final lines = file.readAsLinesSync();
  
  final outLines = <String>[];
  bool inAddEdit = false;
  bool inCard = false;
  
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    
    // Add imports
    if (line == "import 'services/activity_service.dart';") {
      outLines.add(line);
      outLines.add("import 'screens/meds/add_medicine_bottom_sheet.dart';");
      outLines.add("import 'screens/meds/widgets/medicine_card.dart';");
      continue;
    }
    
    if (line.contains('Future<void> _showAddEditDialog({Medicine? existingMed}) async {')) {
      inAddEdit = true;
      outLines.add('  Future<void> _showAddEditDialog({Medicine? existingMed}) async {');
      outLines.add('    await showDialog(');
      outLines.add('      context: context,');
      outLines.add('      builder: (context) => AddMedicineBottomSheet(');
      outLines.add('        existingMed: existingMed,');
      outLines.add('        onSave: _handleSave,');
      outLines.add('      ),');
      outLines.add('    );');
      outLines.add('  }');
      continue;
    }
    
    if (inAddEdit) {
      if (line.contains('  Widget _buildSlotChip(String value, String label, IconData icon, List<String> selected,')) {
        inAddEdit = false;
        outLines.add(line);
      }
      continue;
    }
    
    if (line.contains('  Widget _buildMedicineCard(Medicine med) {')) {
      inCard = true;
      outLines.add('  Widget _buildMedicineCard(Medicine med) {');
      outLines.add('    return MedicineCard(');
      outLines.add('      med: med,');
      outLines.add('      isExpanded: _expandedMedId == med.id,');
      outLines.add('      onDelete: () => _deleteMedication(med),');
      outLines.add('      onToggleExpand: () => setState(() => _expandedMedId = _expandedMedId == med.id ? null : med.id),');
      outLines.add('      onShowOptions: () => _showMedicineOptions(med),');
      outLines.add('      onRefill: () => _showRefillDialog(med),');
      outLines.add('      onUpdateQty: (delta) => _updateQty(med, delta),');
      outLines.add('    );');
      outLines.add('  }');
      continue;
    }
    
    if (inCard) {
      if (line.contains('  Widget _buildInactiveMedicineCard(Medicine med) {')) {
        inCard = false;
        outLines.add(line);
      }
      continue;
    }
    
    outLines.add(line);
  }
  
  file.writeAsStringSync(outLines.join('\n'));
  print('Replaced successfully!');
}
