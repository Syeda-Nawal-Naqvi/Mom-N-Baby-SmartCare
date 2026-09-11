import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/app_notification_service.dart';
import '../../services/theme_service.dart';

/// Admin's own in-app notification center. This is deliberately a separate
/// widget from the user-facing `notifications/notifications_screen.dart`
/// so admin-facing notification UI can evolve independently — even though
/// today it reads from the same underlying `AppNotificationService`/
/// `notifications` collection, scoped to whichever uid is currently
/// signed in (which, on this screen, is always the admin).
class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final AppNotificationService _service = AppNotificationService();

  @override
  void initState() {
    super.initState();
    // Trim to the retention window (10 read / 20 total-if-unread) every
    // time this screen is opened, in addition to the continuous
    // enforcement already running via NotificationWatcherMixin.
    _service.enforceRetention();
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'feedback_submitted':
        return Icons.feedback_rounded;
      case 'feedback_reply':
        return Icons.feedback_rounded;
      case 'admin_message':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorFor(AppThemeColors theme, String type) {
    switch (type) {
      case 'feedback_submitted':
        return ThemeService.warning;
      case 'feedback_reply':
        return ThemeService.success;
      case 'admin_message':
        return theme.accent;
      default:
        return theme.infoBlue;
    }
  }

  /// Unsorted-on-purpose stream (see AppNotificationService), sorted
  /// newest-first on the client against the small per-admin result set.
  /// Docs without a server-confirmed `createdAt` yet sort as "now" so
  /// brand-new items still show up at the top immediately.
  List<QueryDocumentSnapshot> _sortedNewestFirst(
      List<QueryDocumentSnapshot> docs) {
    DateTime resolve(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    final sorted = List<QueryDocumentSnapshot>.from(docs);
    sorted.sort((a, b) {
      final da = (a.data() as Map<String, dynamic>)['createdAt'];
      final db = (b.data() as Map<String, dynamic>)['createdAt'];
      return resolve(db).compareTo(resolve(da));
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        return Scaffold(
          backgroundColor: theme.bg,
          appBar: AppBar(
            backgroundColor: theme.surface,
            elevation: 0,
            iconTheme: IconThemeData(color: theme.accent),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Admin Notifications',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.accent)),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(Icons.done_all_rounded, color: theme.accent),
                tooltip: 'Mark all as read',
                onPressed: () => _service.markAllAsRead(),
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: _service.streamMyNotifications(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                    child: CircularProgressIndicator(color: theme.accent));
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('Something went wrong.',
                      style: GoogleFonts.poppins(color: theme.textSecondary)),
                );
              }
              final docs = _sortedNewestFirst(snapshot.data?.docs ?? []);
              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: theme.accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.notifications_off_rounded,
                            size: 40, color: theme.accent),
                      ),
                      const SizedBox(height: 12),
                      Text('No notifications yet',
                          style: GoogleFonts.poppins(
                              color: theme.textSecondary, fontSize: 14)),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final bool read = data['read'] ?? false;
                  final String type = data['type'] ?? 'admin_message';
                  final String title = data['title'] ?? '';
                  final String body = data['body'] ?? '';
                  final Timestamp? ts = data['createdAt'];
                  final String timeLabel = ts != null
                      ? DateFormat('dd/MM/yyyy hh:mm a').format(ts.toDate())
                      : '';
                  final color = _colorFor(theme, type);

                  return Dismissible(
                    key: Key(doc.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: theme.danger,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child:
                          const Icon(Icons.delete_rounded, color: Colors.white),
                    ),
                    onDismissed: (_) => _service.deleteNotification(doc.id),
                    child: GestureDetector(
                      onTap: () {
                        if (!read) _service.markAsRead(doc.id);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: read
                              ? Border.all(color: theme.border)
                              : Border.all(color: color.withValues(alpha: 0.4)),
                          boxShadow: [
                            BoxShadow(
                              color: theme.accent.withValues(
                                  alpha: theme.isDark ? 0.10 : 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child:
                                  Icon(_iconFor(type), color: color, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: read
                                                ? FontWeight.w500
                                                : FontWeight.w700,
                                            color: theme.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (!read)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(body,
                                      style: GoogleFonts.poppins(
                                          fontSize: 12.5,
                                          color: theme.textSecondary)),
                                  const SizedBox(height: 6),
                                  Text(timeLabel,
                                      style: GoogleFonts.poppins(
                                          fontSize: 10.5,
                                          color: theme.textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
