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
  int _streakCount = 0;
  List<dynamic> _adherenceLogs = [];

  @override
  void initState() {
    super.initState();
    _fetchAdherenceData();
  }

  // ==========================================
  // 🚀 FETCH ADHERENCE LOGS (Streak Logic)
  // ==========================================
  Future<void> _fetchAdherenceData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 'family_history' table se sirf 'MEDS' waale logs uthao
      final data = await _supabase
          .from('family_history')
          .select('*')
          .eq('user_id', user.id)
          .eq('action_type', 'MEDS')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _adherenceLogs = data;
          // Streak Logic: Unique days calculate karo
          _streakCount = _calculateStreak(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Adherence Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _calculateStreak(List<dynamic> logs) {
    if (logs.isEmpty) return 0;
    // Unique days set banata hai (YYYY-MM-DD format mein)
    Set<String> uniqueDays = logs.map((log) {
      return log['created_at'].toString().substring(0, 10);
    }).toSet();
    return uniqueDays.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Health & Adherence', 
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchAdherenceData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 1. STREAK CARD ---
                    _buildStreakCard(),
                    
                    // --- 2. CONSISTENCY SCORE (PROGRESS BAR) ---
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.1)),
                      ),
                      child: Column(
                        children: [
                          const Text("Consistency Score", 
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: (_streakCount / 7).clamp(0.0, 1.0), // 7 din ka target
                              backgroundColor: Colors.grey[200],
                              color: Colors.green,
                              minHeight: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("$_streakCount Days Done", 
                                style: TextStyle(fontSize: 12, color: Colors.blue[800], fontWeight: FontWeight.w600)),
                              Text("Target: 7 Days Challenge", 
                                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),
                    Text('Medication History', 
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),

                    // --- 3. LOGS LIST ---
                    _adherenceLogs.isEmpty 
                      ? _buildEmptyState()
                      : _buildLogsList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStreakCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF38BDF8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0EA5E9).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.flame, color: Colors.orangeAccent, size: 50),
          const SizedBox(height: 10),
          Text('$_streakCount Day Streak!', 
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const Text('You are consistently taking your meds!', 
            style: TextStyle(color: Colors.white70, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildLogsList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _adherenceLogs.length,
      itemBuilder: (context, index) {
        final log = _adherenceLogs[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[100]!),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.checkCircle, color: Colors.green, size: 20),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(log['description'] ?? 'Medicine Taken', 
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(log['created_at'].toString().substring(0, 16).replaceFirst('T', ' '), 
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Icon(LucideIcons.clipboardList, size: 50, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text("No records yet. Start taking meds to build a streak!", 
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }
}