import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({super.key});

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _activities = [];

  @override
  void initState() {
    super.initState();
    _fetchActivities();
  }

  Future<void> _fetchActivities() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) return;

      // Get Group ID first
      final memberRes = await Supabase.instance.client
          .from('family_members')
          .select('group_id')
          .eq('user_id', currentUser.id)
          .maybeSingle();

      if (memberRes == null) return;
      final groupId = memberRes['group_id'];

      // Fetch Feed
      final response = await Supabase.instance.client
          .from('activity_feed')
          .select()
          .eq('group_id', groupId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _activities = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error fetching activity feed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _groupedItems() {
    final items = <dynamic>[];
    String? previousLabel;

    for (final activity in _activities) {
      final createdAtRaw = activity['created_at'];
      if (createdAtRaw == null) continue;

      final createdAt = DateTime.tryParse(createdAtRaw.toString());
      if (createdAt == null) continue;

      final label = _dateLabel(createdAt);
      if (label != previousLabel) {
        items.add(label);
        previousLabel = label;
      }
      items.add(activity);
    }

    return items;
  }

  String _dateLabel(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final target = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (target == today) return 'Today';
    if (target == yesterday) return 'Yesterday';
    return DateFormat('dd MMM yyyy').format(dateTime);
  }

  Color _colorForAction(String? actionType) {
    switch (actionType) {
      case 'MEDICINE_TAKEN':
        return Colors.green;
      case 'MEDICINE_MISSED':
        return Colors.red;
      case 'ROLE_CHANGED':
        return Colors.purple;
      case 'MEMBER_REMOVED':
        return Colors.orange;
      default:
        return const Color(0xFF0EA5E9);
    }
  }

  IconData _iconForAction(String? actionType) {
    switch (actionType) {
      case 'MEDICINE_TAKEN':
        return Icons.check_circle;
      case 'MEDICINE_MISSED':
        return Icons.cancel;
      case 'ROLE_CHANGED':
        return Icons.admin_panel_settings;
      case 'MEMBER_REMOVED':
        return Icons.person_remove;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _groupedItems();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Activity Feed',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchActivities,
              child: _activities.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.72,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.timeline,
                                  size: 72,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No activity yet',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Family updates will appear here automatically.',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        if (item is String) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 10),
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                              ),
                            ),
                          );
                        }

                        final activity = item as Map<String, dynamic>;
                        final actionType = activity['action_type']?.toString();
                        final color = _colorForAction(actionType);
                        final actorName =
                            activity['actor_name']?.toString().trim().isNotEmpty == true
                                ? activity['actor_name'].toString().trim()
                                : 'Family Member';
                        final description =
                            activity['description']?.toString() ?? 'Activity updated';
                        final createdAt =
                            DateTime.tryParse(activity['created_at']?.toString() ?? '');
                        final formattedTime = createdAt != null
                            ? DateFormat('hh:mm a').format(createdAt)
                            : '--:--';
                        final initial = actorName.isNotEmpty
                            ? actorName.substring(0, 1).toUpperCase()
                            : 'F';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: color.withOpacity(0.15),
                                    child: Text(
                                      initial,
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 2,
                                    height: 54,
                                    margin: const EdgeInsets.only(top: 8),
                                    color: Colors.grey[200],
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: Colors.grey[200]!),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: color.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          _iconForAction(actionType),
                                          color: color,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              description,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '$actorName • $formattedTime',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
