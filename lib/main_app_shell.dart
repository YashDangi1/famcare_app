import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:google_fonts/google_fonts.dart';

// Screens ke imports
import 'login_screen.dart';
import 'family_hub_screen.dart';
import 'vitals_screen.dart';
import 'meds_screen.dart';
import 'prescription_screen.dart';
import 'activity_feed_screen.dart';

// ==========================================
// 1. MAIN SHELL (Navigation Controller)
// ==========================================
class MainAppShell extends StatefulWidget {
  const MainAppShell({super.key});

  @override
  State<MainAppShell> createState() => _MainAppShellState();
}

class _MainAppShellState extends State<MainAppShell> {
  int _currentIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeScreen(onTabChange: (index) => setState(() => _currentIndex = index)), // Tab 0
      const MedsScreen(),           // Tab 1
      const VitalsScreen(),         // Tab 2
      const PrescriptionScreen(),   // Tab 3
      const FamilyHubScreen(),      // Tab 4
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF0EA5E9),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(LucideIcons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.pill), label: 'Meds'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.activity), label: 'Vitals'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.folderLock), label: 'Vault'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.users), label: 'Family'),
        ],
      ),
    );
  }
}

// ==========================================
// 2. HOME SCREEN (With 30-Min Logic)
// ==========================================
class HomeScreen extends StatefulWidget {
  final Function(int) onTabChange;
  const HomeScreen({super.key, required this.onTabChange});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  String? _fullName;
  bool _isLoading = true;
  List<dynamic> _upcomingMeds = [];

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  Future<void> _initDashboard() async {
    await _fetchUserProfile();
    await _fetchUpcomingMeds();
  }

  // --- 30-MIN LOGIC HELPER ---
  bool _isDueSoon(String medTime) {
    try {
      final now = DateTime.now();
      final parts = medTime.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1].split(' ')[0]);
      
      if (medTime.contains('PM') && hour != 12) hour += 12;
      if (medTime.contains('AM') && hour == 12) hour = 0;

      final schedule = DateTime(now.year, now.month, now.day, hour, minute);
      final diff = schedule.difference(now).inMinutes;
      
      // Window: 30 min pehle se lekar 30 min baad tak
      return diff.abs() <= 30;
    } catch (e) {
      return false;
    }
  }

  Future<void> _fetchUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user != null) {
        final data = await _supabase.from('profiles').select('full_name').eq('id', user.id).maybeSingle();
        if (data != null && mounted) setState(() => _fullName = data['full_name']);
      }
    } catch (e) { debugPrint('Profile Error: $e'); }
  }

  Future<void> _fetchUpcomingMeds() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      // Dawa wahi jo 'is_taken' false ho
      final data = await _supabase.from('medications')
          .select('*')
          .eq('user_id', userId!)
          .eq('is_taken', false);

      // 30 min window filter lagao
      final filtered = data.where((m) => _isDueSoon(m['time'])).toList();

      if (mounted) {
        setState(() {
          _upcomingMeds = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Meds Filter Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _supabase.auth.currentUser;
    final displayName = _fullName ?? user?.email?.split('@')[0] ?? "User";

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('FamCare', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: const Color(0xFF0EA5E9))),
        backgroundColor: Colors.white, elevation: 0,
        actions: [
          IconButton(icon: const Icon(LucideIcons.logOut, color: Colors.redAccent), 
          onPressed: () async {
            await _supabase.auth.signOut();
            if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const LoginScreen()));
          }),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _initDashboard,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeSection(displayName),
                    const SizedBox(height: 25),
                    
                    // --- DYNAMIC NEXT MEDICINE SECTION ---
                    if (_upcomingMeds.isNotEmpty) ...[
                      const Text('DUE SOON', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.2)),
                      const SizedBox(height: 10),
                      _buildSummaryCard(
                        context, 'Medicine Reminder', 
                        'Time to take: ${_upcomingMeds[0]['name']} at ${_upcomingMeds[0]['time']}', 
                        LucideIcons.pill, Colors.orange,
                        () => widget.onTabChange(1), 
                      ),
                    ] else ...[
                      _buildSummaryCard(
                        context, 'No Immediate Meds', 'Check your full schedule here', 
                        LucideIcons.pill, Colors.grey,
                        () => widget.onTabChange(1), 
                      ),
                    ],
                    
                    const SizedBox(height: 15),

                    // Vitals Card
                    _buildSummaryCard(
                      context, 'Health Tracker', 'Log or view your latest vitals', 
                      LucideIcons.heartPulse, const Color(0xFF0EA5E9),
                      () => widget.onTabChange(2), 
                    ),
                    const SizedBox(height: 15),

                    // Family History (Activity Feed)
                    _buildSummaryCard(
                      context, 'Family Activity', 'See what others are doing', 
                      LucideIcons.history, Colors.green,
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ActivityFeedScreen())),
                    ),
                    const SizedBox(height: 15),

                    // Vault Card
                    _buildSummaryCard(
                      context, 'Medical Vault', 'Stored prescriptions & reports', 
                      LucideIcons.fileText, Colors.purple,
                      () => widget.onTabChange(3),
                    ),

                    const SizedBox(height: 30),
                    const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildActionButton(context, 'Add Meds', LucideIcons.plusCircle, Colors.orange, () => widget.onTabChange(1)),
                        _buildActionButton(context, 'Family Hub', LucideIcons.users, Colors.green, () => widget.onTabChange(4)),
                        _buildActionButton(context, 'Emergency', LucideIcons.phoneCall, Colors.red, () {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calling Emergency Services...')));
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeSection(String userName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Good Morning,', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        Text(userName.toUpperCase(), style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey[100]!),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
                  Text(sub, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}