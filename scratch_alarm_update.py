import os

file_path = r"c:\Projects\famcare_app\lib\screens\alarm_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

content = "".join(lines)

# 1. Update _onTakeLaterWithFeedback to accept minutes
old_snooze = """  Future<void> _onTakeLaterWithFeedback() async {
    if (_isProcessing || _context == null) return;
    setState(() => _isProcessing = true);
    
    try {
      if (_context!.isSingle) {
        await AlarmActionEngine.instance.snoozeSingleDose(_context!, 30);
      } else {
        await AlarmActionEngine.instance.snoozeGroupDoses(_context!, _context!.medicationIds, 30);
      }

      if (mounted) {
        AppSnackBar.showSuccess(context, "Reminder set for 30 min later");
        _dismissScreen();
      }
    } catch (e) {
      debugPrint("Error in _onTakeLater: $e");
      if (mounted) {
        AppSnackBar.showError(context, "Failed to snooze: $e");
        setState(() => _isProcessing = false);
      }
    }
  }"""

new_snooze = """  Future<void> _onTakeLaterWithFeedback(int minutes) async {
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
  }"""

content = content.replace(old_snooze, new_snooze)

# 2. Update _onTakeItWithFeedback to accept actualDose
old_take = """  Future<void> _onTakeItWithFeedback() async {
    if (_isProcessing || _context == null) return;
    setState(() => _isProcessing = true);
    
    try {
      if (_context!.isSingle) {
        await AlarmActionEngine.instance.takeSingleDose(_context!);
      } else {
        await AlarmActionEngine.instance.takeGroupDoses(_context!, _context!.medicationIds);
      }"""

new_take = """  Future<void> _onTakeItWithFeedback({double? actualDose}) async {
    if (_isProcessing || _context == null) return;
    setState(() => _isProcessing = true);
    
    try {
      if (_context!.isSingle) {
        await AlarmActionEngine.instance.takeSingleDose(_context!, actualDose: actualDose);
      } else {
        await AlarmActionEngine.instance.takeGroupDoses(_context!, _context!.medicationIds);
      }"""

content = content.replace(old_take, new_take)

# 3. Update the UI buttons
old_ui = """                        Row(
                          children: [
                            Expanded(
                              child: _buildAlarmButton(
                                label: "Take Later",
                                color: Colors.amber[700]!,
                                onTap: _onTakeLaterWithFeedback,
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
                        TextButton(
                          onPressed: _isProcessing ? null : _onSkipWithFeedback,
                          child: const Text(
                            "Skip Dose",
                            style: TextStyle(color: Colors.white54, fontSize: 16),
                          ),
                        ),"""

new_ui = """                        Row(
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
                        ),"""

content = content.replace(old_ui, new_ui)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
