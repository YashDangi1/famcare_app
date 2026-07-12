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

class AlarmScreen extends StatefulWidget {
  final int alarmId;

  const AlarmScreen({
    super.key,
    required this.alarmId,
  });

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> with SingleTickerProviderStateMixin {
  Timer? _autoDismissTimer;
  bool _isProcessing = false;
  late AnimationController _bellController;
  late Animation<double> _bellAnimation;
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
        });
        _startAutoDismissTimer();
      }
    }
  }

  @override
  void dispose() {
    _bellController.dispose();
    _autoDismissTimer?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    activeAlarmIdNotifier.value = null;
    super.dispose();
  }

  void _startAutoDismissTimer() {
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      final expiryStr = prefs.getString('auto_stop_expiry_${widget.alarmId}');
      final expiry = expiryStr != null ? DateTime.tryParse(expiryStr) : null;
      final remaining = expiry?.difference(DateTime.now());

      if (remaining == null || remaining <= Duration.zero) {
        _handleMissedDose();
        return;
      }

      _autoDismissTimer = Timer(remaining, _handleMissedDose);
    });
  }

  Future<void> _handleMissedDose() async {
    if (_context != null) {
      if (_context!.isSingle) {
        await AlarmActionEngine.instance.missSingleDose(_context!);
      } else {
        await AlarmActionEngine.instance.missGroupDoses(_context!);
      }
    }
    _dismissScreen();
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

  Future<void> _onTakeItWithFeedback({double? actualDose}) async {
    if (_isProcessing || _context == null) return;
    setState(() => _isProcessing = true);
    
    try {
      if (_context!.isSingle) {
        await AlarmActionEngine.instance.takeSingleDose(_context!, actualDose: actualDose);
      } else {
        await AlarmActionEngine.instance.takeGroupDoses(_context!, _context!.medicationIds);
      }
      
      if (mounted) {
        AppSnackBar.showSuccess(context, "Great! Medicine marked as taken");
        _dismissScreen();
      }
    } catch (e) {
      debugPrint("Error in _onTakeIt: $e");
      if (mounted) {
        AppSnackBar.showError(context, "Failed to update: $e");
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _onTakeLaterWithFeedback(int minutes) async {
    if (_isProcessing || _context == null) return;
    setState(() => _isProcessing = true);
    
    try {
      if (_context!.isSingle) {
        await AlarmActionEngine.instance.snoozeSingleDose(_context!, minutes);
      } else {
        await AlarmActionEngine.instance.snoozeGroupDoses(_context!, _context!.medicationIds, minutes);
      }

      if (mounted) {
        AppSnackBar.showSuccess(context, "Reminder set for $minutes min later");
        _dismissScreen();
      }
    } catch (e) {
      debugPrint("Error in _onTakeLater: $e");
      if (mounted) {
        AppSnackBar.showError(context, "Failed to snooze: $e");
        setState(() => _isProcessing = false);
      }
    }
  }
  
  void _showSnoozeOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2332),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Snooze Reminder", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(LucideIcons.clock, color: Colors.amber),
                title: const Text("Snooze for 15 minutes", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _onTakeLaterWithFeedback(15);
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.clock, color: Colors.amber),
                title: const Text("Snooze for 30 minutes", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _onTakeLaterWithFeedback(30);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDoseAdjustmentDialog() {
    if (_context == null || !_context!.isSingle) return;
    final dosageString = _context!.dosages.first;
    final match = RegExp(r'^([\d\.]+)').firstMatch(dosageString);
    double currentDose = 1.0;
    if (match != null) {
      currentDose = double.tryParse(match.group(1) ?? '1.0') ?? 1.0;
    }

    showDialog(
      context: context,
      builder: (context) {
        double tempDose = currentDose;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A2332),
              title: const Text("Adjust Dose", style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("How much did you actually take?", style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
                        onPressed: () {
                          if (tempDose > 0.25) setDialogState(() => tempDose -= 0.25);
                        },
                      ),
                      Text(tempDose.toStringAsFixed(2).replaceAll('.00', ''), style: const TextStyle(fontSize: 24, color: Colors.white, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Colors.white),
                        onPressed: () {
                          setDialogState(() => tempDose += 0.25);
                        },
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () {
                    Navigator.pop(context);
                    _onTakeItWithFeedback(actualDose: tempDose);
                  },
                  child: const Text("Log Dose", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _onSkipWithFeedback() async {
    if (_isProcessing || _context == null) return;
    setState(() => _isProcessing = true);

    try {
      if (_context!.isSingle) {
        await AlarmActionEngine.instance.skipSingleDose(_context!);
      } else {
        await AlarmActionEngine.instance.skipGroupDoses(_context!);
      }

      if (mounted) {
        AppSnackBar.showSuccess(context, "Dose skipped");
        _dismissScreen();
      }
    } catch (e) {
      debugPrint("Error in _onSkip: $e");
      if (mounted) {
        AppSnackBar.showError(context, "Failed to skip: $e");
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1117),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    // For group alarms show a human-readable slot name, not the raw slotKey
    String _slotLabel(String key) {
      if (key.startsWith('custom')) return 'Custom Time Reminder';
      switch (key) {
        case 'morning': return 'Morning Medicines';
        case 'afternoon': return 'Afternoon Medicines';
        case 'evening': return 'Evening Medicines';
        case 'night': return 'Night Medicines';
        default: return 'Medicine Reminder';
      }
    }
    final medName = _context!.isGroup
        ? _slotLabel((_context!.slotKey ?? '').split('_').first)
        : _context!.medicineNames.first;
    final dosage = _context!.isGroup
        ? _context!.medicineNames.join(', ')
        : _context!.dosages.first;
    final imagePath = _context!.isSingle ? _context!.imagePaths.first : null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: false,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                    ),
                    child: ClipOval(
                      child: imagePath != null && imagePath.isNotEmpty
                          ? FutureBuilder<bool>(
                              future: File(imagePath).exists(),
                              builder: (context, snapshot) {
                                if (snapshot.data == true) {
                                  return Image.file(
                                    File(imagePath),
                                    fit: BoxFit.cover,
                                  );
                                }
                                return const Icon(LucideIcons.pill, size: 80, color: Colors.white70);
                              },
                            )
                          : const Icon(LucideIcons.pill, size: 80, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(height: 30),
                  AnimatedBuilder(
                    animation: _bellAnimation,
                    builder: (_, child) => Transform.rotate(
                      angle: _bellAnimation.value,
                      child: const Icon(LucideIcons.bellRing, size: 40, color: Color(0xFFF59E0B)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "MEDICATION REMINDER",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      medName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      dosage,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildAlarmButton(
                                label: "Snooze",
                                color: Colors.amber[700]!,
                                onTap: _showSnoozeOptions,
                                isLoading: _isProcessing,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: _buildAlarmButton(
                                label: "I Took It",
                                color: Colors.green[600]!,
                                onTap: _onTakeItWithFeedback,
                                isLoading: _isProcessing,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              onPressed: _isProcessing ? null : _onSkipWithFeedback,
                              child: const Text("Skip Dose", style: TextStyle(color: Colors.white54, fontSize: 16)),
                            ),
                            if (_context?.isSingle == true)
                              TextButton(
                                onPressed: _isProcessing ? null : _showDoseAdjustmentDialog,
                                child: const Text("Change Dose", style: TextStyle(color: Colors.white54, fontSize: 16)),
                              ),
                          ],
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

  Widget _buildAlarmButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return ElevatedButton(
      onPressed: isLoading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: color.withOpacity(0.6),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 10,
        shadowColor: color.withOpacity(0.5),
      ),
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            )
          : Text(
              label,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
}
