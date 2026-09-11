import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/session_service.dart';
import '../../services/app_notification_service.dart';
import '../../services/auth_service.dart';

class SecurityAlertScreen extends StatefulWidget {
  final String? sessionId;
  final String? notificationId;

  const SecurityAlertScreen({super.key, this.sessionId, this.notificationId});

  @override
  State<SecurityAlertScreen> createState() => _SecurityAlertScreenState();
}

class _SecurityAlertScreenState extends State<SecurityAlertScreen> {
  final SessionService _sessionService = SessionService();
  final AppNotificationService _notificationService = AppNotificationService();
  final AuthService _authService = AuthService();
  bool _isProcessing = false;

  static const Color _danger = Color(0xFFE74C3C);
  static const Color _safe = Color(0xFF2ECC71);
  static const Color _headingColor = Color(0xFF0D3B66);

  Future<void> _markNotificationRead() async {
    if (widget.notificationId == null) return;
    try {
      await _notificationService.markAsRead(widget.notificationId!);
    } catch (_) {}
  }

  void _showResultToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmItWasMe() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.sessionId == null) {
      Navigator.pop(context);
      return;
    }
    setState(() => _isProcessing = true);
    await _sessionService.confirmSession(uid, widget.sessionId!);
    await _markNotificationRead();
    if (!mounted) return;
    setState(() => _isProcessing = false);
    Navigator.pop(context);
  }

  Future<void> _blockLogin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || widget.sessionId == null) {
      Navigator.pop(context);
      return;
    }
    setState(() => _isProcessing = true);
    await _sessionService.revokeSession(uid, widget.sessionId!);
    await _markNotificationRead();

    final email = FirebaseAuth.instance.currentUser?.email;
    if (email != null) {
      await _authService.sendPasswordResetEmail(email);
    }

    if (!mounted) return;
    setState(() => _isProcessing = false);
    _showResultToast(
        'That login has been blocked. A password reset link was sent to your email for extra safety.');
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Security Alert',
          style: GoogleFonts.poppins(
            color: _headingColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: _headingColor),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined, color: _danger, size: 64),
            const SizedBox(height: 20),
            Text(
              'New Login Detected',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _headingColor,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'We noticed a new login to your account on another device. Was this you?',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: _headingColor.withValues(alpha: 0.65),
                height: 1.5,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _confirmItWasMe,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _safe,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Yes, It Was Me',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: _isProcessing ? null : _blockLogin,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _danger,
                  side: const BorderSide(color: _danger, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(
                        "No, It Wasn't Me",
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
