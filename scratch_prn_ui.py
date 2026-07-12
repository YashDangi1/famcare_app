import os

file_path = r"c:\Projects\famcare_app\lib\screens\meds\widgets\medicine_card.dart"
with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

content = "".join(lines)

import_to_add = "import '../../../services/alarm_action_engine.dart';\n"
if import_to_add not in content:
    content = content.replace("import '../../../theme/app_theme.dart';", "import '../../../theme/app_theme.dart';\n" + import_to_add)


old_button = """                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => MedicineLogScreen(
                                  medicationId: med.id!,
                                  medicineName: med.name,
                                ),
                              ),
                            );
                          },
                          icon: Icon(LucideIcons.history, size: 16, color: primaryColor),
                          label: const Text('View Logs'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryColor,
                            side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                          ),
                        ),
                      ),"""

new_button = """                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MedicineLogScreen(
                                      medicationId: med.id!,
                                      medicineName: med.name,
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(LucideIcons.history, size: 16, color: primaryColor),
                              label: const Text('Logs'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: primaryColor,
                                side: BorderSide(color: primaryColor.withValues(alpha: 0.5)),
                              ),
                            ),
                          ),
                          if (med.isAsNeeded && canEdit) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      double tempDose = 1.0;
                                      return StatefulBuilder(
                                        builder: (context, setDialogState) => AlertDialog(
                                          backgroundColor: isLight ? Colors.white : AppTheme.surface1,
                                          title: Text("Log PRN Dose", style: TextStyle(color: isLight ? Colors.black : Colors.white)),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text("How much did you take?", style: TextStyle(color: isLight ? Colors.grey[700] : Colors.white70)),
                                              const SizedBox(height: 20),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  IconButton(
                                                    icon: Icon(Icons.remove_circle_outline, color: isLight ? Colors.black : Colors.white),
                                                    onPressed: () {
                                                      if (tempDose > 0.25) setDialogState(() => tempDose -= 0.25);
                                                    },
                                                  ),
                                                  Text(tempDose.toStringAsFixed(2).replaceAll('.00', ''), style: TextStyle(fontSize: 24, color: isLight ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                                                  IconButton(
                                                    icon: Icon(Icons.add_circle_outline, color: isLight ? Colors.black : Colors.white),
                                                    onPressed: () => setDialogState(() => tempDose += 0.25),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(backgroundColor: secondaryColor),
                                              onPressed: () async {
                                                Navigator.pop(context);
                                                await AlarmActionEngine.instance.logDoseAction(
                                                  medicationId: med.id!,
                                                  medicineName: med.name,
                                                  dosage: '${tempDose} unit(s)',
                                                  status: 'taken',
                                                  slotIndex: 0,
                                                  scheduledTime: DateTime.now(),
                                                  actualDose: tempDose,
                                                  isPrn: true,
                                                );
                                                await AlarmActionEngine.instance.decrementQtyAtomically(med.id!, overrideTakeAmt: tempDose);
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PRN Dose Logged!")));
                                                }
                                              },
                                              child: const Text("Log", style: TextStyle(color: Colors.white)),
                                            ),
                                          ],
                                        )
                                      );
                                    }
                                  );
                                },
                                icon: const Icon(LucideIcons.checkCircle, size: 16),
                                label: const Text('Log Dose'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: secondaryColor,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),"""

content = content.replace(old_button, new_button)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
