import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;
  NotificationService._internal();
  String _normalizePhone(String raw) {
    // Remove all non-digits except leading +
    String cleaned = raw.trim();

    // If user entered with +countrycode, keep it
    if (cleaned.startsWith('+')) {
      return cleaned.replaceAll(RegExp(r'[^\d]'), '');
    }

    // Remove non-digits
    cleaned = cleaned.replaceAll(RegExp(r'[^\d]'), '');

    // India: 10-digit number → add 91 prefix
    if (cleaned.length == 10 && !cleaned.startsWith('91')) {
      return '91$cleaned';
    }

    // Remove leading 0 (landline format)
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }

    return cleaned;
  }

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

      if (admins.isEmpty) {
        // Solo user case — check if they have their own phone number
        final selfProfile = await supabase
            .from('profiles')
            .select('phone_number, full_name')
            .eq('id', userId)
            .maybeSingle();

        if (selfProfile != null && (selfProfile['phone_number'] ?? '').toString().isNotEmpty) {
          // Add self to the notify list
          final cleanPhone = _normalizePhone(selfProfile['phone_number'].toString());
          final message = 'Reminder: You missed your dose of $medicineName. '
              'Please take it if not too late. 💊';
          final uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          debugPrint('Solo user — notified self');
        } else {
          debugPrint('No admins and no self phone — skipping WhatsApp');
        }
        return;
      }

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
      final localTime = scheduledTime.isUtc ? scheduledTime.toLocal() : scheduledTime;
final timeStr = DateFormat('hh:mm a').format(localTime);
      final message = 'Hi $targetName, $patientName missed their dose of '
          '$medicineName at $timeStr. Please check on them.';

      // Clean phone: remove spaces, +, dashes, parens; fix leading 0 (assume India +91)
      final cleanPhone = _normalizePhone(targetPhone);

      final uri = Uri.parse(
        'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint(
            'NotificationService: WhatsApp launched for $targetName ($cleanPhone)');
      } else {
        debugPrint(
            'NotificationService: Could not launch WhatsApp for $targetName');
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
      final localTime = slotStartTime.isUtc ? slotStartTime.toLocal() : slotStartTime;
      final timeStr = DateFormat('hh:mm a').format(localTime);
      final message = '$patientName ko $medicineName lene ka time ho gaya hai\n'
          '($slotName \u2022 $timeStr)';

      // Clean phone number
      final cleanPhone = _normalizePhone(targetPhone);

      final uri = Uri.parse(
        'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint(
            'NotificationService: Slot reminder WhatsApp sent to $targetName');
      } else {
        debugPrint(
            'NotificationService: Could not launch WhatsApp for slot reminder');
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
        debugPrint(
            'NotificationService: No admin with phone number for low stock alert');
        return;
      }

      // 4. Build Hindi low stock message
      final message =
          'Low Stock Alert: $medicineName — sirf $qty doses bachi hain. Refill karo!';

      final cleanPhone = _normalizePhone(targetPhone);


      final uri = Uri.parse(
        'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
      );

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint(
            'NotificationService: Low stock WhatsApp sent to $targetName');
      } else {
        debugPrint(
            'NotificationService: Could not launch WhatsApp for low stock alert');
      }
    } catch (e) {
      debugPrint('NotificationService Low Stock Error: $e');
    }
  }

  Future<void> sendSlotMissedAlert(
      String slotKey, List<String> medicineNames) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null || medicineNames.isEmpty) return;

      final membership = await supabase
          .from('family_members')
          .select('group_id')
          .eq('user_id', userId)
          .maybeSingle();
      if (membership == null) return;

      final admins = await supabase
          .from('family_members')
          .select('user_id')
          .eq('group_id', membership['group_id'])
          .eq('role', 'admin')
          .neq('user_id', userId);
      if (admins.isEmpty) return;

      String? targetPhone;
      String targetName = 'Admin';
      for (final admin in admins) {
        final profile = await supabase
            .from('profiles')
            .select('full_name, phone_number')
            .eq('id', admin['user_id'])
            .maybeSingle();
        final phone = profile?['phone_number'] as String?;
        if (phone != null && phone.isNotEmpty) {
          targetPhone = phone;
          targetName = profile?['full_name'] ?? 'Admin';
          break;
        }
      }
      if (targetPhone == null) return;

      final medicineList = medicineNames.length == 1
          ? medicineNames.first
          : medicineNames.join(', ');
      final message =
          'Hi $targetName, medicines were missed for $slotKey: $medicineList. Please check.';

      final cleanPhone = _normalizePhone(targetPhone);


      final uri = Uri.parse(
        'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('NotificationService Slot Missed Error: $e');
    }
  }
}
