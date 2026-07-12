import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class NotificationInboxScreen extends StatefulWidget {
  const NotificationInboxScreen({super.key});

  @override
  State<NotificationInboxScreen> createState() => _NotificationInboxScreenState();
}

class _NotificationInboxScreenState extends State<NotificationInboxScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      
      final data = await _supabase
          .from('notification_inbox')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load notifications: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await _supabase.from('notification_inbox').update({'is_read': true}).eq('id', id);
      setState(() {
        final idx = _notifications.indexWhere((n) => n['id'] == id);
        if (idx != -1) {
          _notifications[idx]['is_read'] = true;
        }
      });
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      await _supabase.from('notification_inbox').update({'is_read': true}).eq('user_id', userId).eq('is_read', false);
      setState(() {
        for (var n in _notifications) {
          n['is_read'] = true;
        }
      });
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'meds': return LucideIcons.pill;
      case 'family': return LucideIcons.users;
      case 'health': return LucideIcons.activity;
      default: return LucideIcons.bell;
    }
  }

  Color _getColorForSeverity(String severity) {
    switch (severity) {
      case 'critical': return Colors.red;
      case 'warning': return Colors.orange;
      case 'success': return Colors.green;
      default: return const Color(0xFF0EA5E9);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Inbox', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text('Mark all read'),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.blue.shade50,
            child: Text('Basic Inbox Only: Deep-link actions coming soon.', style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                    ? const Center(child: Text('No notifications yet', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notif = _notifications[index];
                          final isRead = notif['is_read'] == true;
                          final iconColor = _getColorForSeverity(notif['severity']);
                          
                          return GestureDetector(
                            onTap: () {
                              if (!isRead) _markAsRead(notif['id']);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isRead ? Colors.white : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isRead ? Colors.grey.shade200 : Colors.blue.shade200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: iconColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(_getIconForCategory(notif['category']), color: iconColor),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(child: Text(notif['title'], style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold, fontSize: 16))),
                                            Text(DateFormat('MMM d, h:mm a').format(DateTime.parse(notif['created_at'])), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(notif['body'], style: TextStyle(color: Colors.grey.shade700)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
