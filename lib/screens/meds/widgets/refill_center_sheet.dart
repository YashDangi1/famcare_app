import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../models/medicine_model.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/snackbar_utils.dart';

class RefillCenterSheet extends StatefulWidget {
  final List<Medicine> medications;
  final VoidCallback onRefillComplete;

  const RefillCenterSheet({
    super.key,
    required this.medications,
    required this.onRefillComplete,
  });

  @override
  State<RefillCenterSheet> createState() => _RefillCenterSheetState();
}

class _RefillCenterSheetState extends State<RefillCenterSheet> {
  final _supabase = Supabase.instance.client;
  bool _isUpdating = false;
  late List<Medicine> _localMedications;

  @override
  void initState() {
    super.initState();
    _localMedications = List.from(widget.medications);
  }

  int _getEffectiveRefillThreshold(Medicine med) {
    return med.refillReminderThreshold ?? (med.frequency * 3);
  }

  int _getEstimatedDaysLeft(Medicine med) {
    final takeAmt = double.tryParse(med.takeAmount ?? '1') ?? 1.0;
    if (med.frequency <= 0 || takeAmt <= 0) return 0;
    final estimated = (med.qty / takeAmt / med.frequency).floor();
    return estimated < 0 ? 0 : estimated;
  }

  Future<void> _updateRefill(Medicine med, int addedQty) async {
    if (med.id == null || _isUpdating) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final newQty = med.qty + addedQty;
      await _supabase.from('medications').update({
        'qty': newQty,
        'low_stock_alerted': false, // Reset alert flag on refill
      }).eq('id', med.id!);

      if (mounted) {
        setState(() {
          final index = _localMedications.indexWhere((m) => m.id == med.id);
          if (index != -1) {
            _localMedications[index] = _localMedications[index].copyWith(qty: newQty, lowStockAlerted: false);
          }
        });
        AppSnackBar.showSuccess(context, 'Added $addedQty to ${med.name}');
        widget.onRefillComplete();
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, 'Failed to update stock: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  void _showCustomRefillDialog(Medicine med) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Custom Refill - ${med.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Amount to add',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text) ?? 0;
              Navigator.pop(ctx);
              if (val > 0) {
                _updateRefill(med, val);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sort: Low stock items first, then by days left
    final sortedMeds = List<Medicine>.from(_localMedications.where((m) => m.isActive && !m.isAsNeeded));
    sortedMeds.sort((a, b) {
      final aThreshold = _getEffectiveRefillThreshold(a);
      final bThreshold = _getEffectiveRefillThreshold(b);
      final aIsLow = a.qty <= aThreshold;
      final bIsLow = b.qty <= bThreshold;

      if (aIsLow && !bIsLow) return -1;
      if (!aIsLow && bIsLow) return 1;

      return _getEstimatedDaysLeft(a).compareTo(_getEstimatedDaysLeft(b));
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.packageSearch, color: AppTheme.cyanAccent),
                    SizedBox(width: 12),
                    Text(
                      'Refill Center',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(),
          // List
          Expanded(
            child: sortedMeds.isEmpty
                ? const Center(child: Text("No active medications found."))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: sortedMeds.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final med = sortedMeds[index];
                      return _buildMedCard(med);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedCard(Medicine med) {
    final threshold = _getEffectiveRefillThreshold(med);
    final isLowStock = med.qty <= threshold;
    final isCritical = med.qty <= 0;
    final daysLeft = _getEstimatedDaysLeft(med);

    Color statusColor;
    if (isCritical) {
      statusColor = Colors.red;
    } else if (isLowStock) {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  med.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.pill, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      '${med.qty} left',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isCritical
                ? 'Out of stock!'
                : 'Est. ~${daysLeft} days left (${med.getCurrentDosage(DateTime.now())})',
            style: TextStyle(
              color: isCritical ? Colors.red : Colors.grey[600],
              fontWeight: isCritical ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 16),
          // Quick actions
          Row(
            children: [
              _buildQuickActionButton(med, 10, '+10'),
              const SizedBox(width: 8),
              _buildQuickActionButton(med, 30, '+30'),
              const SizedBox(width: 8),
              _buildQuickActionButton(med, 60, '+60'),
              const Spacer(),
              TextButton.icon(
                onPressed: _isUpdating ? null : () => _showCustomRefillDialog(med),
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Custom'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.cyanAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(Medicine med, int amount, String label) {
    return InkWell(
      onTap: _isUpdating ? null : () => _updateRefill(med, amount),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.cyanAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.cyanAccent.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.cyanAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
