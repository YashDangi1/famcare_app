import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/family/family_alert_service.dart';

final familyAlertServiceProvider = Provider((ref) {
  return FamilyAlertService(Supabase.instance.client);
});

final familyAlertsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, groupId) async {
  return ref.watch(familyAlertServiceProvider).listAlerts(groupId, status: 'open');
});
