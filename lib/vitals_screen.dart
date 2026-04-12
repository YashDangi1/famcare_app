import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

class VitalsScreen extends StatefulWidget {
  const VitalsScreen({super.key});

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _vitalsLog = [];
  Map<String, dynamic>? _latestVitals;

  final _bpController = TextEditingController();
  final _hrController = TextEditingController();
  final _tempController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchVitals();
  }

  @override
  void dispose() {
    _bpController.dispose();
    _hrController.dispose();
    _tempController.dispose();
    super.dispose();
  }

  // Database se vitals fetch karna (Table name fixed to 'vitals_logs')
  Future<void> _fetchVitals() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('vitals_logs') // ✅ Fixed table name
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _vitalsLog = data;
          _latestVitals = _vitalsLog.isNotEmpty ? _vitalsLog.first : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching vitals: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: Table not found or access denied')),
        );
      }
    }
  }

  // Naya vital log add karna
  Future<void> _addVitals() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final bp = _bpController.text.trim();
    final hr = int.tryParse(_hrController.text.trim());
    final temp = double.tryParse(_tempController.text.trim());

    if (bp.isEmpty || hr == null || temp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid health data')),
      );
      return;
    }

    try {
      await _supabase.from('vitals_logs').insert({ // ✅ Fixed table name
        'user_id': userId,
        'blood_pressure': bp,
        'heart_rate': hr,
        'temperature': temp,
      });

      if (mounted) {
        Navigator.pop(context);
        _bpController.clear();
        _hrController.clear();
        _tempController.clear();
        _fetchVitals();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vitals updated successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddVitalsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Log Health Vitals', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField(_bpController, 'Blood Pressure', LucideIcons.heart, '120/80'),
            const SizedBox(height: 15),
            _buildDialogField(_hrController, 'Heart Rate (bpm)', LucideIcons.activity, '72'),
            const SizedBox(height: 15),
            _buildDialogField(_tempController, 'Temp (°F)', LucideIcons.thermometer, '98.6'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: _addVitals,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(TextEditingController controller, String label, IconData icon, String hint) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF0EA5E9)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      keyboardType: label.contains('Pressure') ? TextInputType.text : TextInputType.number,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Vitals Tracker', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchVitals,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_latestVitals != null) ...[
                    _buildQuickStats(),
                    const SizedBox(height: 30),
                  ],
                  Row(
                    children: [
                      const Icon(LucideIcons.history, size: 20, color: Colors.grey),
                      const SizedBox(width: 10),
                      Text('Recent Logs', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  if (_vitalsLog.isEmpty)
                    const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No history found.')))
                  else
                    ..._vitalsLog.map((vital) => _buildVitalCard(vital)).toList(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddVitalsDialog,
        backgroundColor: const Color(0xFF0EA5E9),
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        _buildStatBox('BP', _latestVitals?['blood_pressure'] ?? '--', LucideIcons.heart, Colors.red),
        _buildStatBox('Pulse', '${_latestVitals?['heart_rate'] ?? '--'}', LucideIcons.activity, Colors.green),
        _buildStatBox('Temp', '${_latestVitals?['temperature'] ?? '--'}', LucideIcons.thermometer, Colors.orange),
      ],
    );
  }

  Widget _buildStatBox(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalCard(Map<String, dynamic> vital) {
    final date = DateTime.parse(vital['created_at']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: const Icon(LucideIcons.clipboardCheck, color: Color(0xFF0EA5E9)),
        title: Text('${vital['blood_pressure']} BP • ${vital['heart_rate']} BPM', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('Temp: ${vital['temperature']}°F • ${date.day}/${date.month}'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ),
    );
  }
}