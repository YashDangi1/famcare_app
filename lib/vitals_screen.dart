import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:intl/intl.dart';

class VitalsScreen extends StatefulWidget {
  const VitalsScreen({super.key});

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _vitalsLog = [];

  final _valueController = TextEditingController();
  String _selectedType = "Heart Rate";

  @override
  void initState() {
    super.initState();
    _fetchVitals();
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  String _getUnit(String type) {
    switch (type) {
      case "Blood Pressure":
        return "mmHg";
      case "Blood Sugar":
        return "mg/dL";
      case "Heart Rate":
        return "bpm";
      case "Weight":
        return "kg";
      default:
        return "";
    }
  }

  IconData _getIcon(String type) {
    switch (type) {
      case "Heart Rate":
        return LucideIcons.heart;
      case "Blood Sugar":
        return LucideIcons.droplets;
      case "Blood Pressure":
        return LucideIcons.activity;
      case "Weight":
        return LucideIcons.scale;
      default:
        return LucideIcons.activity;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case "Heart Rate":
        return Colors.red;
      case "Blood Sugar":
        return Colors.blue;
      case "Blood Pressure":
        return Colors.orange;
      case "Weight":
        return Colors.green;
      default:
        return const Color(0xFF0EA5E9);
    }
  }

  Future<void> _fetchVitals() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('vitals')
          .select()
          .eq('user_id', userId)
          .order('measured_at', ascending: false);

      if (mounted) {
        setState(() {
          _vitalsLog = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching vitals: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching vitals: $e')),
        );
      }
    }
  }

  Future<void> _saveVital() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    final value = _valueController.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a value')),
      );
      return;
    }

    try {
      await _supabase.from('vitals').insert({
        'user_id': userId,
        'vital_type': _selectedType,
        'value': value,
        'unit': _getUnit(_selectedType),
        'measured_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context);
        _valueController.clear();
        _fetchVitals();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vital logged successfully!'), backgroundColor: Colors.green),
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

  void _showAddVitalDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Log New Vital', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  labelText: 'Vital Type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: Icon(_getIcon(_selectedType), color: _getColor(_selectedType)),
                ),
                items: ["Blood Pressure", "Blood Sugar", "Heart Rate", "Weight"]
                    .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setModalState(() => _selectedType = val);
                },
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _valueController,
                keyboardType: _selectedType == "Blood Pressure" ? TextInputType.text : TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Value',
                  hintText: _selectedType == "Blood Pressure" ? 'e.g. 120/80' : 'Enter value',
                  suffixText: _getUnit(_selectedType),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(LucideIcons.activity),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveVital,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EA5E9),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Vital', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Vitals Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchVitals,
              child: _vitalsLog.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.activity, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('No vitals logged yet', 
                            style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Text('Track your health by adding your first vital', 
                            style: TextStyle(fontSize: 14, color: Colors.grey[400])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _vitalsLog.length,
                      itemBuilder: (context, index) {
                        final vital = _vitalsLog[index];
                        final type = vital['vital_type'] ?? '';
                        final value = vital['value'] ?? '';
                        final unit = vital['unit'] ?? '';
                        final measuredAt = DateTime.parse(vital['measured_at']);
                        
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey[200]!),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _getColor(type).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(_getIcon(type), color: _getColor(type), size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(type, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 4),
                                      Text('$value $unit', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                Text(
                                  DateFormat('MMM d, h:mm a').format(measuredAt),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddVitalDialog,
        backgroundColor: const Color(0xFF0EA5E9),
        child: const Icon(LucideIcons.plus, color: Colors.white),
      ),
    );
  }
}