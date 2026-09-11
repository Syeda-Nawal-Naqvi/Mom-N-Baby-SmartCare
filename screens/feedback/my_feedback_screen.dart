import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/feedback_service.dart';
import '../../services/theme_service.dart';

/// User-facing feedback screen — kept in its own `feedback/` folder,
/// separate from the admin-side `admin/admin_feedback_screen.dart`.
/// Shows the signed-in user's own feedback history (pending / replied)
/// and lets them submit new feedback via the floating action button.
/// Submitting uses `FeedbackService.submitFeedback`; when the admin
/// replies, `FeedbackService.replyToFeedback` on the admin side fires an
/// in-app notification back to this user automatically.
class MyFeedbackScreen extends StatefulWidget {
  const MyFeedbackScreen({super.key});

  @override
  State<MyFeedbackScreen> createState() => _MyFeedbackScreenState();
}

class _MyFeedbackScreenState extends State<MyFeedbackScreen> {
  final FeedbackService _feedbackService = FeedbackService();
  bool _submitting = false;

  static const Color primary = Color(0xFFE91E8C);

  Future<void> _openSendDialog(bool isDark) async {
    final ctrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2A1A2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Send Feedback',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: isDark
                    ? const Color(0xFFF5E6F5)
                    : const Color(0xFF3D1A2E))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Share your thoughts or report an issue.',
                style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color:
                        isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              maxLines: 4,
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF3D1A2E)),
              decoration: InputDecoration(
                hintText: 'Type your message here...',
                hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color:
                        isDark ? Colors.grey.shade600 : Colors.grey.shade400),
                filled: true,
                fillColor:
                    isDark ? const Color(0xFF3D1A3A) : Colors.grey.shade50,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF6B2D5E)
                          : Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFF6B2D5E)
                          : Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: primary, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(
                    color: isDark ? Colors.grey.shade400 : Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _submitting = true);
              final error = await _feedbackService.submitFeedback(ctrl.text);
              if (!mounted) return;
              setState(() => _submitting = false);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content:
                      Text(error ?? "Feedback sent! We'll get back to you.")));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child:
                Text('Send', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final bg = isDark ? const Color(0xFF1A0D1E) : const Color(0xFFFFF0F5);
    final cardColor = isDark ? const Color(0xFF2A1A2E) : Colors.white;
    final titleColor =
        isDark ? const Color(0xFFF5E6F5) : const Color(0xFF3D1A2E);
    final subColor = isDark ? const Color(0xFFB08AB8) : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: titleColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('My Feedback',
            style: GoogleFonts.poppins(
                fontSize: 17, fontWeight: FontWeight.w600, color: titleColor)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _submitting ? null : () => _openSendDialog(isDark),
        backgroundColor: primary,
        icon: _submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.add_comment_rounded, color: Colors.white),
        label: Text('Send Feedback',
            style: GoogleFonts.poppins(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _feedbackService.getMyFeedback(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: primary));
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Could not load your feedback.',
                    style: GoogleFonts.poppins(color: subColor)));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.feedback_outlined,
                      size: 56, color: Colors.pink.shade100),
                  const SizedBox(height: 12),
                  Text("You haven't sent any feedback yet",
                      style:
                          GoogleFonts.poppins(color: subColor, fontSize: 14)),
                  const SizedBox(height: 6),
                  Text('Tap the button below to share your thoughts',
                      style: GoogleFonts.poppins(
                          color: subColor.withValues(alpha: 0.8),
                          fontSize: 12)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final message = (data['message'] ?? '').toString();
              final status = (data['status'] ?? 'pending').toString();
              final adminReply = data['adminReply'] as String?;
              final replied = status == 'replied';
              final Timestamp? ts = data['createdAt'];
              final timeLabel = ts != null
                  ? DateFormat('dd/MM/yyyy hh:mm a').format(ts.toDate())
                  : '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: replied
                      ? null
                      : Border.all(color: primary.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
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
                          child: Text('You',
                              style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: titleColor)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: replied
                                ? const Color(0xFF10B981)
                                    .withValues(alpha: 0.12)
                                : const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.12),
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
                            fontSize: 13, color: titleColor)),
                    const SizedBox(height: 6),
                    Text(timeLabel,
                        style: GoogleFonts.poppins(
                            fontSize: 10.5, color: subColor)),
                    if (replied && adminReply != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Admin reply',
                                style: GoogleFonts.poppins(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: primary)),
                            const SizedBox(height: 4),
                            Text(adminReply,
                                style: GoogleFonts.poppins(
                                    fontSize: 12.5, color: titleColor)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
