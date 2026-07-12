import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/family/family_alert.dart';

class FamilyAlertService {
  final SupabaseClient _supabase;

  FamilyAlertService(this._supabase);

  Future<List<Map<String, dynamic>>> listAlerts(String groupId, {String status = 'open'}) async {
    final response = await _supabase
        .from('family_alerts')
        .select('*, recipient:profiles!family_alerts_recipient_user_id_fkey(full_name)')
        .eq('group_id', groupId)
        .eq('status', status)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> acknowledgeAlert(String alertId) async {
    await _supabase.rpc('rpc_acknowledge_family_alert', params: {
      'p_alert_id': alertId,
    });
  }

  Future<void> resolveAlert(String alertId) async {
    try {
      await _supabase.rpc('rpc_resolve_family_alert', params: {
        'p_alert_id': alertId,
      });
    } catch (e) {
      throw Exception('Failed to resolve alert: $e');
    }
  }
}
