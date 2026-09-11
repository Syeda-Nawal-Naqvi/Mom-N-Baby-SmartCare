import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_notification_service.dart';
import '../services/theme_service.dart';

class NotificationBell extends StatelessWidget {
  final VoidCallback onTap;
  const NotificationBell({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final bgColor = ThemeService.surface(isDark);
    // Sharp, saturated red always — not the softened dangerSoft tone,
    // so the unread count stands out clearly against the chip.
    const badgeColor = Color(0xFFE60023);

    return StreamBuilder<int>(
      stream: AppNotificationService().streamUnreadCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              // Was hardcoded Colors.white — now follows the app's
              // dark/light surface color so the bell's own chip
              // blends into the themed top bar instead of showing a
              // leftover white square in dark mode.
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  // Fixed bright yellow glow, always — does not
                  // follow the theme accent/palette per request.
                  color: const Color(0xFFFFD400)
                      .withValues(alpha: isDark ? 0.55 : 0.40),
                  blurRadius: isDark ? 16 : 10,
                  spreadRadius: isDark ? 0.6 : 0,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Image.asset(
                    'assets/icons/bell.png',
                    width: 22,
                    height: 22,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.notifications_rounded,
                      color: Color(0xFFFFD400),
                      size: 22,
                    ),
                  ),
                ),
                if (count > 0)
                  Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        shape: BoxShape.circle,
                        border: isDark
                            ? Border.all(color: bgColor, width: 1)
                            : null,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        count > 9 ? '9+' : '$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
