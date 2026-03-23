import 'package:flutter/material.dart';

/// Centralized floating notification system.
/// Call from any widget that has a BuildContext.
class AppNotifications {
  static void show(
    BuildContext context,
    String message, {
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final color = switch (type) {
      NotificationType.success => const Color(0xFF00E676),
      NotificationType.warning => const Color(0xFFFF9100),
      NotificationType.error   => const Color(0xFFFF1744),
      NotificationType.info    => const Color(0xFF00E5FF),
    };

    final icon = switch (type) {
      NotificationType.success => Icons.check_circle_outline,
      NotificationType.warning => Icons.warning_amber_rounded,
      NotificationType.error   => Icons.error_outline,
      NotificationType.info    => Icons.info_outline,
    };

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          elevation: 0,
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E30),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withAlpha(70), width: 1),
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(20),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Thin left-edge color accent
                Container(
                  width: 3,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [BoxShadow(color: color.withAlpha(60), blurRadius: 6)],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}

enum NotificationType { info, success, warning, error }
