import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class AppSnackBar {
  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.checkCircle2, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 180,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.alertCircle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.red.shade500,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 180,
          left: 16,
          right: 16,
        ),
      ),
    );
  }

  static void showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(LucideIcons.info, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          ],
        ),
        backgroundColor: const Color(0xFF0EA5E9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 180,
          left: 16,
          right: 16,
        ),
      ),
    );
  }
}
