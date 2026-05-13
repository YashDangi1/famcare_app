import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<dynamic> _activities = [];

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Pehle family ka ID nikalo
      final membership = await _supabase
          .from('family_members')
          .select('group_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (membership != null) {
        final groupId = membership['group_id'];
        
        // Ab us family ki history fetch karo
        final data = await _supabase
            .from('family_history')
            .select('*, profiles(full_name)')
            .eq('group_id', groupId)
            .order('created_at', ascending: false);

        if (mounted) setState(() => _activities = data);
      }
    } catch (e) {
      debugPrint('Error fetching history: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Action type ke hisaab se icon 
  IconData _getIconForAction(String? action) {
    switch (action) {
      case 'JOIN': return LucideIcons.userPlus;
      case 'MED': return LucideIcons.pill;
      case 'VITAL': return LucideIcons.activity;
      case 'ALARM': return LucideIcons.bellRing;
      default: return LucideIcons.info;
    }
  }

  // Action type ke hisaab se color
  Color _getColorForAction(String? action) {
    switch (action) {
      case 'JOIN': return Colors.green;
      case 'MED': return Colors.orange;
      case 'VITAL': return Colors.redAccent;
      case 'ALARM': return const Color(0xFF0EA5E9);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Activity Feed', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activities.isEmpty
              ? const Center(child: Text('No activity yet. Start logging!'))
              : RefreshIndicator(
                  onRefresh: _fetchHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _activities.length,
                    itemBuilder: (context, index) {
                      final activity = _activities[index];
                      // Null checks taaki error na aaye
                      final userName = activity['profiles']?['full_name'] ?? 'Family Member';
                      final actionType = activity['action_type'];
                      final date = DateTime.parse(activity['created_at']);
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                          side: BorderSide(color: Colors.grey[200]!)
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getColorForAction(actionType).withOpacity(0.1),
                            child: Icon(_getIconForAction(actionType), color: _getColorForAction(actionType)),
                          ),
                          title: Text(activity['description'] ?? 'Action performed', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text('By $userName • ${date.day}/${date.month} at ${date.hour}:${date.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 12)),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}