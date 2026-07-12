import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../models/health/symptom_entry.dart';
import '../../providers/health/symptoms_provider.dart';
import '../../utils/snackbar_utils.dart';

class SymptomEntrySheet extends ConsumerStatefulWidget {
  final String? targetUserId;
  final SymptomEntry? existingSymptom; // If editing

  const SymptomEntrySheet({super.key, this.targetUserId, this.existingSymptom});

  @override
  ConsumerState<SymptomEntrySheet> createState() => _SymptomEntrySheetState();
}

class _SymptomEntrySheetState extends ConsumerState<SymptomEntrySheet> {
  final _supabase = Supabase.instance.client;
  final _typeController = TextEditingController();
  final _notesController = TextEditingController();
  final _triggerController = TextEditingController();
  final _durationController = TextEditingController();
  
  double _severity = 3;
  DateTime _startedAt = DateTime.now();
  bool _isSaving = false;

  final List<String> _commonSymptoms = [
    'Headache', 'Fever', 'Cough', 'Nausea', 'Fatigue', 
    'Dizziness', 'Stomach Ache', 'Sore Throat'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingSymptom != null) {
      final s = widget.existingSymptom!;
      _typeController.text = s.symptomType;
      _notesController.text = s.notes ?? '';
      _triggerController.text = s.possibleTrigger ?? '';
      _durationController.text = s.durationMinutes?.toString() ?? '';
      _severity = s.severity.toDouble();
      _startedAt = s.startedAt;
    }
  }

  @override
  void dispose() {
    _typeController.dispose();
    _notesController.dispose();
    _triggerController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startedAt,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startedAt),
    );
    if (time == null || !mounted) return;

    setState(() {
      _startedAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _save() async {
    if (_typeController.text.trim().isEmpty) {
      AppSnackBar.showError(context, 'Please enter a symptom type');
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      final userId = widget.targetUserId ?? _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final symptom = SymptomEntry(
        id: widget.existingSymptom?.id,
        userId: userId,
        symptomType: _typeController.text.trim(),
        severity: _severity.toInt(),
        startedAt: _startedAt,
        durationMinutes: int.tryParse(_durationController.text.trim()),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        possibleTrigger: _triggerController.text.trim().isEmpty ? null : _triggerController.text.trim(),
      );

      if (widget.existingSymptom != null) {
        await ref.read(symptomsProvider.notifier).updateSymptom(symptom, widget.targetUserId);
      } else {
        await ref.read(symptomsProvider.notifier).addSymptom(symptom, widget.targetUserId);
      }

      if (mounted) {
        Navigator.pop(context, true);
        AppSnackBar.showSuccess(context, 'Symptom saved successfully');
      }
    } catch (e) {
      if (mounted) AppSnackBar.showError(context, 'Failed to save symptom: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existingSymptom != null ? 'Edit Symptom' : 'Log Symptom', 
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Common Symptoms Quick Select
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _commonSymptoms.map((s) => Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChip(
                    label: Text(s),
                    backgroundColor: _typeController.text == s ? const Color(0xFF0EA5E9).withOpacity(0.1) : Colors.grey[100],
                    side: BorderSide(color: _typeController.text == s ? const Color(0xFF0EA5E9) : Colors.transparent),
                    onPressed: () {
                      setState(() {
                        _typeController.text = s;
                      });
                    },
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _typeController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Symptom Type *',
                hintText: 'e.g. Headache',
                prefixIcon: const Icon(LucideIcons.activity, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),

            Text('Severity: ${_severity.toInt()}/5', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            Slider(
              value: _severity,
              min: 1,
              max: 5,
              divisions: 4,
              activeColor: _getSeverityColor(_severity.toInt()),
              onChanged: (val) => setState(() => _severity = val),
            ),
            const SizedBox(height: 8),

            InkWell(
              onTap: _pickDateTime,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Started At *',
                  prefixIcon: const Icon(LucideIcons.calendar, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  DateFormat('EEE, dd MMM yyyy • hh:mm a').format(_startedAt),
                  style: const TextStyle(color: Color(0xFF1E293B), fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Duration (mins)',
                      prefixIcon: const Icon(LucideIcons.clock, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _triggerController,
                    decoration: InputDecoration(
                      labelText: 'Possible Trigger',
                      prefixIcon: const Icon(LucideIcons.helpCircle, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                prefixIcon: const Icon(LucideIcons.fileText, size: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EA5E9),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Symptom', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
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
