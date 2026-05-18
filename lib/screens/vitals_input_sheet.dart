import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/vitals_service.dart';
import '../utils/snackbar_utils.dart';

class VitalsInputSheet extends StatefulWidget {
  final VoidCallback onSave;
  const VitalsInputSheet({super.key, required this.onSave});

  @override
  State<VitalsInputSheet> createState() => _VitalsInputSheetState();
}

class _VitalsInputSheetState extends State<VitalsInputSheet> {
  final _vitalsService = VitalsService();
  final _formKey = GlobalKey<FormState>();

  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _spo2Controller = TextEditingController();
  final _weightController = TextEditingController();
  final _tempController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _systolicController.dispose();
    _diastolicController.dispose();
    _heartRateController.dispose();
    _spo2Controller.dispose();
    _weightController.dispose();
    _tempController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    // Basic validation: Check if at least one field has data
    if (_systolicController.text.isEmpty &&
        _diastolicController.text.isEmpty &&
        _heartRateController.text.isEmpty &&
        _spo2Controller.text.isEmpty &&
        _weightController.text.isEmpty &&
        _tempController.text.isEmpty) {
      AppSnackBar.showError(context, "Please enter at least one reading");
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Helper function to extract ONLY numbers and decimals
      String _clean(String val) {
        if (val.isEmpty) return '';
        return val.replaceAll(RegExp(r'[^0-9\.]'), '');
      }

      final systolic = int.tryParse(_clean(_systolicController.text));
      final diastolic = int.tryParse(_clean(_diastolicController.text));
      final heartRate = int.tryParse(_clean(_heartRateController.text));
      final spo2 = int.tryParse(_clean(_spo2Controller.text));
      final weight = double.tryParse(_clean(_weightController.text));
      final temp = double.tryParse(_clean(_tempController.text));

      // BP range validation
      if (systolic != null && (systolic < 60 || systolic > 250)) {
        AppSnackBar.showError(context, "Systolic BP must be between 60-250 mmHg");
        return;
      }
      if (diastolic != null && (diastolic < 40 || diastolic > 150)) {
        AppSnackBar.showError(context, "Diastolic BP must be between 40-150 mmHg");
        return;
      }

      debugPrint("Saving Vitals: BP $systolic/$diastolic, HR $heartRate, SpO2 $spo2, Wt $weight, Temp $temp");

      await _vitalsService.saveVitals(
        bpSystolic: systolic,
        bpDiastolic: diastolic,
        heartRate: heartRate,
        spo2: spo2,
        weight: weight,
        temperature: temp,
      );

      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.showSuccess(context, "Vitals saved successfully!");
        widget.onSave();
      }
    } catch (e) {
      debugPrint("SAVE ERROR: $e");
      if (mounted) {
        AppSnackBar.showError(context, "Error saving: ${e.toString()}");
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Log New Vitals",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _systolicController,
                      label: "BP Systolic",
                      hint: "120",
                      icon: LucideIcons.activity,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildTextField(
                      controller: _diastolicController,
                      label: "BP Diastolic",
                      hint: "80",
                      icon: LucideIcons.activity,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _heartRateController,
                      label: "Heart Rate",
                      hint: "72",
                      icon: LucideIcons.heart,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildTextField(
                      controller: _spo2Controller,
                      label: "SpO2 (%)",
                      hint: "98",
                      icon: LucideIcons.droplets,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _weightController,
                      label: "Weight (kg)",
                      hint: "70.5",
                      icon: LucideIcons.scale,
                      isDecimal: true,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: _buildTextField(
                      controller: _tempController,
                      label: "Temperature (°C)",
                      hint: "36.6",
                      icon: LucideIcons.thermometer,
                      isDecimal: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("Save Vitals", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isDecimal = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: const Color(0xFF0EA5E9)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[200]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}
