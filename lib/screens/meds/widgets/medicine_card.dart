import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../models/medicine_model.dart';
import '../../medicine_log_screen.dart';
import '../../../theme/app_theme.dart';
import '../../../services/alarm_action_engine.dart';


class MedicineCard extends StatelessWidget {
  final Medicine med;
  final bool isExpanded;
  final bool canEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleExpand;
  final VoidCallback onShowOptions;
  final VoidCallback onRefill;
  final Function(int delta) onUpdateQty;
  final Map<String, dynamic> slotPrefs;

  const MedicineCard({
    super.key,
    required this.med,
    required this.isExpanded,
    this.canEdit = true,
    required this.onDelete,
    required this.onToggleExpand,
    required this.onShowOptions,
    required this.onRefill,
    required this.onUpdateQty,
    required this.slotPrefs,
  });

  String _formatMedicineChipTime(String timeStr, BuildContext context) {
    try {
      final trimmed = timeStr.trim();
      // Try 12-hour format
      if (trimmed.contains('AM') || trimmed.contains('PM')) {
        final dt = DateFormat('hh:mm a').parseStrict(trimmed);
        return DateFormat('hh:mm a').format(dt);
      }
      // Try 24-hour format
      final parts = trimmed.split(':');
      if (parts.length >= 2) {
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final dt = DateTime(2000, 1, 1, h, m);
        return DateFormat('hh:mm a').format(dt);
      }
      return trimmed;
    } catch (_) {
      // Strip seconds if present
      final stripped = timeStr.replaceAll(RegExp(r':\d{2}$'), '').trim();
      try {
        final parts = stripped.split(':');
        if (parts.length == 2) {
          final dt = DateTime(2000, 1, 1, int.parse(parts[0]), int.parse(parts[1]));
          return DateFormat('hh:mm a').format(dt);
        }
      } catch (_) {}
      return timeStr;
    }
  }

  List<String> _getDynamicActiveTimes() {
    final times = <String>[];
    for (final slot in med.slotTypes) {
      if (slot == 'custom') {
        times.addAll(med.customTimes);
      } else {
        final startStr = slotPrefs['${slot}_start'];
        if (startStr != null) {
          times.add(startStr);
        } else {
          // Default fallbacks
          if (slot == 'morning') times.add('08:00');
          else if (slot == 'afternoon') times.add('12:00');
          else if (slot == 'evening') times.add('16:00');
          else if (slot == 'night') times.add('21:00');
        }
      }
    }
    // Fallback to activeTimes if no slots defined (for backward compatibility)
    if (times.isEmpty) {
      return med.activeTimes;
    }
    return times;
  }

  @override
  Widget build(BuildContext context) {
    final threshold = med.refillReminderThreshold ?? (med.frequency * 3);
    final bool lowStock = med.qty <= threshold;
    final isLight = Theme.of(context).brightness == Brightness.light;
    
    final primaryColor = isLight ? const Color(0xFF0EA5E9) : AppTheme.cyanAccent;
    final secondaryColor = isLight ? const Color(0xFF10B981) : AppTheme.emeraldAccent;
    final errorColor = isLight ? Colors.red : AppTheme.error;
    final surfaceColor = isLight ? Colors.grey[200] : AppTheme.surface1;
    final textColor = isLight ? Colors.grey[600] : AppTheme.textSecondary;

    return Dismissible(
      key: Key(med.id!),
      direction: canEdit ? DismissDirection.endToStart : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: errorColor.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(20)),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.trash2, color: Colors.white),
            Text("Delete", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        if (!canEdit) return false;
        onDelete();
        return false;
      },
      child: Opacity(
        opacity: med.isPaused ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onLongPress: onShowOptions,
                onTap: onToggleExpand,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      Hero(
                        tag: 'med_img_${med.id}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 70, height: 70,
                            color: primaryColor.withValues(alpha: 0.1),
                            child: med.imagePath != null && File(med.imagePath!).existsSync()
                                ? Image.file(File(med.imagePath!), fit: BoxFit.cover)
                                : Icon(LucideIcons.pill, color: primaryColor, size: 30),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(med.name,
                                    style: Theme.of(context).textTheme.titleLarge,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (med.isPaused)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: surfaceColor,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text("Paused",
                                      style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: lowStock ? errorColor.withValues(alpha: 0.15) : secondaryColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: lowStock ? errorColor.withValues(alpha: 0.3) : secondaryColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text("${med.qty} left" + (lowStock ? " • low stock" : ""),
                                    style: TextStyle(color: lowStock ? errorColor : secondaryColor, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text("${DateFormat('dd MMM').format(med.startDate)} → ${DateFormat('dd MMM').format(med.endDate)}",
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _getDynamicActiveTimes().map((t) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(LucideIcons.clock, size: 12, color: primaryColor),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatMedicineChipTime(t, context),
                                      style: TextStyle(fontSize: 12, color: primaryColor, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              )).toList(),
                            ),
                          ],
                        ),
                      ),
                      // Actions
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canEdit)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(LucideIcons.edit3, size: 20, color: textColor),
                              onPressed: onShowOptions,
                            ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                              size: 20,
                              color: primaryColor,
                            ),
                            onPressed: onToggleExpand,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (isExpanded) ...[
                Divider(height: 1, thickness: 1, color: isLight ? Colors.grey.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1)),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Stock Management', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 12,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Qty: ${med.qty}', style: Theme.of(context).textTheme.titleLarge),
                              if (med.refillReminderThreshold != null)
                                Text('Alerts at ${med.refillReminderThreshold} left', style: TextStyle(color: textColor, fontSize: 12))
                              else if (!med.isAsNeeded && med.frequency > 0)
                                Text('Alerts at $threshold left (auto)', style: TextStyle(color: textColor, fontSize: 12)),
                            ],
                          ),
                          if (canEdit)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(LucideIcons.minusCircle, color: errorColor),
                                  onPressed: () => onUpdateQty(-1),
                                ),
                                IconButton(
                                  icon: Icon(LucideIcons.plusCircle, color: secondaryColor),
                                  onPressed: () => onUpdateQty(1),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: onRefill,
                                  icon: const Icon(LucideIcons.packagePlus, size: 16),
                                  label: const Text('Refill'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor.withValues(alpha: 0.2),
                                    foregroundColor: primaryColor,
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ).asGlass(context: context),
        ),
      ),
    ).animate().fade(duration: 400.ms).slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOutQuad);
  }
}
