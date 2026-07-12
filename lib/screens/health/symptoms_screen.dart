import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../models/health/symptom_entry.dart';
import '../../providers/health/symptoms_provider.dart';
import 'symptom_entry_sheet.dart';

class SymptomsScreen extends ConsumerStatefulWidget {
  final String? targetUserId;
  final String? targetUserName;

  const SymptomsScreen({
    super.key,
    this.targetUserId,
    this.targetUserName,
  });

  @override
  ConsumerState<SymptomsScreen> createState() => _SymptomsScreenState();
}

class _SymptomsScreenState extends ConsumerState<SymptomsScreen> {
  @override
  void initState() {
    super.initState();
    // Use Future.microtask to avoid modifying providers during build phase
    Future.microtask(() => ref.read(symptomsProvider.notifier).fetchSymptoms(widget.targetUserId));
  }

  void _showSymptomSheet([SymptomEntry? existingSymptom]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SymptomEntrySheet(
        targetUserId: widget.targetUserId,
        existingSymptom: existingSymptom,
      ),
    );
  }

  Future<void> _deleteSymptom(SymptomEntry symptom) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Symptom'),
        content: const Text('Are you sure you want to delete this symptom log?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && symptom.id != null) {
      try {
        await ref.read(symptomsProvider.notifier).deleteSymptom(symptom.id!, widget.targetUserId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Symptom deleted')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final symptomsState = ref.watch(symptomsProvider);
    final isViewingOther = widget.targetUserId != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: isViewingOther
          ? null
          : FloatingActionButton(
              heroTag: 'add_symptom_fab',
              onPressed: () => _showSymptomSheet(),
              backgroundColor: const Color(0xFF0EA5E9),
              child: const Icon(LucideIcons.plus, color: Colors.white),
            ),
      body: symptomsState.when(
        loading: () => _buildSkeletonLoader(),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.alertTriangle, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text('Error loading symptoms: $err', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(symptomsProvider.notifier).fetchSymptoms(widget.targetUserId),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (symptoms) {
          if (symptoms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.activitySquare, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    isViewingOther ? 'No symptoms logged' : 'No symptoms logged yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isViewingOther ? 'This user has not logged any symptoms.' : 'Tap the + button to log a symptom.',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(symptomsProvider.notifier).fetchSymptoms(widget.targetUserId),
            child: ListView.builder(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100), // padding for FAB
              itemCount: symptoms.length,
              itemBuilder: (context, index) {
                final s = symptoms[index];
                return _buildSymptomCard(s, isViewingOther);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSymptomCard(SymptomEntry symptom, bool isViewingOther) {
    final severityColor = _getSeverityColor(symptom.severity);
    final dateStr = DateFormat('EEE, dd MMM yyyy • hh:mm a').format(symptom.startedAt);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(LucideIcons.activitySquare, color: severityColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              symptom.symptomType,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B)),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: severityColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Severity: ${symptom.severity}/5',
                              style: TextStyle(color: severityColor, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(dateStr, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                      
                      if (symptom.durationMinutes != null || symptom.possibleTrigger != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            if (symptom.durationMinutes != null)
                              _buildPill(LucideIcons.clock, '${symptom.durationMinutes} mins'),
                            if (symptom.possibleTrigger != null)
                              _buildPill(LucideIcons.target, symptom.possibleTrigger!),
                          ],
                        ),
                      ],

                      if (symptom.notes != null && symptom.notes!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            symptom.notes!,
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isViewingOther) ...[
            Divider(height: 1, color: Colors.grey.shade100),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showSymptomSheet(symptom),
                    icon: Icon(LucideIcons.edit2, size: 16, color: Colors.grey.shade600),
                    label: Text('Edit', style: TextStyle(color: Colors.grey.shade600)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16))),
                    ),
                  ),
                ),
                Container(width: 1, height: 20, color: Colors.grey.shade200),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _deleteSymptom(symptom),
                    icon: Icon(LucideIcons.trash2, size: 16, color: Colors.red.shade400),
                    label: Text('Delete', style: TextStyle(color: Colors.red.shade400)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomRight: Radius.circular(16))),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }

  Color _getSeverityColor(int severity) {
    switch (severity) {
      case 1: return Colors.green;
      case 2: return Colors.lightGreen;
      case 3: return Colors.orangeAccent;
      case 4: return Colors.orange;
      case 5: return Colors.red;
      default: return Colors.blue;
    }
  }
}
