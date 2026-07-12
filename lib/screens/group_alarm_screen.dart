import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/alarm_action_engine.dart';
import '../services/alarm_context_resolver.dart';
import '../models/alarm_context.dart';
import '../utils/snackbar_utils.dart';
import '../main.dart' show activeAlarmIdNotifier;
import 'package:intl/intl.dart';
import 'package:alarm/alarm.dart';

class GroupAlarmScreen extends StatefulWidget {
  final int alarmId;

  const GroupAlarmScreen({
    super.key,
    required this.alarmId,
  });

  @override
  State<GroupAlarmScreen> createState() => _GroupAlarmScreenState();
}

class _GroupAlarmScreenState extends State<GroupAlarmScreen> with SingleTickerProviderStateMixin {
  Timer? _autoDismissTimer;
  Timer? _countdownWarningTimer;
  Timer? _countdownTicker;
  String? _autoDismissWarning;

  bool _isProcessing = false;
  late AnimationController _bellController;
  late Animation<double> _bellAnimation;

  final Set<String> _selectedMedicineIds = {};
  AlarmContext? _context;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _bellController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _bellAnimation = Tween<double>(begin: -0.15, end: 0.15).animate(
      CurvedAnimation(parent: _bellController, curve: Curves.easeInOut),
    );

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadContext();
  }

  Future<void> _loadContext() async {
    final ctx = await AlarmContextResolver.instance.resolveAlarmContext(widget.alarmId);
    if (mounted) {
      if (ctx == null) {
        _dismissScreen();
      } else {
        setState(() {
          _context = ctx;
          _isLoading = false;
          // Select all by default
          for (final medId in _context!.medicationIds) {
            _selectedMedicineIds.add(medId);
          }
        });
        _startAutoDismissTimer();
      }
    }
  }

  @override
  void dispose() {
    _bellController.dispose();
    _autoDismissTimer?.cancel();
    _countdownWarningTimer?.cancel();
    _countdownTicker?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    activeAlarmIdNotifier.value = null;
    super.dispose();
  }

  void _startAutoDismissTimer() {
    const warningBefore = Duration(minutes: 5);
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      final expiryStr = prefs.getString('auto_stop_expiry_${widget.alarmId}');
      final expiry = expiryStr != null ? DateTime.tryParse(expiryStr) : null;
      final remaining = expiry?.difference(DateTime.now());

      if (remaining == null || remaining <= Duration.zero) {
        _handleAutoDismiss();
        return;
      }

      if (remaining <= warningBefore) {
        _startCountdown(remaining);
      } else {
        _countdownWarningTimer = Timer(remaining - warningBefore, () {
          if (!mounted) return;
          _startCountdown(warningBefore);
        });
      }

      _autoDismissTimer = Timer(remaining, () {
        if (!mounted) return;
        _handleAutoDismiss();
      });
    });
  }

  void _startCountdown(Duration duration) {
    int remainingSeconds = duration.inSeconds;
    _countdownTicker?.cancel();
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
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

  void _dismissScreen() {
    if (mounted) {
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      } else {
        SystemNavigator.pop();
      }
    }
  }

  Future<void> _handleAutoDismiss() async {
    if (_context != null) {
      setState(() => _isProcessing = true);
      try {
        await AlarmActionEngine.instance.missGroupDoses(_context!);
      } catch (_) {}
    }
    _dismissScreen();
  }

  Future<void> _onRemindLater() async {
    if (_isProcessing || _context == null) return;

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
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Text('Snooze For', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [5, 10, 15, 30]
                    .map((mins) => ActionChip(
                          label: Text('$mins min', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          backgroundColor: const Color(0xFF334155),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

    setState(() => _isProcessing = true);
    
    try {
      await AlarmActionEngine.instance.snoozeGroupDoses(_context!, _context!.medicationIds, chosen);
      
      if (mounted) {
        final retryTime = DateTime.now().add(Duration(minutes: chosen));
        final timeStr = DateFormat('hh:mm a').format(retryTime);
        AppSnackBar.showSuccess(context, "Snoozed until $timeStr");
        _dismissScreen();
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
    if (_isProcessing || _context == null) return;

    if (_selectedMedicineIds.isEmpty) {
      AppSnackBar.showError(context, "Please select at least one medicine or skip.");
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await AlarmActionEngine.instance.takeGroupDoses(
        _context!, 
        _selectedMedicineIds.toList(), 
        takenEarlier: takenEarlier
      );

      // Remaining unselected meds automatically skipped to clear the alarm state cleanly
      final unselected = _context!.medicationIds.where((m) => !_selectedMedicineIds.contains(m)).toList();
      if (unselected.isNotEmpty) {
        await AlarmActionEngine.instance.skipGroupDoses(_context!, medicationIds: unselected);
      }

      if (mounted) {
        _dismissScreen();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        AppSnackBar.showError(context, "Error: $e");
      }
    }
  }

  Future<void> _onSkipAllToday() async {
    if (_isProcessing || _context == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Skip all doses?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to skip all medicines for this slot today?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel', style: TextStyle(color: Colors.white70))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Skip All', style: TextStyle(color: Colors.orange))),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isProcessing = true);

    try {
      await AlarmActionEngine.instance.skipGroupDoses(_context!);

      if (mounted) {
        AppSnackBar.showInfo(context, "All medicines skipped for this dose");
        _dismissScreen();
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
    if (_isLoading || _context == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1117),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    String slotLabel = _context!.slotKey ?? "Unknown";
    if (slotLabel.startsWith('custom')) slotLabel = 'Custom Time';
    slotLabel = slotLabel[0].toUpperCase() + slotLabel.substring(1).replaceAll('_', ' ');

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1A2332),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Alarm still active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: const Text(
                'Please select your medicines and tap "Mark Selected as Taken", or skip them to dismiss the alarm.',
                style: TextStyle(color: Colors.white70, height: 1.5),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Stay', style: TextStyle(color: Colors.white70))),
                TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Skip All & Go Back', style: TextStyle(color: Colors.orange))),
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
                  Padding(
                    padding: const EdgeInsets.only(top: 8, right: 16),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          // C7: Stop alarm audio only — do NOT clear auto_stop_expiry or ringing_alarm_id.
                          // The background timer must remain active so it can fire missGroupDoses() if
                          // the user doesn't mark medicines via Due Soon before the timer expires.
                          // Previously this called _dismissScreen() which cleared all state.
                          await Alarm.stop(widget.alarmId);
                          _dismissScreen();
                        },
                        icon: const Icon(LucideIcons.home, color: Colors.white70, size: 18),
                        label: const Text('Open App', style: TextStyle(color: Colors.white70)),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedBuilder(
                          animation: _bellAnimation,
                          builder: (context, child) => Transform.rotate(angle: _bellAnimation.value, child: const Icon(LucideIcons.bellRing, color: Colors.amber, size: 20)),
                        ),
                        const SizedBox(width: 8),
                        Text('$slotLabel Reminder', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ],
                    ),
                  ),

                  if (_autoDismissWarning != null) ...[
                    const SizedBox(height: 12),
                    Text(_autoDismissWarning!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],

                  const SizedBox(height: 30),
                  const Text('Time for Meds!', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text('Please take these ${_context!.medicationIds.length} medicines', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                  const SizedBox(height: 4),
                  const Text('All selected by default — uncheck if you haven\'t taken them', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 26),

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: _context!.medicationIds.length,
                      itemBuilder: (context, index) {
                        final medId = _context!.medicationIds[index];
                        final medName = _context!.medicineNames[index];
                        final dosage = _context!.dosages[index];
                        final imagePath = _context!.imagePaths[index];
                        final isSelected = _selectedMedicineIds.contains(medId);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.green.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isSelected ? Colors.green.withValues(alpha: 0.3) : Colors.transparent),
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
                            title: Text(medName, style: TextStyle(color: Colors.white, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 18)),
                            subtitle: Text(dosage, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                            secondary: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                              child: imagePath != null && imagePath.isNotEmpty && File(imagePath).existsSync()
                                  ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(imagePath), fit: BoxFit.cover))
                                  : const Icon(LucideIcons.pill, color: Colors.white, size: 24),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton(
                            onPressed: _isProcessing || _selectedMedicineIds.isEmpty ? null : _onTakeSelected,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              elevation: 0,
                            ),
                            child: _isProcessing
                                ? const CircularProgressIndicator(color: Colors.white)
                                : Text(
                                    _selectedMedicineIds.length == _context!.medicationIds.length ? 'Mark All as Taken' : 'Mark ${_selectedMedicineIds.length} as Taken',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: _isProcessing ? null : _onRemindLater,
                                icon: const Icon(Icons.snooze, color: Colors.white, size: 20),
                                label: const Text('Remind Later', style: TextStyle(color: Colors.white, fontSize: 16)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: _isProcessing ? null : _onSkipAllToday,
                                icon: const Icon(Icons.close, color: Colors.orange, size: 20),
                                label: const Text('Skip All Today', style: TextStyle(color: Colors.orange, fontSize: 16)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.orange.withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            icon: const Icon(LucideIcons.checkCheck, color: Colors.white70),
                            label: const Text('I Already Took These Earlier', style: TextStyle(color: Colors.white70, fontSize: 16)),
                            onPressed: _isProcessing || _selectedMedicineIds.isEmpty ? null : _onAlreadyTookItSelected,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        )
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
