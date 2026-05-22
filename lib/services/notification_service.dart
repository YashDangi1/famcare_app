import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

  /// 6B — Sends WhatsApp slot reminder to family admins at slot START.
  /// Informational message — separate from missed-dose alert.
  Future<void> sendSlotReminderAlert({
    required String patientName,
    required String medicineName,
    required String slotName,
    required DateTime slotStartTime,
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

      // 3. Find first admin with a phone number
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

      // 4. Build Hindi slot reminder message
      final timeStr =
          '${slotStartTime.hour.toString().padLeft(2, '0')}:${slotStartTime.minute.toString().padLeft(2, '0')}';
      final message = '$patientName ko $medicineName lene ka time ho gaya hai\n'
          '($slotName \u2022 $timeStr)';

      // Clean phone number
      var cleanPhone = targetPhone.replaceAll(RegExp(r'[\s+\-()]'), '');
      if (cleanPhone.startsWith('0')) {
        cleanPhone = '91${cleanPhone.substring(1)}';
      }

      final uri = Uri.parse(
        'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('NotificationService: Slot reminder WhatsApp sent to $targetName');
      } else {
        debugPrint('NotificationService: Could not launch WhatsApp for slot reminder');
      }
    } catch (e) {
      debugPrint('NotificationService Slot Reminder Error: $e');
    }
  }

  /// Shows a local notification (for low stock alerts, etc.)
  Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      const androidDetails = AndroidNotificationDetails(
        'famcare_general',
        'FamCare Alerts',
        channelDescription: 'Low stock and general alerts',
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(android: androidDetails);
      await plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        details,
      );
      debugPrint('NotificationService: Local notification shown — $title');
    } catch (e) {
      debugPrint('NotificationService showLocalNotification Error: $e');
    }
  }

  /// Sends WhatsApp low stock alert to family admins
  Future<void> sendLowStockAlert(String medicineName, int qty) async {
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

      // 3. Find first admin with a phone number
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
        debugPrint('NotificationService: No admin with phone number for low stock alert');
        return;
      }

      // 4. Build Hindi low stock message
      final message = 'Low Stock Alert: $medicineName — sirf $qty doses bachi hain. Refill karo!';

      var cleanPhone = targetPhone.replaceAll(RegExp(r'[\s+\-()]'), '');
      if (cleanPhone.startsWith('0')) {
        cleanPhone = '91${cleanPhone.substring(1)}';
      }

      final uri = Uri.parse(
        'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('NotificationService: Low stock WhatsApp sent to $targetName');
      } else {
        debugPrint('NotificationService: Could not launch WhatsApp for low stock alert');
      }
    } catch (e) {
      debugPrint('NotificationService Low Stock Error: $e');
    }
  }
}
