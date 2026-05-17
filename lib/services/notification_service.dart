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

      // 3. Get phone numbers for each admin from profiles
      for (var admin in admins) {
        final adminUserId = admin['user_id'];
        final profile = await supabase
            .from('profiles')
            .select('full_name, phone_number')
            .eq('id', adminUserId)
            .maybeSingle();

        final phone = profile?['phone_number'] as String?;
        final adminName = profile?['full_name'] ?? 'Admin';

        if (phone == null || phone.isEmpty) {
          debugPrint('NotificationService: No phone number for $adminName, skipping WhatsApp');
          continue;
        }

        // 4. Build WhatsApp message and launch
        final timeStr =
            '${scheduledTime.hour.toString().padLeft(2, '0')}:${scheduledTime.minute.toString().padLeft(2, '0')}';
        final message = 'Hi $adminName, $patientName missed their dose of '
            '$medicineName at $timeStr. Please check on them.';

        // Clean phone number: remove spaces, +, leading zeros
        final cleanPhone = phone.replaceAll(RegExp(r'[\s+\-()]'), '');

        final uri = Uri.parse(
          'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
        );

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          debugPrint('NotificationService: WhatsApp launched for $adminName ($cleanPhone)');
        } else {
          debugPrint('NotificationService: Could not launch WhatsApp for $adminName');
        }
      }
    } catch (e) {
      debugPrint('NotificationService Error: $e');
    }
  }
}
