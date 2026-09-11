import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/feedback_service.dart';
import '../../services/theme_service.dart';

/// Admin-only screen: view every piece of user feedback, reply to it (which
/// updates the feedback doc and fires an in-app notification to the user
/// via FeedbackService.replyToFeedback), or delete a feedback item.
///
/// The AppBar no longer has a filter *icon* — a top-right funnel icon with
/// only two states (all vs. pending) added a tap with no extra information
/// the two segmented pills below don't already show more clearly, so it
/// was removed. "Pending only" is now a plain, always-visible segmented
/// control at the top of the list instead.
class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  final FeedbackService _feedbackService = FeedbackService();
  bool _pendingOnly = true;

  Future<void> _openReplyDialog({
    required AppThemeColors theme,
    required String feedbackId,
    required String userId,
    required String userEmail,
    String? userName,
    required String message,
    required bool alreadyReplied,
    String? existingReply,
  }) async {
    final replyCtrl = TextEditingController(text: existingReply ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(alreadyReplied ? 'Edit Reply' : 'Reply to Feedback',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: theme.textPrimary)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (userName != null && userName.trim().isNotEmpty)
                Text(userName,
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary)),
              Text(userEmail,
                  style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.textSecondary)),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(message,
                    style: GoogleFonts.poppins(
                        fontSize: 13, color: theme.textPrimary)),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: replyCtrl,
                maxLines: 4,
                style:
                    GoogleFonts.poppins(fontSize: 14, color: theme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Write your reply...',
                  hintStyle: GoogleFonts.poppins(color: theme.textSecondary),
                  filled: true,
                  fillColor: theme.surfaceAlt,
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.border)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.accent, width: 1.4)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (replyCtrl.text.trim().isEmpty) return;
              final error = await _feedbackService.replyToFeedback(
                feedbackId: feedbackId,
                userId: userId,
                originalMessage: message,
                reply: replyCtrl.text.trim(),
              );
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error ?? 'Reply sent to user.')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: theme.accent),
            child: Text('Send Reply',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(AppThemeColors theme, String feedbackId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete feedback?',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: theme.textPrimary)),
        content: Text('This permanently removes this feedback item.',
            style:
                GoogleFonts.poppins(fontSize: 13, color: theme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _feedbackService.deleteFeedback(feedbackId);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red.shade500),
            child:
                Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
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
            title: Text('Feedback Management',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.accent)),
            centerTitle: true,
          ),
          body: Column(
            children: [
              // ── Segmented "All / Pending only" control — replaces the
              // old funnel icon in the AppBar with something that shows
              // both states at a glance instead of needing a tap+tooltip
              // to discover what the icon even meant.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _segment(theme,
                            label: 'Pending only',
                            selected: _pendingOnly, onTap: () {
                          setState(() => _pendingOnly = true);
                        }),
                      ),
                      Expanded(
                        child: _segment(theme,
                            label: 'All', selected: !_pendingOnly, onTap: () {
                          setState(() => _pendingOnly = false);
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<QueryDocumentSnapshot>>(
                  stream: _pendingOnly
                      ? _feedbackService.getPendingFeedback()
                      : _feedbackService.getAllFeedback(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                          child:
                              CircularProgressIndicator(color: theme.accent));
                    }
                    if (snapshot.hasError) {
                      return Center(
                          child: Text('Could not load feedback.',
                              style: GoogleFonts.poppins(
                                  color: theme.textSecondary)));
                    }
                    final docs = snapshot.data ?? [];
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
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Image.asset(
                                  'assets/icons/feedback.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => Icon(
                                      Icons.feedback_outlined,
                                      size: 40,
                                      color: theme.accent),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                                _pendingOnly
                                    ? 'No pending feedback'
                                    : 'No feedback yet',
                                style: GoogleFonts.poppins(
                                    color: theme.textSecondary, fontSize: 14)),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final userId = (data['userId'] ?? '').toString();
                        final userEmail =
                            (data['userEmail'] ?? 'Unknown user').toString();
                        final userName = (data['userName'] as String?)?.trim();
                        final displayName =
                            (userName == null || userName.isEmpty)
                                ? 'Unknown user'
                                : userName;
                        final message = (data['message'] ?? '').toString();
                        final status = (data['status'] ?? 'pending').toString();
                        final adminReply = data['adminReply'] as String?;
                        final replied = status == 'replied';
                        final Timestamp? ts = data['createdAt'];
                        final timeLabel = ts != null
                            ? DateFormat('dd/MM/yyyy hh:mm a')
                                .format(ts.toDate())
                            : '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: replied
                                ? Border.all(
                                    color: theme.accent.withValues(alpha: 0.10))
                                : Border.all(
                                    color:
                                        theme.accent.withValues(alpha: 0.35)),
                            boxShadow: [
                              BoxShadow(
                                  color: theme.accent.withValues(
                                      alpha: theme.isDark ? 0.14 : 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(displayName,
                                            style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: theme.textPrimary)),
                                        Text(userEmail,
                                            style: GoogleFonts.poppins(
                                                fontSize: 11,
                                                color: theme.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: replied
                                          ? const Color(0xFF10B981)
                                              .withValues(alpha: 0.14)
                                          : const Color(0xFFF59E0B)
                                              .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      replied ? 'Replied' : 'Pending',
                                      style: GoogleFonts.poppins(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: replied
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFF59E0B)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(message,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13, color: theme.textPrimary)),
                              const SizedBox(height: 6),
                              Text(timeLabel,
                                  style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      color: theme.textSecondary)),
                              if (replied && adminReply != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: theme.surfaceAlt,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Your reply',
                                          style: GoogleFonts.poppins(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w600,
                                              color: theme.accentLight)),
                                      const SizedBox(height: 4),
                                      Text(adminReply,
                                          style: GoogleFonts.poppins(
                                              fontSize: 12.5,
                                              color: theme.textPrimary)),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: userId.isEmpty
                                          ? null
                                          : () => _openReplyDialog(
                                                theme: theme,
                                                feedbackId: doc.id,
                                                userId: userId,
                                                userEmail: userEmail,
                                                userName: userName,
                                                message: message,
                                                alreadyReplied: replied,
                                                existingReply: adminReply,
                                              ),
                                      icon: Icon(
                                          replied
                                              ? Icons.edit_rounded
                                              : Icons.reply_rounded,
                                          size: 16),
                                      label: Text(
                                          replied ? 'Edit Reply' : 'Reply',
                                          style: GoogleFonts.poppins(
                                              fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: theme.accent,
                                        side: BorderSide(color: theme.accent),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () =>
                                        _confirmDelete(theme, doc.id),
                                    icon: Icon(Icons.delete_outline_rounded,
                                        color: Colors.red.shade400),
                                    tooltip: 'Delete feedback',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _segment(AppThemeColors theme,
      {required String label,
      required bool selected,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? theme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : theme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
