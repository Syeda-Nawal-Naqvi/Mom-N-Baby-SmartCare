import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/session_service.dart';
import '../../services/theme_service.dart';

/// "Where you're logged in" screen (Settings → Login Activity), same idea
/// as Instagram/Google's device list: every currently-active session on
/// this account, which one is "This device", and a Sign Out button per
/// row that revokes exactly that device's session (SessionService.
/// revokeSession) — the same mechanism the new-login security alert uses,
/// just triggered manually instead of from a notification.
class LoginActivityScreen extends StatefulWidget {
  const LoginActivityScreen({super.key});

  @override
  State<LoginActivityScreen> createState() => _LoginActivityScreenState();
}

class _LoginActivityScreenState extends State<LoginActivityScreen> {
  final SessionService _sessionService = SessionService();
  String? _mySessionId;

  @override
  void initState() {
    super.initState();
    _loadMySessionId();
  }

  Future<void> _loadMySessionId() async {
    final id = await _sessionService.getLocalSessionId();
    if (mounted) setState(() => _mySessionId = id);
  }

  void _confirmSignOut(AppThemeColors theme, String uid, String sessionId,
      String deviceLabel, bool isThisDevice) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign out $deviceLabel?',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: theme.textPrimary)),
        content: Text(
          isThisDevice
              ? 'This is the device you\'re using right now — you\'ll be '
                  'signed out immediately and need to log in again.'
              : 'That device will be signed out immediately, and a '
                  'password-reset email will be sent to your account as a '
                  'precaution.',
          style: GoogleFonts.poppins(fontSize: 13, color: theme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _sessionService.revokeSession(uid, sessionId);
              if (!isThisDevice) {
                final email = FirebaseAuth.instance.currentUser?.email;
                if (email != null && email.isNotEmpty) {
                  try {
                    await FirebaseAuth.instance
                        .sendPasswordResetEmail(email: email);
                  } catch (_) {
                    // Best-effort precaution only — sign-out itself has
                    // already succeeded regardless.
                  }
                }
              }
              // If it's THIS device, SessionGuardService's own
              // watchSessionRevoked listener (already running) will pick
              // this up within moments and perform the actual forced
              // logout + redirect — no need to duplicate that here.
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red.shade500),
            child: Text('Sign Out',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return ThemeAware(
      builder: (context, theme) {
        return Scaffold(
          backgroundColor: theme.bg,
          appBar: AppBar(
            backgroundColor: theme.surface,
            elevation: 0,
            iconTheme: IconThemeData(color: theme.accent),
            title: Text('Login Activity',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.accent)),
            centerTitle: true,
          ),
          body: uid == null
              ? Center(
                  child: Text('Not signed in',
                      style: GoogleFonts.poppins(color: theme.textSecondary)))
              : StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                  stream: _sessionService.streamActiveSessions(uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                          child:
                              CircularProgressIndicator(color: theme.accent));
                    }
                    if (snapshot.hasError) {
                      return Center(
                          child: Text('Could not load your devices.',
                              style: GoogleFonts.poppins(
                                  color: theme.textSecondary)));
                    }
                    final docs = snapshot.data ?? [];
                    // "This device" first, then most-recently active.
                    final sorted = docs.toList()
                      ..sort((a, b) {
                        if (a.id == _mySessionId) return -1;
                        if (b.id == _mySessionId) return 1;
                        DateTime resolve(dynamic v) =>
                            v is Timestamp ? v.toDate() : DateTime.now();
                        return resolve(b.data()['lastSeenAt'])
                            .compareTo(resolve(a.data()['lastSeenAt']));
                      });

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14, left: 4),
                          child: Text(
                            'Devices currently signed in to your account. '
                            'Don\'t recognize one? Sign it out.',
                            style: GoogleFonts.poppins(
                                fontSize: 12.5, color: theme.textSecondary),
                          ),
                        ),
                        ...sorted.map((doc) {
                          final data = doc.data();
                          final isThisDevice = doc.id == _mySessionId;
                          final deviceLabel =
                              (data['deviceLabel'] ?? 'Unknown device')
                                  .toString();
                          final Timestamp? lastSeen = data['lastSeenAt'];
                          final Timestamp? createdAt = data['createdAt'];
                          final timeLabel = lastSeen != null
                              ? DateFormat('dd/MM/yyyy hh:mm a')
                                  .format(lastSeen.toDate())
                              : createdAt != null
                                  ? DateFormat('dd/MM/yyyy hh:mm a')
                                      .format(createdAt.toDate())
                                  : '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isThisDevice
                                    ? theme.accent.withValues(alpha: 0.35)
                                    : theme.accent.withValues(alpha: 0.10),
                              ),
                              boxShadow: [
                                BoxShadow(
                                    color: theme.accent.withValues(
                                        alpha: theme.isDark ? 0.14 : 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: theme.accent
                                        .withValues(alpha: theme.isDark ? 0.18 : 0.10),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    deviceLabel.toLowerCase().contains('android') ||
                                            deviceLabel
                                                .toLowerCase()
                                                .contains('iphone')
                                        ? Icons.smartphone_rounded
                                        : deviceLabel
                                                .toLowerCase()
                                                .contains('web')
                                            ? Icons.language_rounded
                                            : Icons.laptop_mac_rounded,
                                    color: theme.accent,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(deviceLabel,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.poppins(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: theme.textPrimary)),
                                          ),
                                          if (isThisDevice) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981)
                                                    .withValues(alpha: 0.14),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text('This device',
                                                  style: GoogleFonts.poppins(
                                                      fontSize: 9.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: const Color(
                                                          0xFF10B981))),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(timeLabel,
                                          style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              color: theme.textSecondary)),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _confirmSignOut(theme, uid,
                                      doc.id, deviceLabel, isThisDevice),
                                  child: Text('Sign Out',
                                      style: GoogleFonts.poppins(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.red.shade400)),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
        );
      },
    );
  }
}
