import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:isar/isar.dart';
import '../models/medicine_model.dart';
import '../models/medicine_entity.dart';

class OfflineSyncService {
  static final OfflineSyncService instance = OfflineSyncService._internal();
  factory OfflineSyncService() => instance;
  OfflineSyncService._internal();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  void initialize() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.contains(ConnectivityResult.wifi) || results.contains(ConnectivityResult.mobile)) {
        debugPrint('OfflineSyncService: Network restored, attempting sync...');
        attemptSync();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

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
        'status': 'queued',
      };
      
      queue.add(jsonEncode(action));
      await prefs.setStringList(_queueKey, queue);
      debugPrint('OfflineSyncService Telemetry: Action [${action['id']}] of type ${action['type']} is QUEUED');
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
    
    for (int qIndex = 0; qIndex < queue.length; qIndex++) {
      String itemStr = queue[qIndex];
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
        } else if (type == 'medications_decrement_qty' || type == 'medications_update_qty') {
           try {
              final medId = payload['id'];
              
              await supabase.rpc('decrement_medicine_qty_v3', params: {
                'p_med_id': medId,
                if (payload['decrement_by'] != null) 'p_amount': payload['decrement_by'],
              });
              success = true;
           } catch (e) {
             if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup') || (e is PostgrestException && e.message.contains('Failed to host lookup'))) {
               success = false;
             } else {
               debugPrint('OfflineSyncService: Drop action due to error: $e');
               success = true;
             }
           }
        } else if (type == 'medications_increment_qty') {
           try {
              final id = payload['id'];
              final userId = payload['user_id'];
              final amount = payload['amount'];
              
              await supabase.rpc('increment_medicine_qty_v1', params: {
                'p_med_id': id,
                'p_user_id': userId,
                'p_amount': amount,
              });
              success = true;
           } catch (e) {
             if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup') || (e is PostgrestException && e.message.contains('Failed to host lookup'))) {
               success = false;
             } else {
               debugPrint('OfflineSyncService: Drop action due to error: $e');
               success = true;
             }
           }
        } else if (type == 'medications_insert') {
           try {
             final data = Map<String, dynamic>.from(payload);
             final localId = data['id'] as String?;
             if (localId != null && localId.startsWith('local_')) {
               data.remove('id'); // let Supabase generate UUID
             }
             final response = await supabase.from('medications').insert(data).select().maybeSingle();
             if (response != null && localId != null && localId.startsWith('local_')) {
               // Reconcile ID locally
               final isar = Isar.getInstance();
               if (isar != null) {
                 final realMed = Medicine.fromJson(response);
                 final realId = realMed.id;
                 if (realId != null) {
                   await isar.writeTxn(() async {
                     await isar.medicineEntitys.filter().supabaseIdEqualTo(localId).deleteAll();
                     await isar.medicineEntitys.put(realMed.toEntity());
                   });
                   // IMPORTANT: Remap this localId to realId in the rest of the queue
                   for (int j = qIndex + 1; j < queue.length; j++) {
                     final qItem = jsonDecode(queue[j]) as Map<String, dynamic>;
                     if (qItem['status'] == 'queued' || qItem['status'] == 'failed_requeued') {
                       final qPayload = qItem['payload'] as Map<String, dynamic>?;
                       if (qPayload != null) {
                         bool modified = false;
                         if (qPayload['medication_id'] == localId) {
                           qPayload['medication_id'] = realId;
                           modified = true;
                         }
                         if (qPayload['id'] == localId) {
                           qPayload['id'] = realId;
                           modified = true;
                         }
                         if (modified) {
                           qItem['payload'] = qPayload;
                           queue[j] = jsonEncode(qItem);
                         }
                       }
                     }
                   }
                   
                   // Also update remainingQueue if any items were already processed and failed
                   for (int i = 0; i < remainingQueue.length; i++) {
                     final rItem = jsonDecode(remainingQueue[i]) as Map<String, dynamic>;
                     final rPayload = rItem['payload'] as Map<String, dynamic>?;
                     if (rPayload != null) {
                       bool modified = false;
                       if (rPayload['medication_id'] == localId) {
                         rPayload['medication_id'] = realId;
                         modified = true;
                       }
                       if (rPayload['id'] == localId) {
                         rPayload['id'] = realId;
                         modified = true;
                       }
                       if (modified) {
                         rItem['payload'] = rPayload;
                         remainingQueue[i] = jsonEncode(rItem);
                       }
                     }
                   }
                 }
               }
             }
             success = true;
           } catch (e) {
             if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup') || (e is PostgrestException && e.message.contains('Failed to host lookup'))) {
               success = false;
             } else {
               debugPrint('OfflineSyncService: Drop action due to error: $e');
               success = true;
             }
           }
        } else if (type == 'medications_update') {
           try {
             final data = Map<String, dynamic>.from(payload);
             final id = data['id'];
             if (id != null && !id.toString().startsWith('local_')) {
               await supabase.from('medications').update(data).eq('id', id);
             }
             success = true;
           } catch (e) {
             if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup') || (e is PostgrestException && e.message.contains('Failed to host lookup'))) {
               success = false;
             } else {
               debugPrint('OfflineSyncService: Drop action due to error: $e');
               success = true;
             }
           }
        } else if (type == 'vitals_insert') {
           try {
             await supabase.from('vitals').insert(payload);
             success = true;
           } catch (e) {
             if (e.toString().contains('SocketException') || e.toString().contains('Failed host lookup') || (e is PostgrestException && e.message.contains('Failed to host lookup'))) {
               success = false;
             } else {
               debugPrint('OfflineSyncService: Drop action due to error: $e');
               success = true;
             }
           }
        } else if (type == 'medications_delete') {
           try {
             final id = payload['id'];
             if (id != null) {
               await supabase.from('medications').delete().eq('id', id);
             }
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
          debugPrint('OfflineSyncService Telemetry: Action [${action['id']}] of type $type FAILED (re-queued)');
          action['status'] = 'failed_requeued';
          remainingQueue.add(jsonEncode(action));
        } else {
          debugPrint('OfflineSyncService Telemetry: Action [${action['id']}] of type $type is SYNCED');
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
