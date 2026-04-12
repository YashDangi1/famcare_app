import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/alarm_service.dart';

class MedsScreen extends StatefulWidget {
  const MedsScreen({super.key});

  @override
  State<MedsScreen> createState() => _MedsScreenState();
}

class _MedsScreenState extends State<MedsScreen> {
  final _supabase = Supabase.instance.client;
  final _alarmService = AlarmService();
  List<dynamic> _medications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _alarmService.init();
    _fetchMedications();
  }

  Future<void> _fetchMedications() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      final data = await _supabase
          .from('medications')
          .select('*')
          .eq('user_id', userId!)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _medications = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Fetch Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==========================================
  // ➕ MANUAL ADD POPUP (New Feature Here)
  // ==========================================
  void _showAddManualDialog() {
    TextEditingController nameController = TextEditingController();
    TextEditingController doseController = TextEditingController();
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Add Medicine", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Medicine Name", prefixIcon: Icon(Icons.medication)),
              ),
              TextField(
                controller: doseController,
                decoration: const InputDecoration(labelText: "Dosage (e.g., 1 pill)", prefixIcon: Icon(Icons.scale)),
              ),
              const SizedBox(height: 20),
              ListTile(
                title: Text(selectedTime == null ? "Set Alarm Time" : "Alarm: ${selectedTime!.format(context)}"),
                leading: const Icon(Icons.alarm, color: Color(0xFF0EA5E9)),
                onTap: () async {
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                  if (time != null) setDialogState(() => selectedTime = time);
                },
                tileColor: Colors.blue.withOpacity(0.05),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9), foregroundColor: Colors.white),
              onPressed: () async {
                if (nameController.text.isEmpty || selectedTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name and Time are required!")));
                  return;
                }

                // 1. Database mein save karo
                try {
                  await _supabase.from('medications').insert({
                    'user_id': _supabase.auth.currentUser!.id,
                    'name': nameController.text,
                    'dosage': doseController.text,
                    'time': selectedTime!.format(context),
                    'is_taken': false,
                  });

                  // 2. Local Alarm Set karo
                  final now = DateTime.now();
                  final alarmTime = DateTime(now.year, now.month, now.day, selectedTime!.hour, selectedTime!.minute);
                  await _alarmService.scheduleAlarm(
                    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                    title: "Time for ${nameController.text}",
                    body: "Dosage: ${doseController.text}",
                    time: alarmTime,
                  );

                  // 3. UI Update karo
                  _fetchMedications();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Medicine & Alarm added!")));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                }
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  // --- Toggle status ---
  Future<void> _toggleTaken(String id, bool currentStatus) async {
    try {
      await _supabase.from('medications').update({'is_taken': !currentStatus}).eq('id', id);
      _fetchMedications();
    } catch (e) {
      debugPrint('Toggle Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Medication Schedule', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _medications.isEmpty
              ? const Center(child: Text("No medicines added yet.", style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _medications.length,
                  itemBuilder: (context, index) {
                    final med = _medications[index];
                    final isTaken = med['is_taken'] ?? false;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: BorderSide(color: Colors.grey[100]!),
                      ),
                      color: isTaken ? Colors.green[50] : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF0EA5E9).withOpacity(0.1),
                            child: const Icon(LucideIcons.pill, color: Color(0xFF0EA5E9)),
                          ),
                          title: Text(med['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${med['dosage'] ?? ''} • ${med['time'] ?? ''}"),
                          trailing: IconButton(
                            icon: Icon(
                              isTaken ? LucideIcons.checkCircle2 : LucideIcons.circle,
                              color: isTaken ? Colors.green : Colors.grey[300],
                              size: 26,
                            ),
                            onPressed: () => _toggleTaken(med['id'].toString(), isTaken),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      // ✅ FLOATING ACTION BUTTON
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddManualDialog,
        backgroundColor: const Color(0xFF0EA5E9),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Med", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}