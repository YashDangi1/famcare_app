import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:alarm/alarm.dart';
import '../services/alarm_service.dart';
import '../services/notification_service.dart';
import '../services/activity_service.dart';
import '../utils/snackbar_utils.dart';
import '../main.dart' show activeAlarmIdNotifier, kSnoozeOffset;

class AlarmScreen extends StatefulWidget {
  final int alarmId;
  final bool isSnooze; // ✅ Add this flag
  final String medicineName;
  final String? imagePath;
  final String dosage;
  final int qty;
  final String medicationId;
  final int alarmSlot;
  final DateTime scheduledTime;

  const AlarmScreen({
    super.key,
    required this.alarmId,
    this.isSnooze = false, // ✅ Default to false
    required this.medicineName,
    this.imagePath,
    required this.dosage,
    required this.qty,
    required this.medicationId,
    required this.alarmSlot,
    required this.scheduledTime,
  });

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _alarmService = AlarmService();
  Timer? _autoDismissTimer;
  bool _isActionTaken = false;
  bool _isProcessing = false;
  late AnimationController _bellController;
  late Animation<double> _bellAnimation;

  @override
  void initState() {
    super.initState();
    // Bell ringing animation
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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // ✅ Reset alarm notifier so app doesn't stay in "alarm mode"
    activeAlarmIdNotifier.value = null;

    super.dispose();
  }

  void _startAutoDismissTimer() {
    // Auto-dismiss after 30 minutes if no interaction
    _autoDismissTimer = Timer(const Duration(minutes: 30), () {
      _handleMissedDose();
    });
  }

  Future<void> _handleMissedDose({bool explicitSkip = false}) async {
    if (_isActionTaken) return; // ✅ Double execution rokna
    _isActionTaken = true;
    
    try {
      await Alarm.stop(widget.alarmId);
      await _logDoseStatus(explicitSkip ? 'skipped' : 'missed');
      
      // ✅ WhatsApp Notification Logic (Only for missed, not for intentionally skipped unless requested)
      if (!explicitSkip) {
        await _informFamilyOfMissedDose();
      }
      
      try {
        await ActivityService.log(
          actionType: explicitSkip ? 'MEDICINE_SKIPPED' : 'MEDICINE_MISSED',
          description: '${explicitSkip ? 'Skipped' : 'Missed'} ${widget.medicineName}',
        );
      } catch (e) {
        debugPrint('Activity log error: $e');
      }

      if (mounted) {
        if (explicitSkip) {
          AppSnackBar.showSuccess(context, "Dose skipped. Logged successfully.");
        }
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        } else {
          SystemNavigator.pop();
        }
      }
    } catch (e) {
      debugPrint("Error logging missed/skipped dose: $e");
    }
  }

  Future<void> _informFamilyOfMissedDose() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Get user profile name
      final profile = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .maybeSingle();
      final userName = profile?['full_name'] ?? "Someone";

      // 2. Find group_id
      final membership = await _supabase
          .from('family_members')
          .select('group_id')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (membership == null) return;
      final groupId = membership['group_id'];

      // 3. Send WhatsApp alerts to admins via NotificationService
      await NotificationService().sendMissedMedicineAlert(
        patientName: userName,
        medicineName: widget.medicineName,
        scheduledTime: widget.scheduledTime,
      );
    } catch (e) {
      debugPrint("Error informing family: $e");
    }
  }

  Future<void> _logDoseStatus(String status) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    
    // ✅ medicationId empty ya invalid ho to skip karo
    if (widget.medicationId.isEmpty) {
      debugPrint("Skipping log — no valid medicationId");
      return;
    }

    await _supabase.from('medicine_logs').insert({
      'user_id': userId,
      'medication_id': widget.medicationId,
      'medicine_name': widget.medicineName,
      'dosage': widget.dosage,
      'status': status,
      'alarm_slot': widget.alarmSlot,
      'scheduled_time': widget.scheduledTime.toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _onTakeItWithFeedback() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    await _onTakeIt();
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _onTakeLaterWithFeedback() async {
    if (_isProcessing) return;
    
    // Show snooze options
    final int? mins = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF1A2332),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Snooze for...", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12, runSpacing: 12,
              children: [
                _snoozeChip(ctx, 10, "10 mins"),
                _snoozeChip(ctx, 20, "20 mins"),
                _snoozeChip(ctx, 30, "30 mins"),
                _snoozeChip(ctx, 60, "1 hour"),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      )
    );

    if (mins == null) return; // cancelled

    setState(() => _isProcessing = true);
    await _onTakeLater(mins);
    if (mounted) setState(() => _isProcessing = false);
  }

  Widget _snoozeChip(BuildContext ctx, int minutes, String label) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.white.withOpacity(0.1),
      labelStyle: const TextStyle(color: Colors.white),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.transparent)),
      onPressed: () => Navigator.pop(ctx, minutes),
    );
  }

  Future<void> _onSkipWithFeedback() async {
    if (_isProcessing) return;
    
    // Confirm skip
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        title: const Text("Skip Dose?", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to skip taking ${widget.medicineName}?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[400]),
            child: const Text("Yes, Skip", style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    await _handleMissedDose(explicitSkip: true);
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _onTakeIt() async {
    if (_isActionTaken) return;
    _isActionTaken = true;
    _autoDismissTimer?.cancel();
    try {
      await Alarm.stop(widget.alarmId);

      // Guard: If no valid medicationId, just dismiss (fallback alarm)
      if (widget.medicationId.isEmpty) {
        debugPrint("No medicationId — dismissing alarm without DB update");
        if (mounted) {
          AppSnackBar.showSuccess(context, "Medicine marked as taken!");
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          } else {
            SystemNavigator.pop();
          }
        }
        return;
      }

      // Fresh DB se latest qty fetch karo
      final latest = await _supabase
          .from('medications')
          .select('qty, frequency')
          .eq('id', widget.medicationId)
          .maybeSingle();

      if (latest == null) {
        debugPrint("Medication not found in DB — may have been deleted");
        if (mounted) {
          AppSnackBar.showSuccess(context, "Medicine marked as taken!");
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          } else {
            SystemNavigator.pop();
          }
        }
        return;
      }

      final currentQty = int.tryParse(latest['qty'].toString()) ?? 0;
      final newQty = (currentQty - 1).clamp(0, 99999);

      await _supabase
          .from('medications')
          .update({'qty': newQty})
          .eq('id', widget.medicationId);

      if (newQty == 0) {
        await _supabase
            .from('medications')
            .update({'is_active': false})
            .eq('id', widget.medicationId);
      }

      await _logDoseStatus('taken');
      try {
        await ActivityService.log(
          actionType: 'MEDICINE_TAKEN',
          description: 'Took ${widget.medicineName}',
        );
      } catch (e) {
        debugPrint('Activity log error: $e');
      }

      // Clean up cached alarm data
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cached_med_${widget.alarmId}');
      } catch (_) {}

      if (mounted) {
        if (newQty == 0) {
          AppSnackBar.showError(context, "Medicine stock is over. Please refill.");
        } else {
          AppSnackBar.showSuccess(context, "Great! Medicine marked as taken");
        }
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        } else {
          SystemNavigator.pop();
        }
      }
    } catch (e) {
      debugPrint("Error in _onTakeIt: $e");
      if (mounted) {
        AppSnackBar.showError(context, "Failed to update: $e");
      }
    }
  }

  Future<void> _onTakeLater(int snoozeMinutes) async {
    if (_isActionTaken) return;
    _isActionTaken = true;
    _autoDismissTimer?.cancel();
    try {
      await Alarm.stop(widget.alarmId);

      final baseId = widget.isSnooze ? widget.alarmId - kSnoozeOffset : widget.alarmId;

      await _alarmService.scheduleSnoozeAlarm(
        originalId: baseId,
        medicineName: widget.medicineName,
        originalTime: widget.scheduledTime,
        snoozeDurationMinutes: snoozeMinutes,
      );

      // Only log if valid medicationId
      if (widget.medicationId.isNotEmpty) {
        await _logDoseStatus('snoozed');
      }

      // Clean up cached alarm data
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('cached_med_${widget.alarmId}');
      } catch (_) {}

      if (mounted) {
        AppSnackBar.showSuccess(context, "Reminder set for $snoozeMinutes min later");
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        } else {
          SystemNavigator.pop();
        }
      }
    } catch (e) {
      debugPrint("Error in _onTakeLater: $e");
      if (mounted) {
        AppSnackBar.showError(context, "Failed to snooze: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: PopScope(
        canPop: false, // Prevent back button from dismissing
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
                // Large Rounded Image
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                    border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                  ),
                  child: ClipOval(
                    child: widget.imagePath != null && widget.imagePath!.isNotEmpty
                        ? FutureBuilder<bool>(
                            future: File(widget.imagePath!).exists(),
                            builder: (context, snapshot) {
                              if (snapshot.data == true) {
                                return Image.file(
                                  File(widget.imagePath!),
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
                    widget.medicineName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.dosage,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: widget.qty == 0
                        ? Colors.red.withOpacity(0.2)
                        : widget.qty <= 3
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: widget.qty == 0
                          ? Colors.red.withOpacity(0.5)
                          : widget.qty <= 3
                              ? Colors.orange.withOpacity(0.5)
                              : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    widget.qty == 0
                        ? "Out of stock!"
                        : widget.qty <= 3
                            ? "Only ${widget.qty} left!"
                            : "Stock: ${widget.qty} remaining",
                    style: TextStyle(
                      color: widget.qty == 0
                          ? Colors.red[300]
                          : widget.qty <= 3
                              ? Colors.orange[300]
                              : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Spacer(),
                // Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: _buildAlarmButton(
                          label: "I Took It",
                          icon: LucideIcons.checkCircle,
                          color: Colors.green[600]!,
                          onTap: _onTakeItWithFeedback,
                          isLoading: _isProcessing,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildAlarmButton(
                              label: "Snooze",
                              icon: LucideIcons.clock,
                              color: Colors.amber[700]!,
                              onTap: _onTakeLaterWithFeedback,
                              isLoading: _isProcessing,
                              isSmall: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildAlarmButton(
                              label: "Skip",
                              icon: LucideIcons.xCircle,
                              color: Colors.red[400]!.withOpacity(0.8),
                              onTap: _onSkipWithFeedback,
                              isLoading: _isProcessing,
                              isSmall: true,
                            ),
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
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isLoading = false,
    bool isSmall = false,
  }) {
    return ElevatedButton.icon(
      onPressed: isLoading ? null : onTap,
      icon: isLoading 
          ? const SizedBox.shrink() 
          : Icon(icon, size: isSmall ? 20 : 28),
      label: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            )
          : Text(
              label,
              style: TextStyle(
                fontSize: isSmall ? 16 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: color.withOpacity(0.6),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: isSmall ? 16 : 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isSmall ? 16 : 24),
        ),
        elevation: 8,
        shadowColor: color.withOpacity(0.5),
      ),
    );
  }
}
