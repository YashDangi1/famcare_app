import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OfflineSyncService {
  static final OfflineSyncService instance = OfflineSyncService._internal();
  factory OfflineSyncService() => instance;
  OfflineSyncService._internal();

  static const String _queueKey = 'offline_action_queue';

  /// Helper to determine if an exception is due to network failure
  static bool isOfflineError(dynamic e) {
    final str = e.toString().toLowerCase();
    if (str.contains('socketexception') || 
        str.contains('failed host lookup') ||
        str.contains('connection refused')) {
      return true;
    }
    if (e is PostgrestException && e.message.toLowerCase().contains('failed to host lookup')) {
      return true;
    }
    return false;
  }

  /// Enqueue an action to be performed later when online
  Future<void> enqueueAction({
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> queue = prefs.getStringList(_queueKey) ?? [];
      
      final action = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': type,
        'payload': payload,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      queue.add(jsonEncode(action));
      await prefs.setStringList(_queueKey, queue);
      debugPrint('OfflineSyncService: Enqueued action ${action['type']}');
    } catch (e) {
      debugPrint('OfflineSyncService: Error enqueueing action: $e');
    }
  }

  /// Attempts to sync all queued actions to Supabase
  Future<void> attemptSync() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> queue = prefs.getStringList(_queueKey) ?? [];
    
    if (queue.isEmpty) return;
    
    debugPrint('OfflineSyncService: Attempting to sync ${queue.length} actions...');
    final supabase = Supabase.instance.client;
    
    List<String> remainingQueue = [];
    
    for (String itemStr in queue) {
      try {
        final action = jsonDecode(itemStr) as Map<String, dynamic>;
        final type = action['type'] as String;
        final payload = action['payload'] as Map<String, dynamic>;
        
        bool success = false;
        
        if (type == 'medicine_logs_insert') {
          // Check if it already exists to avoid duplicates (deduplication handled by Supabase unique constraint, but we catch it)
          try {
            await supabase.from('medicine_logs').insert(payload);
            success = true;
          } catch (e) {
            // If it's a unique constraint violation (23505), it's already synced
            if (e is PostgrestException && e.code == '23505') {
              success = true; // Mark as success to remove from queue
            } else if (e is PostgrestException && e.message.contains('Failed to host lookup')) {
              // Network error, keep in queue
              success = false;
            } else if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup')) {
               success = false;
            } else {
               // Other error, log and maybe drop to avoid blocking queue
               debugPrint('OfflineSyncService: Drop action due to error: $e');
               success = true;
            }
          }
        } else if (type == 'medications_update_qty') {
           try {
              final id = payload['id'];
              final qty = payload['qty'];
              final isActive = payload['is_active'];
              
              await supabase
                  .from('medications')
                  .update({'qty': qty, if (isActive != null) 'is_active': isActive})
                  .eq('id', id);
              success = true;
           } catch (e) {
             if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup') || (e is PostgrestException && e.message.contains('Failed to host lookup'))) {
               success = false;
             } else {
               debugPrint('OfflineSyncService: Drop action due to error: $e');
               success = true;
             }
           }
        }
        
        if (!success) {
          remainingQueue.add(itemStr);
        } else {
          debugPrint('OfflineSyncService: Successfully synced action $type');
        }
      } catch (e) {
        debugPrint('OfflineSyncService: Error processing queue item: $e');
        remainingQueue.add(itemStr); // Keep on error
      }
    }
    
    // Update queue with remaining items
    await prefs.setStringList(_queueKey, remainingQueue);
    if (remainingQueue.isNotEmpty) {
       debugPrint('OfflineSyncService: ${remainingQueue.length} actions remaining in queue.');
    }
  }
}
