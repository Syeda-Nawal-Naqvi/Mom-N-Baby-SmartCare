import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../services/admin_service.dart';
import '../../services/local_notification_service.dart';
import '../../services/app_notification_service.dart';
import '../../services/notification_sound_service.dart';
import '../../services/firebase_service.dart';
import '../../services/cache_service.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'need_help_screen.dart';
import 'verify_email_screen.dart';
import 'set_password_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/feedback_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  // ═════════════════════════════════════════════════════════════════
  // OFFLINE-SAFE "BLOCKED ACCOUNT" FEEDBACK DRAFT
  // ═════════════════════════════════════════════════════════════════
  //
  // Why this needs special handling (unlike the rest of the app's data,
  // e.g. weight/BP/glucose records): submitting this feedback requires
  // FIRST signing in as the blocked user (so Firestore rules can attach
  // it to their uid). Firebase Auth's sign-in is a live network
  // handshake — unlike a normal Firestore write, it CANNOT be queued
  // locally by Firestore's offline cache and replayed later. So if the
  // device is offline, we can't silently queue "send feedback" the way
  // Firestore already does for e.g. AppRecordStreamList's "Syncing…"
  // writes elsewhere in the app.
  //
  // What we do instead, mirroring CacheService's existing
  // save-while-online / load-while-offline pattern:
  //   - Cache ONLY the email + message text (via CacheService.saveMap),
  //     never the password — auto-replaying a stored password in the
  //     background is a security anti-pattern, so the person must
  //     re-enter it once to actually send.
  //   - Watch FirestoreService.isOnline (already initialized in main())
  //     instead of creating a second, redundant connectivity listener.
  //   - When connectivity returns and a draft exists, prompt with a
  //     "Send now" action — same UX pattern as WhatsApp/email drafts.
  static const String _pendingFeedbackKey = 'blockedFeedbackDraft';
  Map<String, dynamic>? _pendingFeedback;

  @override
  void initState() {
    super.initState();
    _loadPendingFeedback();
    FirestoreService.isOnline.addListener(_onConnectivityChanged);
  }

  Future<void> _loadPendingFeedback() async {
    final data = await CacheService.loadMap(_pendingFeedbackKey);
    if (data == null || !mounted) return;
    setState(() => _pendingFeedback = data);
    if (FirestoreService.isOnline.value) _showPendingFeedbackReminder();
  }

  void _onConnectivityChanged() {
    if (FirestoreService.isOnline.value &&
        _pendingFeedback != null &&
        mounted) {
      _showPendingFeedbackReminder();
    }
  }

  void _showPendingFeedbackReminder() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "You're back online — you have an unsent feedback message.",
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF3B82F6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Send now',
          textColor: Colors.white,
          onPressed: () =>
              _showBlockedFeedbackDialog(prefill: _pendingFeedback),
        ),
      ),
    );
  }

  Future<void> _showBlockedFeedbackDialog({
    Map<String, dynamic>? prefill,
  }) async {
    final controller =
        TextEditingController(text: prefill?['message']?.toString() ?? '');
    final sent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Feedback to Admin'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Tell us why you think your account was blocked...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (sent != true || controller.text.trim().isEmpty) return;

    final email = (prefill?['email'] as String?) ?? _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim().toLowerCase();
    final message = controller.text.trim();

    // Sign-in needs a live round-trip — check connectivity up front
    // instead of letting the sign-in call fail with a confusing error.
    if (!FirestoreService.isOnline.value) {
      await CacheService.saveMap(_pendingFeedbackKey, {
        'email': email,
        'message': message,
        'savedAt': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      setState(() => _pendingFeedback = {'email': email, 'message': message});
      _showToast(
        "You're offline. Your message has been saved — we'll remind you "
        "to send it once you're back online.",
        isSuccess: true,
      );
      return;
    }

    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final error = await FeedbackService().submitFeedback(
        '[Blocked account] $message',
      );
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      if (error == null) {
        await CacheService.clear(_pendingFeedbackKey);
        setState(() => _pendingFeedback = null);
      }
      _showToast(
        error ?? 'Feedback sent. Admin will review your account.',
        isSuccess: error == null,
      );
    } catch (e) {
      // Connectivity may have dropped mid-flight even though isOnline
      // said true a moment ago — keep the draft so the banner can
      // prompt a retry once the connection is confirmed back.
      final msg = e.toString().toLowerCase();
      final looksLikeNetworkIssue = msg.contains('network') ||
          msg.contains('timeout') ||
          msg.contains('unavailable');
      if (looksLikeNetworkIssue) {
        await CacheService.saveMap(_pendingFeedbackKey, {
          'email': email,
          'message': message,
          'savedAt': DateTime.now().toIso8601String(),
        });
        if (mounted) {
          setState(
              () => _pendingFeedback = {'email': email, 'message': message});
        }
      }
      if (!mounted) return;
      _showToast('Could not send feedback. Please try again.',
          isSuccess: false);
    }
  }

  static const List<Color> _brandGradient = [
    Color(0xFF7A2790),
    Color(0xFFD44FC2),
    Color(0xFFE91E8C),
  ];
  static const Color _accent = Color(0xFFE91E8C);
  static const Color _accentDeep = Color(0xFF7A2790);
  static const Color _headingColor = Color(0xFF6A1B9A);
  static const Color _labelColor = Color(0xFF9C27B0);
  static const Color _inputTextColor = Color(0xFF3D1259);

  static const String _iconEmail = 'assets/icons/email.png';
  static const String _iconLock = 'assets/icons/lock.png';
  static const String _iconEyeOpen = 'assets/icons/eye_open.png';
  static const String _iconEyeOff = 'assets/icons/eye_off.png';

  static const String _noSpaceHelper =
      'Use letters, numbers, and symbols (- _ !) — no spaces.';

  @override
  void dispose() {
    FirestoreService.isOnline.removeListener(_onConnectivityChanged);
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _showToast(String message, {required bool isSuccess}) {
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
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor:
            isSuccess ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _navigateByRole(String role) {
    LocalNotificationService().requestPermission();

    AppNotificationService().hasUnreadNotifications().then((hasUnread) {
      if (hasUnread) NotificationSoundService().playPopIfEnabled();
    });

    if (role == 'admin') {
      AdminService().ensureAdminDirectoryEntry();
      Navigator.pushReplacementNamed(context, '/admin_dashboard');
    } else {
      Navigator.pushReplacementNamed(context, '/dashboard');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final error = await _authService.login(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text.trim().toLowerCase(),
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _errorMessage = error;
        _isLoading = false;
      });
      return;
    }

    final isVerified = await _authService.checkEmailVerified();
    if (!mounted) return;

    if (!isVerified) {
      setState(() => _isLoading = false);
      _showToast('Please verify your email first.', isSuccess: false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
      );
      return;
    }

    final role = await _authService.getUserRole(_authService.currentUser!.uid);
    if (!mounted) return;

    setState(() => _isLoading = false);
    _showToast('Login successful! Welcome back ', isSuccess: true);
    _navigateByRole(role);
  }

  Future<void> _googleLogin() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });
    _showToast('Opening Google Sign-In…', isSuccess: true);

    final result = await _authService.signInWithGoogle();
    if (!mounted) return;

    if (result['error'] != null) {
      setState(() {
        _errorMessage = result['error'];
        _isGoogleLoading = false;
      });
      return;
    }

    setState(() => _isGoogleLoading = false);

    if (result['isNewUser'] == true) {
      _showToast('Welcome! Account created with Google ', isSuccess: true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SetPasswordScreen(role: result['role']),
        ),
      );
      return;
    }

    if (result['securityNotice'] == true) {
      _showToast(
        'For your security we sent a password reset link to your email — '
        'any old password on this account no longer works.',
        isSuccess: true,
      );
    } else {
      _showToast('Google login successful! ', isSuccess: true);
    }
    _navigateByRole(result['role']);
  }

  Widget _assetIcon(
    String assetPath, {
    Color? color,
    IconData fallback = Icons.circle_outlined,
    double size = 20,
  }) {
    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      color: color,
      errorBuilder: (_, __, ___) =>
          Icon(fallback, color: color ?? _accent, size: size),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    Widget? prefixIcon,
    Widget? suffix,
    String? helperText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade400),
      prefixIcon: Padding(
        padding: const EdgeInsets.all(14),
        child: prefixIcon,
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      helperText: helperText,
      helperMaxLines: 2,
      helperStyle: GoogleFonts.poppins(
          fontSize: 10.5, color: _labelColor.withValues(alpha: 0.75)),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _accent.withValues(alpha: 0.22))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _accent, width: 1.8)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade300)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5)),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: GoogleFonts.poppins(
            fontSize: 12.5, fontWeight: FontWeight.w600, color: _labelColor));
  }

  Widget _fieldShadowWrap(Widget child) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: _accent,
          selectionColor: _accent.withValues(alpha: 0.25),
          selectionHandleColor: _accent,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFFFF0F5),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight -
                        MediaQuery.of(context).padding.top -
                        32,
                  ),
                  child: IntrinsicHeight(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                const _AuthLogoMark(
                                  assetPath: 'assets/icons/app_logo.png',
                                  gradientColors: _brandGradient,
                                  size: 92,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Welcome Back!',
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: _headingColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Sign in to your account',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13.5,
                                      color: _headingColor.withValues(
                                          alpha: 0.55)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          if (_pendingFeedback != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.cloud_off_rounded,
                                      color: Colors.blue.shade400, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'You have an unsent feedback message '
                                      'saved on this device.',
                                      style: GoogleFonts.poppins(
                                          fontSize: 12.5,
                                          color: Colors.blue.shade700),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _showBlockedFeedbackDialog(
                                    prefill: _pendingFeedback),
                                icon: const Icon(Icons.send_rounded, size: 16),
                                label: const Text('Send now'),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline_rounded,
                                      color: Colors.red.shade400, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: GoogleFonts.poppins(
                                          fontSize: 12.5,
                                          color: Colors.red.shade700),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _errorMessage = null),
                                    child: Icon(Icons.close,
                                        color: Colors.red.shade300, size: 18),
                                  ),
                                ],
                              ),
                            ),
                            if (_errorMessage!
                                .toLowerCase()
                                .contains('blocked'))
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => _showBlockedFeedbackDialog(),
                                  icon: const Icon(Icons.feedback_outlined,
                                      size: 16),
                                  label: const Text('Need help? Send Feedback'),
                                ),
                              ),
                            const SizedBox(height: 16),
                          ],
                          _buildLabel('Email Address'),
                          const SizedBox(height: 6),
                          _fieldShadowWrap(
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              cursorColor: _accent,
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              ],
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: _inputTextColor,
                                  fontWeight: FontWeight.w500),
                              decoration: _inputDecoration(
                                hint: 'Enter your email',
                                prefixIcon: _assetIcon(
                                  _iconEmail,
                                  color: _accent,
                                  fallback: Icons.mail_outline_rounded,
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$')
                                    .hasMatch(v.trim())) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildLabel('Password'),
                          const SizedBox(height: 6),
                          _fieldShadowWrap(
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              cursorColor: _accent,
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              ],
                              style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: _inputTextColor,
                                  fontWeight: FontWeight.w500),
                              decoration: _inputDecoration(
                                hint: 'Enter your password',
                                helperText: _noSpaceHelper,
                                prefixIcon: _assetIcon(
                                  _iconLock,
                                  color: _accent,
                                  fallback: Icons.lock_outline_rounded,
                                ),
                                suffix: IconButton(
                                  icon: _assetIcon(
                                    _obscurePassword
                                        ? _iconEyeOff
                                        : _iconEyeOpen,
                                    color: _accent.withValues(alpha: 0.7),
                                    fallback: _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Password is required';
                                }
                                if (v.contains(' ')) {
                                  return "Spaces aren't allowed. Use letters, numbers, or symbols like - _ instead.";
                                }
                                if (v.length < 6) {
                                  return 'Minimum 6 characters required';
                                }
                                return null;
                              },
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 32),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const NeedHelpScreen()),
                                ),
                                child: Text(
                                  'Need Help?',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      color:
                                          _accentDeep.withValues(alpha: 0.75),
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 32),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const ForgotPasswordScreen()),
                                ),
                                child: Text(
                                  'Forgot Password?',
                                  style: GoogleFonts.poppins(
                                      fontSize: 12.5,
                                      color: _accentDeep,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _AuthGradientButton(
                            label: 'Sign In',
                            isLoading: _isLoading,
                            onPressed: _isLoading ? null : _login,
                            gradientColors: _brandGradient,
                            glowColor: _accent,
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                  child: Divider(
                                      color: _accent.withValues(alpha: 0.18))),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text('OR',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color:
                                            _accentDeep.withValues(alpha: 0.55),
                                        fontWeight: FontWeight.w600)),
                              ),
                              Expanded(
                                  child: Divider(
                                      color: _accent.withValues(alpha: 0.18))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _AuthOutlineButton(
                            accent: _accent,
                            onPressed: _isGoogleLoading ? null : _googleLogin,
                            child: _isGoogleLoading
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        color: _accent, strokeWidth: 2.5),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset('assets/icons/google.png',
                                          width: 20, height: 20),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Continue with Google',
                                        style: GoogleFonts.poppins(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w600,
                                            color: _headingColor),
                                      ),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 26),
                          Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text("Don't have an account? ",
                                    style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: _headingColor.withValues(
                                            alpha: 0.6))),
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const RegisterScreen()),
                                  ),
                                  child: Text(
                                    'Sign Up',
                                    style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _accent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AuthLogoMark extends StatelessWidget {
  final String assetPath;
  final List<Color> gradientColors;
  final double size;

  const _AuthLogoMark({
    required this.assetPath,
    required this.gradientColors,
    this.size = 92,
  });

  @override
  Widget build(BuildContext context) {
    final borderWidth = size * 0.045;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors.last.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        padding: EdgeInsets.all(size * 0.16),
        child: ClipOval(
          child: Image.asset(assetPath, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _AuthGradientButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final List<Color> gradientColors;
  final Color glowColor;

  const _AuthGradientButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    required this.gradientColors,
    required this.glowColor,
  });

  @override
  State<_AuthGradientButton> createState() => _AuthGradientButtonState();
}

class _AuthGradientButtonState extends State<_AuthGradientButton> {
  bool _hover = false;
  bool _pressed = false;

  bool get _active => _hover || _pressed;
  bool get _disabled => widget.onPressed == null;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.97 : (_hover ? 1.02 : 1.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: _disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: _disabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: _disabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: _disabled ? null : () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..scaleByDouble(scale, scale, 1.0, 1.0),
          transformAlignment: Alignment.center,
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _disabled
                  ? widget.gradientColors
                      .map((c) => c.withValues(alpha: 0.45))
                      .toList()
                  : widget.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _disabled
                ? []
                : [
                    BoxShadow(
                      color: widget.glowColor
                          .withValues(alpha: _active ? 0.55 : 0.35),
                      blurRadius: _active ? 26 : 18,
                      offset: const Offset(0, 8),
                      spreadRadius: _active ? 1.5 : 0.5,
                    ),
                  ],
          ),
          alignment: Alignment.center,
          child: widget.isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  widget.label,
                  style: GoogleFonts.poppins(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
        ),
      ),
    );
  }
}

class _AuthOutlineButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color accent;

  const _AuthOutlineButton({
    required this.child,
    required this.onPressed,
    required this.accent,
  });

  @override
  State<_AuthOutlineButton> createState() => _AuthOutlineButtonState();
}

class _AuthOutlineButtonState extends State<_AuthOutlineButton> {
  bool _hover = false;
  bool _pressed = false;

  bool get _active => _hover || _pressed;
  bool get _disabled => widget.onPressed == null;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.97 : (_hover ? 1.015 : 1.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: _disabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: _disabled ? null : (_) => setState(() => _pressed = true),
        onTapUp: _disabled ? null : (_) => setState(() => _pressed = false),
        onTapCancel: _disabled ? null : () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.identity()..scaleByDouble(scale, scale, 1.0, 1.0),
          transformAlignment: Alignment.center,
          width: double.infinity,
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.accent.withValues(alpha: _active ? 0.55 : 0.28),
              width: 1.6,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: _active ? 0.22 : 0.10),
                blurRadius: _active ? 20 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}
