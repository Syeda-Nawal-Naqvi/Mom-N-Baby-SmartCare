import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../services/app_notification_service.dart';
import '../../services/local_notification_service.dart';
import '../../utils/contact_links.dart';
import '../auth/forgot_password_screen.dart';
import 'login_activity_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AppNotificationService _notificationService = AppNotificationService();

  bool _notificationsEnabled = true;
  bool _isLoading = false;

  // ═════════════════════════════════════════════════════════════════════
  // OS-LEVEL NOTIFICATION PERMISSION BANNER (Instagram-style)
  // ═════════════════════════════════════════════════════════════════════
  //
  // Separate from `_notificationsEnabled` above, which is the app-level
  // Firestore preference (sound/pop toggle). This tracks the actual
  // Android/iOS runtime permission. When it's off, a dismissible banner
  // is shown at the top of this screen so the user can fix it without
  // needing to log out/in again.
  bool _osPermissionGranted = true;
  bool _osPermissionLoading = true;

  // Session-scoped only (not persisted) — dismissing hides the banner
  // for the rest of this app session. A fresh app open resets this, so
  // it reappears if the permission is still off, mirroring how
  // Instagram/WhatsApp nag gently instead of forcing the decision.
  static bool _bannerDismissedThisSession = false;

  static const String _noSpaceHelper =
      'Use letters, numbers, and symbols (- _ !) — no spaces.';
  static const Color _settingsPageBg = Color(0xFFF1F8FF);
  static const Color _settingsCardBg = Color(0xFFEAF4FF);
  static const Color _settingsBlue = Color(0xFF3B82F6);
  static const Color _darkBlue = Color(0xFF1E3A8A);
  static const Color _instagramPink = Color(0xFFE91E8C);
  static const Color _gmailRed = Color(0xFFEA4335);
  static const double _maxContentWidth = 640;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefs();
    _refreshOsPermissionStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Re-checks OS permission whenever the app comes back to the
  /// foreground — this is what catches the case where the user left
  /// this screen, went to phone Settings, turned notifications on, and
  /// came back. Without this, the banner would keep showing until the
  /// screen was reopened from scratch.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshOsPermissionStatus();
    }
  }

  Future<void> _refreshOsPermissionStatus() async {
    final granted = await LocalNotificationService().isPermissionGranted();
    if (!mounted) return;
    setState(() {
      _osPermissionGranted = granted;
      _osPermissionLoading = false;
    });
  }

  Future<void> _handleEnableNotifications() async {
    final granted =
        await LocalNotificationService().checkAndRequestPermission(context);
    if (!mounted) return;
    setState(() => _osPermissionGranted = granted);
  }

  void _dismissNotificationBanner() {
    setState(() => _bannerDismissedThisSession = true);
  }

  Future<void> _loadPrefs() async {
    final enabled = await _notificationService.isNotificationsEnabled();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = enabled;
    });
  }

  void _showToast(String message, {required bool isSuccess}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style:
                      GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: isSuccess ? ThemeService.success : ThemeService.danger,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        final isDark = context.read<ThemeNotifier>().isDarkMode;
        final accent = ThemeService.activeAccent(isDark);
        return AlertDialog(
          backgroundColor: ThemeService.surface(isDark),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Change Password',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: ThemeService.textPrimary(isDark),
              )),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(
                    ctrl: currentCtrl,
                    hint: 'Current password',
                    isPassword: true,
                    isDark: isDark),
                const SizedBox(height: 12),
                _dialogField(
                    ctrl: newCtrl,
                    hint: 'New password',
                    isPassword: true,
                    isDark: isDark,
                    helperText: _noSpaceHelper),
                const SizedBox(height: 12),
                _dialogField(
                    ctrl: confirmCtrl,
                    hint: 'Confirm new password',
                    isPassword: true,
                    isDark: isDark),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen()));
                    },
                    child: Text('Forgot your password?',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: accent)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(
                      color: ThemeService.textSecondary(isDark))),
            ),
            ElevatedButton(
              onPressed: () async {
                if (newCtrl.text.contains(' ') ||
                    confirmCtrl.text.contains(' ')) {
                  _showToast(
                      "Spaces aren't allowed. Use letters, numbers, or symbols like - _ instead.",
                      isSuccess: false);
                  return;
                }
                if (newCtrl.text != confirmCtrl.text) {
                  _showToast('Passwords do not match', isSuccess: false);
                  return;
                }
                if (newCtrl.text.length < 6) {
                  _showToast('Minimum 6 characters required', isSuccess: false);
                  return;
                }
                final error = await _authService.changePassword(
                  oldPassword: currentCtrl.text,
                  newPassword: newCtrl.text,
                );
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (error == null) {
                  _showToast('Password updated successfully!', isSuccess: true);
                } else {
                  _showToast(error, isSuccess: false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Update',
                  style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changeEmail() async {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        final isDark = context.read<ThemeNotifier>().isDarkMode;
        final accent = ThemeService.activeAccent(isDark);
        return AlertDialog(
          backgroundColor: ThemeService.surface(isDark),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Change Email',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: ThemeService.textPrimary(isDark))),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'A verification link will be sent to your new email. Your email updates only after you click that link.',
                  style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: ThemeService.textSecondary(isDark)),
                ),
                const SizedBox(height: 14),
                _dialogField(
                    ctrl: emailCtrl, hint: 'New email address', isDark: isDark),
                const SizedBox(height: 12),
                _dialogField(
                    ctrl: passwordCtrl,
                    hint: 'Current password',
                    isPassword: true,
                    isDark: isDark),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(
                      color: ThemeService.textSecondary(isDark))),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailCtrl.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  _showToast('Enter a valid email', isSuccess: false);
                  return;
                }
                if (passwordCtrl.text.isEmpty) {
                  _showToast('Enter your current password', isSuccess: false);
                  return;
                }
                final error = await _authService.requestEmailChange(
                    email, passwordCtrl.text);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                if (error == null) {
                  _showToast(
                      'Verification link sent to $email. Click it to confirm.',
                      isSuccess: true);
                } else {
                  _showToast(error, isSuccess: false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Send Link',
                  style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendFeedback() async {
    final feedbackCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        final isDark = context.read<ThemeNotifier>().isDarkMode;
        final accent = ThemeService.activeAccent(isDark);
        return AlertDialog(
          backgroundColor: ThemeService.surface(isDark),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Send Feedback',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: ThemeService.textPrimary(isDark))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Share your thoughts or report an issue.',
                  style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: ThemeService.textSecondary(isDark))),
              const SizedBox(height: 14),
              TextField(
                controller: feedbackCtrl,
                maxLines: 4,
                style: GoogleFonts.poppins(
                    fontSize: 14, color: ThemeService.textPrimary(isDark)),
                decoration: InputDecoration(
                  hintText: 'Type your message here...',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 13, color: ThemeService.textSecondary(isDark)),
                  filled: true,
                  fillColor: ThemeService.surfaceAlt(isDark),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ThemeService.border(isDark)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: ThemeService.border(isDark)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: accent, width: 1.5),
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
                      color: ThemeService.textSecondary(isDark))),
            ),
            ElevatedButton(
              onPressed: () async {
                final message = feedbackCtrl.text.trim();
                if (message.isEmpty) {
                  _showToast('Please enter a message', isSuccess: false);
                  return;
                }
                try {
                  final uid = _auth.currentUser?.uid ?? '';
                  final userDoc =
                      await _firestore.collection('users').doc(uid).get();
                  final userName = (userDoc.data()?['name'] ?? '').toString();

                  await _firestore.collection('feedback').add({
                    'userId': uid,
                    'userEmail': _auth.currentUser?.email ?? '',
                    'userName': userName,
                    'message': message,
                    'status': 'pending',
                    'adminReply': null,
                    'createdAt': FieldValue.serverTimestamp(),
                    'repliedAt': null,
                    'notificationRead': false,
                  });

                  try {
                    final adminsSnap = await _firestore
                        .collection('users')
                        .where('role', isEqualTo: 'admin')
                        .where('blocked', isEqualTo: false)
                        .get();
                    for (final admin in adminsSnap.docs) {
                      await _notificationService.sendToUser(
                        userId: admin.id,
                        title: 'New Feedback',
                        body: message,
                        type: 'feedback_reply',
                        senderName: userName.isNotEmpty
                            ? userName
                            : (_auth.currentUser?.email ?? 'A user'),
                      );
                    }
                  } catch (e) {
                    debugPrint('Could not notify admins of feedback: $e');
                  }

                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _showToast("Feedback sent! We'll get back to you.",
                      isSuccess: true);
                } catch (e) {
                  debugPrint('Failed to send feedback: $e');
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _showToast('Failed to send feedback.', isSuccess: false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child:
                  Text('Send', style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    final passwordCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = context.read<ThemeNotifier>().isDarkMode;
        return AlertDialog(
          backgroundColor: ThemeService.surface(isDark),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Delete Account',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: ThemeService.dangerSoft(isDark))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This is permanent and cannot be undone. All your data will be deleted.',
                style: GoogleFonts.poppins(
                    fontSize: 13, color: ThemeService.textSecondary(isDark)),
              ),
              const SizedBox(height: 16),
              _dialogField(
                  ctrl: passwordCtrl,
                  hint: 'Enter password to confirm',
                  isPassword: true,
                  isDark: isDark),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(
                      color: ThemeService.textSecondary(isDark))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Delete',
                  style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    try {
      setState(() => _isLoading = true);
      final user = _auth.currentUser!;
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: passwordCtrl.text,
      );
      await user.reauthenticateWithCredential(cred);
      await _firestore.collection('users').doc(user.uid).delete();
      await user.delete();
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showToast('Incorrect password. Try again.', isSuccess: false);
    }
  }

  Widget _dialogField({
    required TextEditingController ctrl,
    required String hint,
    bool isPassword = false,
    bool isDark = false,
    String? helperText,
  }) {
    final accent = ThemeService.activeAccent(isDark);
    return TextField(
      controller: ctrl,
      obscureText: isPassword,
      inputFormatters:
          isPassword ? [FilteringTextInputFormatter.deny(RegExp(r'\s'))] : null,
      style: GoogleFonts.poppins(
          fontSize: 14, color: ThemeService.textPrimary(isDark)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
            fontSize: 13, color: ThemeService.textSecondary(isDark)),
        filled: true,
        fillColor: ThemeService.surfaceAlt(isDark),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        helperText: helperText,
        helperMaxLines: 2,
        helperStyle: GoogleFonts.poppins(
            fontSize: 10.5,
            color: ThemeService.textSecondary(isDark).withValues(alpha: 0.85)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ThemeService.border(isDark)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ThemeService.border(isDark)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
    );
  }

  /// Instagram-style dismissible banner shown ONLY when the OS-level
  /// notification permission is currently off. Styled to match
  /// `_buildSettingsTile`'s card language (same border/shadow/radius
  /// pattern) so it reads as a native part of this screen rather than a
  /// bolted-on component.
  Widget _buildNotificationPermissionBanner({
    required bool isDark,
    required Color titleColor,
    required Color subtitleColor,
    required Color accent,
  }) {
    if (_osPermissionLoading ||
        _osPermissionGranted ||
        _bannerDismissedThisSession) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        decoration: BoxDecoration(
          color: isDark ? ThemeService.surface(isDark) : _settingsCardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _settingsBlue.withValues(alpha: isDark ? 0.32 : 0.22),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _settingsBlue.withValues(alpha: isDark ? 0.42 : 0.30),
              blurRadius: isDark ? 30 : 26,
              spreadRadius: isDark ? 1.2 : 0.8,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.15 : 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.notifications_off_outlined,
                  color: accent, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Turn on notifications',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: titleColor)),
                  const SizedBox(height: 3),
                  Text(
                    'Feedback replies aur admin messages ke liye alerts na miss karein.',
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: subtitleColor, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      onPressed: _handleEnableNotifications,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: Text('Turn On',
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close_rounded,
                  size: 18, color: subtitleColor.withValues(alpha: 0.6)),
              splashRadius: 18,
              onPressed: _dismissNotificationBanner,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    final isDark = themeNotifier.isDarkMode;

    final bgColor = isDark ? ThemeService.bg(isDark) : _settingsPageBg;
    final cardColor = ThemeService.surface(isDark);
    final titleColor = ThemeService.textPrimary(isDark);
    final subtitleColor = ThemeService.textSecondary(isDark);
    final dividerColor = ThemeService.border(isDark);
    final accent = ThemeService.activeAccent(isDark);
    final sectionLabelColor = isDark ? accent : _darkBlue;
    final infoBlue = ThemeService.infoBlue(isDark);
    final dangerSoft = ThemeService.dangerSoft(isDark);
    final mint = const Color(0xFF10B981);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: accent, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Settings',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w600, color: titleColor)),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accent))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: _maxContentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Instagram-style banner sits at the very top —
                        // renders nothing once permission is granted or
                        // dismissed for this session.
                        _buildNotificationPermissionBanner(
                          isDark: isDark,
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                          accent: accent,
                        ),
                        _buildSectionLabel('Account', color: sectionLabelColor),
                        const SizedBox(height: 12),
                        _buildSettingsTile(
                          iconAsset: 'assets/icons/msg.png',
                          fallbackIcon: Icons.mail_outline_rounded,
                          iconBg:
                              infoBlue.withValues(alpha: isDark ? 0.18 : 0.10),
                          iconColor: infoBlue,
                          label: 'Change Email',
                          subtitle: 'Verify a new email address',
                          onTap: _changeEmail,
                          cardColor: cardColor,
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),
                        _buildSettingsTile(
                          iconAsset: 'assets/icons/password.png',
                          fallbackIcon: Icons.lock_outline_rounded,
                          iconBg: isDark
                              ? const Color(0xFF102A54)
                              : const Color(0xFFDCE8FB),
                          iconColor:
                              isDark ? const Color(0xFF60A5FA) : _darkBlue,
                          label: 'Change Password',
                          subtitle: 'Update or reset your password',
                          onTap: _changePassword,
                          cardColor: cardColor,
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),
                        _buildSettingsTile(
                          iconAsset: 'assets/icons/devices.png',
                          fallbackIcon: Icons.devices_rounded,
                          iconBg: isDark
                              ? const Color(0xFF3A1440)
                              : const Color(0xFFF3E5F9),
                          iconColor:
                              isDark ? const Color(0xFFD8A6E8) : _darkBlue,
                          label: 'Login Activity',
                          subtitle: 'See and manage your signed-in devices',
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginActivityScreen()),
                          ),
                          cardColor: cardColor,
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),
                        _buildSettingsTile(
                          iconAsset: 'assets/icons/feedback.png',
                          fallbackIcon: Icons.feedback_outlined,
                          iconBg: isDark
                              ? const Color(0xFF0A2A1A)
                              : const Color(0xFFD1FAE5),
                          iconColor: mint,
                          label: 'Send Feedback',
                          subtitle: 'Tell us what you think',
                          onTap: _sendFeedback,
                          cardColor: cardColor,
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 28),
                        _buildSectionLabel('Preferences',
                            color: sectionLabelColor),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? cardColor : _settingsCardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _settingsBlue.withValues(
                                  alpha: isDark ? 0.32 : 0.22),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _settingsBlue.withValues(
                                    alpha: isDark ? 0.45 : 0.32),
                                blurRadius: isDark ? 32 : 28,
                                spreadRadius: isDark ? 1.2 : 0.9,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('Notifications',
                                    style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: titleColor)),
                                subtitle: Text('Reminders and health alerts',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, color: subtitleColor)),
                                secondary: Container(
                                  width: 42,
                                  height: 42,
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(
                                        alpha: isDark ? 0.15 : 0.10),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Image.asset(
                                    'assets/icons/notification.png',
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                    color: accent,
                                    colorBlendMode: BlendMode.srcIn,
                                    errorBuilder: (_, __, ___) => Icon(
                                        Icons.notifications_outlined,
                                        color: accent,
                                        size: 20),
                                  ),
                                ),
                                value: _notificationsEnabled,
                                activeThumbColor: accent,
                                inactiveThumbColor: isDark
                                    ? ThemeService.textSecondary(isDark)
                                    : _darkBlue.withValues(alpha: 0.35),
                                inactiveTrackColor: isDark
                                    ? ThemeService.surfaceAlt(isDark)
                                    : _darkBlue.withValues(alpha: 0.14),
                                onChanged: (val) async {
                                  setState(() => _notificationsEnabled = val);
                                  await _notificationService
                                      .setNotificationsEnabled(val);
                                },
                              ),
                              Divider(color: dividerColor),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('Dark Mode',
                                    style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: titleColor)),
                                subtitle: Text('Switch app theme',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, color: subtitleColor)),
                                secondary: Container(
                                  width: 42,
                                  height: 42,
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: infoBlue.withValues(
                                        alpha: isDark ? 0.20 : 0.10),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Image.asset(
                                    isDark
                                        ? 'assets/icons/dark_mode.png'
                                        : 'assets/icons/day_mode.png',
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                    color: infoBlue,
                                    colorBlendMode: BlendMode.srcIn,
                                    errorBuilder: (_, __, ___) => Icon(
                                        isDark
                                            ? Icons.dark_mode
                                            : Icons.dark_mode_outlined,
                                        color: infoBlue,
                                        size: 20),
                                  ),
                                ),
                                value: themeNotifier.isDarkMode,
                                activeThumbColor: accent,
                                inactiveThumbColor: isDark
                                    ? ThemeService.textSecondary(isDark)
                                    : _darkBlue.withValues(alpha: 0.35),
                                inactiveTrackColor: isDark
                                    ? ThemeService.surfaceAlt(isDark)
                                    : _darkBlue.withValues(alpha: 0.14),
                                onChanged: (val) =>
                                    themeNotifier.toggleTheme(val),
                              ),
                            ],
                          ),
                        ),
                        if (isDark) ...[
                          const SizedBox(height: 28),
                          _buildSectionLabel('Appearance',
                              color: sectionLabelColor),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: dividerColor, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.05),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Dark Mode Colors',
                                    style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: titleColor)),
                                const SizedBox(height: 2),
                                Text('Pick the color scheme used in dark mode',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12, color: subtitleColor)),
                                const SizedBox(height: 14),
                                ...ThemeService.availableDarkPalettes.map((p) {
                                  final selected =
                                      themeNotifier.darkPalette == p;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _buildPaletteOption(
                                      palette: p,
                                      selected: selected,
                                      titleColor: titleColor,
                                      subtitleColor: subtitleColor,
                                      accent: accent,
                                      dividerColor: dividerColor,
                                      onTap: () =>
                                          themeNotifier.setDarkPalette(p),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        _buildSectionLabel('Danger Zone',
                            color: sectionLabelColor),
                        const SizedBox(height: 12),
                        _buildSettingsTile(
                          iconAsset: 'assets/icons/delete.png',
                          fallbackIcon: Icons.delete_outline_rounded,
                          iconBg: dangerSoft.withValues(
                              alpha: isDark ? 0.18 : 0.10),
                          iconColor: dangerSoft,
                          label: 'Delete Account',
                          subtitle: 'Permanently remove all data',
                          onTap: _deleteAccount,
                          labelColor: dangerSoft,
                          cardColor: cardColor,
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 28),
                        _buildSectionLabel('Contact Us',
                            color: sectionLabelColor),
                        const SizedBox(height: 12),
                        _buildSettingsTile(
                          iconAsset: 'assets/icons/instagram.png',
                          fallbackIcon: Icons.camera_alt_rounded,
                          iconBg: _instagramPink.withValues(
                              alpha: isDark ? 0.20 : 0.10),
                          iconColor: _instagramPink,
                          label: 'Follow us on Instagram',
                          subtitle: '@${ContactLinks.instagramUsername}',
                          onTap: () => ContactLinks.openInstagram(context),
                          cardColor: cardColor,
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 10),
                        _buildSettingsTile(
                          iconAsset: 'assets/icons/gmail.png',
                          fallbackIcon: Icons.mail_outline_rounded,
                          iconBg:
                              _gmailRed.withValues(alpha: isDark ? 0.20 : 0.10),
                          iconColor: _gmailRed,
                          label: 'Reach us on Gmail',
                          subtitle: ContactLinks.supportEmail,
                          onTap: () => ContactLinks.openGmail(context),
                          cardColor: cardColor,
                          titleColor: titleColor,
                          subtitleColor: subtitleColor,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 36),
                        Center(
                          child: Text(
                            'Mother N Baby SmartCare  ·  v1.0.0',
                            style: GoogleFonts.poppins(
                                fontSize: 12, color: subtitleColor),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionLabel(String label, {required Color color}) {
    return Text(label.toUpperCase(),
        style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 1.0));
  }

  Widget _buildPaletteOption({
    required AppDarkPalette palette,
    required bool selected,
    required Color titleColor,
    required Color subtitleColor,
    required Color accent,
    required Color dividerColor,
    required VoidCallback onTap,
  }) {
    final swatchBg = ThemeService.previewBgOf(palette);
    final swatchAccent = ThemeService.previewColorOf(palette);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : dividerColor,
            width: selected ? 1.5 : 1,
          ),
          color: selected ? accent.withValues(alpha: 0.08) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: swatchBg,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: dividerColor),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: swatchAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ThemeService.labelOf(palette),
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: titleColor)),
                  Text(ThemeService.descriptionOf(palette),
                      style: GoogleFonts.poppins(
                          fontSize: 11, color: subtitleColor)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: selected ? accent : dividerColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required String iconAsset,
    required IconData fallbackIcon,
    required Color iconBg,
    required Color iconColor,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    required Color cardColor,
    required Color titleColor,
    required Color subtitleColor,
    required bool isDark,
    Color? labelColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? cardColor : _settingsCardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _settingsBlue.withValues(alpha: isDark ? 0.32 : 0.22),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: _settingsBlue.withValues(alpha: isDark ? 0.42 : 0.30),
              blurRadius: isDark ? 30 : 26,
              spreadRadius: isDark ? 1.2 : 0.8,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(13)),
              child: Image.asset(
                iconAsset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                color: iconColor,
                colorBlendMode: BlendMode.srcIn,
                errorBuilder: (_, __, ___) =>
                    Icon(fallbackIcon, color: iconColor, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: labelColor ?? titleColor)),
                  Text(subtitle,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: subtitleColor)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: isDark
                    ? ThemeService.textSecondary(isDark)
                    : _darkBlue.withValues(alpha: 0.55),
                size: 22),
          ],
        ),
      ),
    );
  }
}
