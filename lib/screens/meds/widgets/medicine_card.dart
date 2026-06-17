import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../models/medicine_model.dart';
import '../../medicine_log_screen.dart';
import '../../../theme/app_theme.dart';

class MedicineCard extends StatelessWidget {
  final Medicine med;
  final bool isExpanded;
  final VoidCallback onDelete;
  final VoidCallback onToggleExpand;
  final VoidCallback onShowOptions;
  final VoidCallback onRefill;
  final Function(int delta) onUpdateQty;

  const MedicineCard({
    super.key,
    required this.med,
    required this.isExpanded,
    required this.onDelete,
    required this.onToggleExpand,
    required this.onShowOptions,
    required this.onRefill,
    required this.onUpdateQty,
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

  @override
  Widget build(BuildContext context) {
    final bool lowStock = med.qty <= med.frequency * 3;
    final isLight = Theme.of(context).brightness == Brightness.light;
    
    final primaryColor = isLight ? const Color(0xFF0EA5E9) : AppTheme.cyanAccent;
    final secondaryColor = isLight ? const Color(0xFF10B981) : AppTheme.emeraldAccent;
    final errorColor = isLight ? Colors.red : AppTheme.error;
    final surfaceColor = isLight ? Colors.grey[200] : AppTheme.surface1;
    final textColor = isLight ? Colors.grey[600] : AppTheme.textSecondary;

    return Dismissible(
      key: Key(med.id!),
      direction: DismissDirection.endToStart,
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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MedicineLogScreen(
                      medicationId: med.id!,
                      medicineName: med.name,
                    ),
                  ),
                ),
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
                                  child: Text("${med.qty} left",
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
                              children: med.activeTimes.map((t) => Container(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Qty: ${med.qty}', style: Theme.of(context).textTheme.titleLarge),
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
