import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/medicine_model.dart';
import '../services/alarm_service.dart';
import '../services/activity_service.dart';
import '../services/offline_sync_service.dart';
import '../utils/snackbar_utils.dart';
import '../main.dart' show activeAlarmIdNotifier, kSnoozeOffset;
import 'package:intl/intl.dart';

class GroupAlarmScreen extends StatefulWidget {
  final int alarmId;
  final bool isSnooze;
  final List<Medicine> medicines;
  final String slotKey;
  final int alarmSlot;
  final DateTime scheduledTime;

  const GroupAlarmScreen({
    super.key,
    required this.alarmId,
    this.isSnooze = false,
    required this.medicines,
    required this.slotKey,
    required this.alarmSlot,
    required this.scheduledTime,
  });

  @override
  State<GroupAlarmScreen> createState() => _GroupAlarmScreenState();
}

class _GroupAlarmScreenState extends State<GroupAlarmScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _alarmService = AlarmService();

  Timer? _autoDismissTimer;
  Timer? _countdownWarningTimer;
  String? _autoDismissWarning;

  bool _isActionTaken = false;
  bool _isProcessing = false;

  late AnimationController _bellController;
  late Animation<double> _bellAnimation;

  // Selected state for checkboxes
  final Set<String> _selectedMedicineIds = {};

  @override
  void initState() {
    super.initState();
    // Default: all medicines checked
    for (var med in widget.medicines) {
      if (med.id != null) {
        _selectedMedicineIds.add(med.id!);
      }
    }

    _bellController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _bellAnimation = Tween<double>(begin: -0.15, end: 0.15).animate(
      CurvedAnimation(parent: _bellController, curve: Curves.easeInOut),
    );

    _startAutoDismissTimer();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _bellController.dispose();
    _autoDismissTimer?.cancel();
    _countdownWarningTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    activeAlarmIdNotifier.value = null;
    super.dispose();
  }

  void _startAutoDismissTimer() {
    const totalDuration = Duration(minutes: 15);
    const warningBefore = Duration(minutes: 5);

    _countdownWarningTimer = Timer(totalDuration - warningBefore, () {
      if (_isActionTaken || !mounted) return;
      _startCountdown(warningBefore);
    });

    _autoDismissTimer = Timer(totalDuration, () {
      if (_isActionTaken || !mounted) return;
      _handleAutoDismiss();
    });
  }

  void _startCountdown(Duration duration) {
    int remainingSeconds = duration.inSeconds;
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _isActionTaken) {
        timer.cancel();
        return;
      }
      if (remainingSeconds <= 0) {
        timer.cancel();
      } else {
        setState(() {
          final m = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
          final s = (remainingSeconds % 60).toString().padLeft(2, '0');
          _autoDismissWarning = 'Screen auto-closes in $m:$s';
        });
        remainingSeconds--;
      }
    });
  }

  Future<void> _handleAutoDismiss() async {
    setState(() {
      _isProcessing = true;
      _isActionTaken = true;
    });

    try {
      await _alarmService.cancelAlarm(widget.alarmId);
    } catch (e) {
      debugPrint('Auto-dismiss stop alarm error: $e');
    }

    if (mounted) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      } else {
        SystemNavigator.pop();
      }
    }
  }

  Future<bool> _checkAndIncrementSnoozeCount() async {
    const maxSnoozes = 3;
    try {
      final key = 'snooze_count_${widget.slotKey}';
      final prefs = await SharedPreferences.getInstance();
      
      // Reset snooze count if it's a new day
      final lastDateKey = 'snooze_date_${widget.slotKey}';
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final lastDate = prefs.getString(lastDateKey);
      
      int count = prefs.getInt(key) ?? 0;
      
      if (lastDate != todayStr) {
        count = 0;
        await prefs.setString(lastDateKey, todayStr);
      }
      
      if (count >= maxSnoozes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Maximum snoozes reached (3). Please take or skip this dose.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return false;
      }
      await prefs.setInt(key, count + 1);
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _onRemindLater() async {
    if (_isProcessing) return;

    final int? chosen = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (BuildContext ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1E293B),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Text('Snooze For',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [5, 10, 15, 30]
                    .map((mins) => ActionChip(
                          label: Text('$mins min',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          backgroundColor: const Color(0xFF334155),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          onPressed: () => Navigator.of(ctx).pop(mins),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );

    if (chosen == null || !mounted) return;

    final allowed = await _checkAndIncrementSnoozeCount();
    if (!allowed) return;

    setState(() => _isProcessing = true);
    _isActionTaken = true;
    _autoDismissTimer?.cancel();

    try {
      await _alarmService.cancelAlarm(widget.alarmId);
      final fromOriginal = widget.scheduledTime.add(Duration(minutes: chosen));
      final fromNow = DateTime.now().add(const Duration(minutes: 5));
      final retryTime = fromOriginal.isAfter(fromNow) ? fromOriginal : fromNow;

      final slotStr = widget.slotKey.startsWith('custom') ? 'custom' : widget.slotKey;
      
      await _alarmService.scheduleRetryAlarm(
        slot: slotStr,
        slotKey: widget.slotKey,
        retryTime: retryTime,
        remainingMedicineNames: widget.medicines.map((m) => m.name).toList(),
        remainingMedicationIdsJson: jsonEncode(widget.medicines.map((m) => m.id).whereType<String>().toList()),
      );
      
      final snoozeTime = retryTime;

      if (mounted) {
        final timeStr = DateFormat('hh:mm a').format(snoozeTime);
        AppSnackBar.showSuccess(context, "Snoozed until $timeStr");
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        } else {
          SystemNavigator.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        AppSnackBar.showError(context, "Error snoozing: $e");
      }
    }
  }

  Future<void> _onAlreadyTookItSelected() async {
    await _onTakeSelected(takenEarlier: true);
  }

  Future<void> _onTakeSelected({bool takenEarlier = false}) async {
    if (_isProcessing) return;

    if (_selectedMedicineIds.isEmpty) {
      AppSnackBar.showError(
          context, "Please select at least one medicine or skip.");
      return;
    }

    setState(() => _isProcessing = true);
    _isActionTaken = true;
    _autoDismissTimer?.cancel();

    try {
      await _alarmService.cancelAlarm(widget.alarmId);
      final userId = _supabase.auth.currentUser?.id;

      final now = DateTime.now();

      // Process each selected medicine
      for (final med in widget.medicines) {
        if (med.id == null || !_selectedMedicineIds.contains(med.id)) continue;

        // Phase 3: Atomic decrement via RPC
        int newQty = 0;
        try {
          final result = await _supabase
              .rpc('decrement_medicine_qty', params: {'med_id': med.id!});
          newQty = result as int;
        } catch (e) {
          debugPrint("RPC failed, falling back to manual: $e");
          int currentQty = med.qty;
          try {
            final latest = await _supabase
                .from('medications')
                .select('qty')
                .eq('id', med.id!)
                .maybeSingle();
            if (latest != null) {
              currentQty = int.tryParse(latest['qty'].toString()) ?? currentQty;
            }
          } catch (err) {}
          newQty = (currentQty - 1).clamp(0, 99999);

          await _supabase
              .from('medications')
              .update({'qty': newQty, if (newQty == 0) 'is_active': false}).eq(
                  'id', med.id!);
        }

        try {
          await _supabase.from('medicine_logs').insert({
            'user_id': userId,
            'medication_id': med.id,
            'medicine_name': med.name,
            'dosage': med.dosage,
            'status': 'taken',
            'alarm_slot': widget.alarmSlot,
            'scheduled_time': widget.scheduledTime.toIso8601String(),
            'created_at': takenEarlier
                ? widget.scheduledTime.toIso8601String()
                : now.toIso8601String(),
          });
        } catch (e) {
          if (OfflineSyncService.isOfflineError(e)) {
            await OfflineSyncService.instance.enqueueAction(
              type: 'medications_update_qty',
              payload: {
                'id': med.id,
                'qty': newQty,
                'is_active': newQty == 0 ? false : null
              },
            );
            await OfflineSyncService.instance.enqueueAction(
              type: 'medicine_logs_insert',
              payload: {
                'user_id': userId,
                'medication_id': med.id,
                'medicine_name': med.name,
                'dosage': med.dosage,
                'status': 'taken',
                'alarm_slot': widget.alarmSlot,
                'scheduled_time': widget.scheduledTime.toIso8601String(),
                'created_at': now.toIso8601String(),
              },
            );
          } else {
            rethrow;
          }
        }
      }

      try {
        await ActivityService.log(
          actionType: 'MEDICINE_TAKEN',
          description: 'Took ${_selectedMedicineIds.length} medicines',
        );
      } catch (e) {
        debugPrint('Feed log error: $e');
      }

      if (mounted) {
        // Return selected IDs so dashboard knows which ones were taken
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop(_selectedMedicineIds.toList());
        } else {
          SystemNavigator.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        AppSnackBar.showError(context, "Error: $e");
      }
    }
  }

  Future<void> _onSkipAllToday() async {
    if (_isProcessing) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Skip all doses?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'Are you sure you want to skip all medicines for this slot today?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.white70))),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Skip All',
                  style: TextStyle(color: Colors.orange))),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isProcessing = true);
    _isActionTaken = true;
    _autoDismissTimer?.cancel();

    try {
      await _alarmService.cancelAlarm(widget.alarmId);
      final userId = _supabase.auth.currentUser?.id;

      if (userId != null) {
        for (final med in widget.medicines) {
          if (med.id == null) continue;
          final nowStr = DateTime.now().toIso8601String();
          try {
            await _supabase.from('medicine_logs').insert({
              'user_id': userId,
              'medication_id': med.id,
              'medicine_name': med.name,
              'dosage': med.dosage,
              'status': 'skipped',
              'alarm_slot': widget.alarmSlot,
              'scheduled_time': widget.scheduledTime.toIso8601String(),
              'created_at': nowStr,
            });
          } catch (e) {
            if (OfflineSyncService.isOfflineError(e)) {
              await OfflineSyncService.instance.enqueueAction(
                type: 'medicine_logs_insert',
                payload: {
                  'user_id': userId,
                  'medication_id': med.id,
                  'medicine_name': med.name,
                  'dosage': med.dosage,
                  'status': 'skipped',
                  'alarm_slot': widget.alarmSlot,
                  'scheduled_time': widget.scheduledTime.toIso8601String(),
                  'created_at': nowStr,
                },
              );
            } else {
              rethrow;
            }
          }
        }
      }

      if (mounted) {
        AppSnackBar.showInfo(context, "All medicines skipped for this dose");
        // Return empty list so dashboard knows they were skipped
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop(<String>[]);
        } else {
          SystemNavigator.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        AppSnackBar.showError(context, "Error skipping: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String slotLabel = widget.slotKey;
    if (slotLabel.startsWith('custom')) slotLabel = 'Custom Time';
    slotLabel = slotLabel[0].toUpperCase() +
        slotLabel.substring(1).replaceAll('_', ' ');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          if (_isActionTaken) return;
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1A2332),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: const Text('Alarm still active',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              content: const Text(
                'Please select your medicines and tap "Mark Selected as Taken", or skip them to dismiss the alarm.',
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Stay',
                        style: TextStyle(color: Colors.white70))),
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Skip All & Go Back',
                        style: TextStyle(color: Colors.orange))),
              ],
            ),
          );
          if (confirm == true && mounted) {
            await _onSkipAllToday();
          }
        },
        child: Scaffold(
          body: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0D1117), Color(0xFF1A2332)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // Top Status
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _bellAnimation,
                          builder: (context, child) => Transform.rotate(
                              angle: _bellAnimation.value,
                              child: const Icon(LucideIcons.bellRing,
                                  color: Colors.amber, size: 20)),
                        ),
                        const SizedBox(width: 8),
                        Text('$slotLabel Reminder',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2)),
                      ],
                    ),
                  ),

                  if (_autoDismissWarning != null) ...[
                    const SizedBox(height: 12),
                    Text(_autoDismissWarning!,
                        style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ],

                  const SizedBox(height: 30),

                  // Title
                  const Text('Time for Meds!',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('Please take these ${widget.medicines.length} medicines',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text(
                      'All selected by default — uncheck if you haven\'t taken them',
                      style: TextStyle(
                          color: Colors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 26),

                  // Medicines List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: widget.medicines.length,
                      itemBuilder: (context, index) {
                        final med = widget.medicines[index];
                        final medId = med.id ?? '';
                        final isSelected = _selectedMedicineIds.contains(medId);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: isSelected
                                    ? Colors.green.withValues(alpha: 0.3)
                                    : Colors.transparent),
                          ),
                          child: CheckboxListTile(
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedMedicineIds.add(medId);
                                } else {
                                  _selectedMedicineIds.remove(medId);
                                }
                              });
                            },
                            activeColor: Colors.green,
                            checkColor: Colors.white,
                            title: Text(med.name,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 18)),
                            subtitle: Text('${med.dosage} • ${med.qty} left',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 14)),
                            secondary: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12)),
                              child: med.imagePath != null &&
                                      med.imagePath!.isNotEmpty &&
                                      File(med.imagePath!).existsSync()
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(File(med.imagePath!),
                                          fit: BoxFit.cover))
                                  : const Icon(LucideIcons.pill,
                                      color: Colors.white, size: 24),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Action Buttons
                  Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed:
                                _isProcessing || _selectedMedicineIds.isEmpty
                                    ? null
                                    : _onTakeSelected,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                            child: _isProcessing
                                ? const CircularProgressIndicator(
                                    color: Colors.white)
                                : Text(
                                    _selectedMedicineIds.length ==
                                            widget.medicines.length
                                        ? 'Mark All as Taken'
                                        : 'Mark ${_selectedMedicineIds.length} as Taken',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed:
                                    _isProcessing ? null : _onRemindLater,
                                icon: const Icon(Icons.snooze,
                                    color: Colors.white, size: 20),
                                label: const Text('Remind Later',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 16)),
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextButton.icon(
                                onPressed:
                                    _isProcessing ? null : _onSkipAllToday,
                                icon: const Icon(Icons.close,
                                    color: Colors.orange, size: 20),
                                label: const Text('Skip All Today',
                                    style: TextStyle(
                                        color: Colors.orange, fontSize: 16)),
                                style: TextButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor:
                                      Colors.orange.withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            icon: const Icon(LucideIcons.checkCheck,
                                color: Colors.white70),
                            label: const Text('I Already Took These Earlier',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 16)),
                            onPressed:
                                _isProcessing || _selectedMedicineIds.isEmpty
                                    ? null
                                    : _onAlreadyTookItSelected,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
