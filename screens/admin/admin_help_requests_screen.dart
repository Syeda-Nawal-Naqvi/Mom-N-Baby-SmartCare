import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/help_request_service.dart';
import '../../services/theme_service.dart';

/// Admin-only screen: locked-out users who submitted the public "Need
/// Help?" form (no account, no sign-in) via NeedHelpScreen. Since these
/// people have no account, there's no in-app notification to send back
/// — "Reply by Email" opens the device's native mail composer (signed
/// in as the app's own support Gmail on the admin's phone) addressed to
/// whatever email they left, exactly like the Feedback screen's reply
/// but through the OS mail app instead of Firestore.
class AdminHelpRequestsScreen extends StatefulWidget {
  const AdminHelpRequestsScreen({super.key});

  @override
  State<AdminHelpRequestsScreen> createState() =>
      _AdminHelpRequestsScreenState();
}

class _AdminHelpRequestsScreenState extends State<AdminHelpRequestsScreen> {
  final HelpRequestService _helpService = HelpRequestService();
  bool _pendingOnly = true;

  Future<void> _reply(
      AppThemeColors theme, String id, String email, String name) async {
    try {
      await _helpService.replyViaEmail(
        requestId: id,
        recipientEmail: email,
        recipientName: name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Mail app opened — marked as resolved once sent.')),
      );
    } on NoEmailAppException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'No email app is set up on this device. Sign in to the '
              'support Gmail in Gmail/Mail app first.',
              style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: const Color(0xFFE74C3C),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('$e', style: GoogleFonts.poppins(fontSize: 13)),
            backgroundColor: const Color(0xFFE74C3C)),
      );
    }
  }

  void _confirmDelete(AppThemeColors theme, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete this request?',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: theme.textPrimary)),
        content: Text('This permanently removes this help request.',
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
              _helpService.deleteHelpRequest(id);
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
            title: Text('Help Requests',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.accent)),
            centerTitle: true,
          ),
          body: Column(
            children: [
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
                      ? _helpService.streamPending()
                      : _helpService.streamAll(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                          child:
                              CircularProgressIndicator(color: theme.accent));
                    }
                    if (snapshot.hasError) {
                      return Center(
                          child: Text('Could not load help requests.',
                              style: GoogleFonts.poppins(
                                  color: theme.textSecondary)));
                    }
                    final docs = snapshot.data ?? [];
                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.support_agent_rounded,
                                size: 56,
                                color: theme.accent.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text(
                                _pendingOnly
                                    ? 'No pending help requests'
                                    : 'No help requests yet',
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
                        final name = (data['name'] ?? 'Unknown').toString();
                        final email = (data['email'] ?? '').toString();
                        final message = (data['message'] ?? '').toString();
                        final status = (data['status'] ?? 'pending').toString();
                        final resolved = status == 'resolved';
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
                            border: resolved
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
                                        Text(name,
                                            style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: theme.textPrimary)),
                                        Text(email,
                                            style: GoogleFonts.poppins(
                                                fontSize: 11.5,
                                                color: theme.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: resolved
                                          ? const Color(0xFF10B981)
                                              .withValues(alpha: 0.14)
                                          : const Color(0xFFF59E0B)
                                              .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      resolved ? 'Resolved' : 'Pending',
                                      style: GoogleFonts.poppins(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: resolved
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFF59E0B)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(message,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13, color: theme.textPrimary)),
                              const SizedBox(height: 6),
                              Text(timeLabel,
                                  style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      color: theme.textSecondary)),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: email.isEmpty
                                          ? null
                                          : () => _reply(
                                              theme, doc.id, email, name),
                                      icon: const Icon(Icons.email_rounded,
                                          size: 16),
                                      label: Text('Reply by Email',
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
                                  if (!resolved) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () =>
                                          _helpService.markResolved(doc.id),
                                      icon: Icon(Icons.check_circle_outline,
                                          color: const Color(0xFF10B981)),
                                      tooltip: 'Mark resolved',
                                    ),
                                  ],
                                  IconButton(
                                    onPressed: () =>
                                        _confirmDelete(theme, doc.id),
                                    icon: Icon(Icons.delete_outline_rounded,
                                        color: Colors.red.shade400),
                                    tooltip: 'Delete request',
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
