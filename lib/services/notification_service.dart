import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();

  /// Sends WhatsApp messages to family admins when a dose is missed.
  Future<void> sendMissedMedicineAlert({
    required String patientName,
    required String medicineName,
    required DateTime scheduledTime,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Get patient's group_id
      final membership = await supabase
          .from('family_members')
          .select('group_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (membership == null) return;
      final groupId = membership['group_id'];

      // 2. Fetch admins in the group with phone numbers
      final admins = await supabase
          .from('family_members')
          .select('user_id')
          .eq('group_id', groupId)
          .eq('role', 'admin')
          .neq('user_id', userId);

      if (admins.isEmpty) return;

      // 3. Find first admin with a phone number (send only one message)
      String? targetPhone;
      String targetName = 'Admin';

      for (var admin in admins) {
        final adminUserId = admin['user_id'];
        final profile = await supabase
            .from('profiles')
            .select('full_name, phone_number')
            .eq('id', adminUserId)
            .maybeSingle();

        final phone = profile?['phone_number'] as String?;
        if (phone != null && phone.isNotEmpty) {
          targetPhone = phone;
          targetName = profile?['full_name'] ?? 'Admin';
          break;
        }
      }

      if (targetPhone == null) {
        debugPrint('NotificationService: No admin with phone number found');
        return;
      }

      // 4. Build WhatsApp message and launch
      final timeStr =
          '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}';
      final message = 'Hi $targetName, $patientName missed their dose of '
          '$medicineName at $timeStr. Please check on them.';

      // Clean phone: remove spaces, +, dashes, parens; fix leading 0 (assume India +91)
      var cleanPhone = targetPhone.replaceAll(RegExp(r'[\s+\-()]'), '');
      if (cleanPhone.startsWith('0')) {
        cleanPhone = '91${cleanPhone.substring(1)}';
      }

      final uri = Uri.parse(
        'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('NotificationService: WhatsApp launched for $targetName ($cleanPhone)');
      } else {
        debugPrint('NotificationService: Could not launch WhatsApp for $targetName');
      }
    } catch (e) {
      debugPrint('NotificationService Error: $e');
    }
  }
}
