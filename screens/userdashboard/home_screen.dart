import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../services/notification_watcher_mixin.dart';
import '../../widgets/notification_bell.dart';
import '../../services/feedback_reminder_service.dart';
import '../Notifications/notifications_screen.dart';
import '../Shop/shop_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, NotificationWatcherMixin {
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _userName = '';
  bool _isLoading = true;
  bool _drawerOpen = false;

  AnimationController? _drawerController;
  Animation<double>? _drawerAnim;

  static const Color _brandPink = Color(0xFFE91E8C);
  static const Color _mediumPink = Color(0xFFD6478E);
  static const Color _settingsIceBlue = Color(0xFF38BDF8);
  static const Color _babyPinkBg = Color(0xFFFFF1F6);

  @override
  void initState() {
    super.initState();
    _drawerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _drawerAnim = CurvedAnimation(
      parent: _drawerController!,
      curve: Curves.easeInOut,
    );
    _loadUserData();
    startWatchingNotifications();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeShowFeedbackReminder());
  }

  /// Zero-cost stand-in for a real push notification (no backend/FCM in
  /// this app — see FeedbackReminderService's doc comment): shows an
  /// automatic "Send Feedback" prompt the moment the app is opened, at
  /// most once every 7 days, with no button press needed to trigger it.
  Future<void> _maybeShowFeedbackReminder() async {
    final show = await FeedbackReminderService.shouldShow();
    if (!show || !mounted) return;
    await FeedbackReminderService.markShownNow();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('We\'d love your feedback!',
            style:
                GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
          'Tell us what you think, or let us know if something isn\'t '
          'working — it only takes a minute.',
          style: GoogleFonts.poppins(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Not now', style: GoogleFonts.poppins(fontSize: 13)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/my_feedback');
            },
            style: ElevatedButton.styleFrom(backgroundColor: _brandPink),
            child: Text('Send Feedback',
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _drawerController?.dispose();
    stopWatchingNotifications();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!mounted) return;
      if (doc.exists) {
        setState(() {
          _userName = doc['name'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _userName = _auth.currentUser?.displayName ??
              _auth.currentUser?.email?.split('@')[0] ??
              'User';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userName = _auth.currentUser?.email?.split('@')[0] ?? 'User';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshUserName() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!mounted) return;
      if (doc.exists) setState(() => _userName = doc['name'] ?? _userName);
    } catch (_) {}
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Good Morning';
    if (hour >= 12 && hour < 17) return 'Good Afternoon';
    if (hour >= 17 && hour < 19) return 'Good Evening';
    return 'Good Night';
  }

  static const Map<String, List<String>> _quotePool = {
    'morning': [
      'Start your day with care and love ',
      'Small steps today, big moments ahead ',
      'Every morning is a fresh chance to nurture ',
    ],
    'afternoon': [
      "You're doing amazing — keep going! ",
      "Take a breath — you're handling this beautifully ",
      'Your care makes all the difference today ',
    ],
    'evening': [
      "Enjoy your evening — you've earned it ",
      'Time to slow down and cherish these moments ',
      'A peaceful evening for you and your little one ',
    ],
    'night': [
      'Wonderful to have you here tonight ',
      'Rest well — tomorrow is full of new moments ',
      'Sweet dreams to you and your baby ',
    ],
  };

  String get _motivationalQuote {
    final now = DateTime.now();
    final hour = now.hour;
    String bucket;
    if (hour >= 5 && hour < 12) {
      bucket = 'morning';
    } else if (hour >= 12 && hour < 17) {
      bucket = 'afternoon';
    } else if (hour >= 17 && hour < 19) {
      bucket = 'evening';
    } else {
      bucket = 'night';
    }
    final quotes = _quotePool[bucket]!;
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    return quotes[dayOfYear % quotes.length];
  }

  void _toggleDrawer() {
    setState(() => _drawerOpen = !_drawerOpen);
    if (_drawerOpen) {
      _drawerController?.forward();
    } else {
      _drawerController?.reverse();
    }
  }

  void _closeDrawer() {
    if (_drawerOpen) {
      setState(() => _drawerOpen = false);
      _drawerController?.reverse();
    }
  }

  Future<void> _goToProfile() async {
    _closeDrawer();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    await Navigator.pushNamed(context, '/profile');
    if (mounted) await _refreshUserName();
  }

  Future<void> _goToSettings() async {
    _closeDrawer();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    Navigator.pushNamed(context, '/settings');
  }

  Future<void> _goToNotifications() async {
    _closeDrawer();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  Future<void> _goToShop() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ShopScreen()),
    );
  }

  Future<void> _logout() async {
    _closeDrawer();
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final isDark = context.read<ThemeNotifier>().isDarkMode;
    final surface = ThemeService.surface(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign out',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: textPrimary)),
        content: Text(
          'Are you sure you want to sign out?',
          style: GoogleFonts.poppins(fontSize: 14, color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('Sign out',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirm == true) {
      await _authService.logout();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _navigateToRoute(String route) {
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;

    final bgColor = isDark ? ThemeService.bg(isDark) : _babyPinkBg;
    final cardColor = ThemeService.surface(isDark);
    final borderColor = ThemeService.border(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final themeAccent = ThemeService.activeAccent(isDark);

    final identityColor = isDark ? themeAccent : _brandPink;

    final profileColor = _brandPink;
    final settingsColor = isDark ? themeAccent : _settingsIceBlue;
    final signOutColor = ThemeService.dangerSoft(isDark);

    final modules = [
      {
        'title': 'Mother Health\nTracker',
        'icon': 'assets/icons/woman.png',
        'color': _brandPink,
        'shadow': const Color(0xFFFF2D95),
        'light': const Color(0xFFFFE4F2),
        'route': '/mother_tracker',
      },
      {
        'title': 'Baby Health\nTracker',
        'icon': 'assets/icons/baby.png',
        'color': const Color(0xFF3B82F6),
        'shadow': const Color(0xFF4FC3FF),
        'light': const Color(0xFFE7EAFE),
        'route': '/baby_tracker',
      },
      {
        'title': 'Records &\nGraphs',
        'icon': 'assets/icons/records.png',
        'color': const Color(0xFF10B981),
        'shadow': const Color(0xFF00E676),
        'light': const Color(0xFFD1FAE5),
        'route': '/records',
      },
      {
        'title': 'Share PDF',
        'icon': 'assets/icons/onboarding4.png',
        'color': const Color.fromARGB(255, 251, 159, 0),
        'shadow': const Color(0xFFFFD400),
        'light': const Color(0xFFFEF3C7),
        'route': '/share_records',
      },
    ];

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          GestureDetector(
            onTap: _closeDrawer,
            child: AnimatedOpacity(
              opacity: _drawerOpen ? 0.35 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: AbsorbPointer(
                absorbing: _drawerOpen,
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(color: identityColor),
                      )
                    : SafeArea(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 12),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight - 24,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildTopBar(isDark, cardColor,
                                        identityColor, textPrimary),
                                    const SizedBox(height: 16),
                                    _buildCompactGreeting(),
                                    const SizedBox(height: 18),
                                    Text(
                                      'Health Modules',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        childAspectRatio: 0.92,
                                      ),
                                      itemCount: modules.length,
                                      itemBuilder: (context, index) {
                                        final m = modules[index];
                                        return _HoverableModuleCard(
                                          title: m['title'] as String,
                                          iconPath: m['icon'] as String,
                                          color: m['color'] as Color,
                                          shadowColor: m['shadow'] as Color?,
                                          lightColor: m['light'] as Color,
                                          cardColor: cardColor,
                                          borderColor: borderColor,
                                          isDark: isDark,
                                          onTap: () => _navigateToRoute(
                                              m['route'] as String),
                                        );
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    _HoverableShopBanner(onTap: _goToShop),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ),
          ),
          if (_drawerAnim != null)
            AnimatedBuilder(
              animation: _drawerAnim!,
              builder: (context, child) {
                final slide = _drawerAnim!.value;
                return Positioned(
                  top: 0,
                  right: slide > 0 ? 0 : -260,
                  bottom: 0,
                  width: 260,
                  child: slide > 0
                      ? ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(28),
                            bottomLeft: Radius.circular(28),
                          ),
                          child: child!,
                        )
                      : const SizedBox.shrink(),
                );
              },
              child: Material(
                elevation: 24,
                shadowColor: Colors.black.withValues(alpha: 0.35),
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: isDark
                        ? LinearGradient(
                            colors: [
                              ThemeService.surface(isDark),
                              ThemeService.surfaceAlt(isDark),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : const LinearGradient(
                            colors: [
                              Color(0xFFFFF3F8),
                              Color(0xFFF1F4FF),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Menu',
                                style: GoogleFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: identityColor,
                                ),
                              ),
                              GestureDetector(
                                onTap: _closeDrawer,
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color:
                                        identityColor.withValues(alpha: 0.14),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.close_rounded,
                                      size: 18, color: identityColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Divider(color: borderColor.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _HoverableDrawerItem(
                                    iconPath: 'assets/icons/profile.png',
                                    fallbackIcon: Icons.person_outline_rounded,
                                    accentColor: profileColor,
                                    isDark: isDark,
                                    label: 'Profile',
                                    onTap: _goToProfile,
                                  ),
                                  const SizedBox(height: 14),
                                  _HoverableDrawerItem(
                                    iconPath: 'assets/icons/settings.png',
                                    fallbackIcon: Icons.settings_outlined,
                                    accentColor: settingsColor,
                                    isDark: isDark,
                                    label: 'Settings',
                                    onTap: _goToSettings,
                                  ),
                                  const SizedBox(height: 22),
                                ],
                              ),
                            ),
                          ),
                          Divider(color: borderColor.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          _HoverableDrawerItem(
                            iconPath: 'assets/icons/logout.png',
                            fallbackIcon: Icons.logout_rounded,
                            accentColor: signOutColor,
                            isDark: isDark,
                            label: 'Sign out',
                            onTap: _logout,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar(
      bool isDark, Color cardColor, Color accent, Color textPrimary) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF2D95)
                    .withValues(alpha: isDark ? 0.55 : 0.40),
                blurRadius: isDark ? 20 : 14,
                spreadRadius: isDark ? 1.0 : 0.5,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Image.asset(
            'assets/icons/app_logo.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.favorite_rounded, color: accent, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('Mother And Baby',
                    maxLines: 1,
                    style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? textPrimary : _mediumPink,
                        height: 1.0,
                        letterSpacing: 0.2)),
              ),
              const SizedBox(height: 1),
              Text('SmartCare',
                  style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: accent,
                      letterSpacing: 1.4)),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isDark ? 0.46 : 0.28),
                blurRadius: isDark ? 20 : 13,
                spreadRadius: isDark ? 1.0 : 0.5,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: NotificationBell(onTap: _goToNotifications),
        ),
        const SizedBox(width: 8),
        _HoverableIconButton(
          onTap: _toggleDrawer,
          cardColor: cardColor,
          accentColor: accent,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildCompactGreeting() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7A2790), Color(0xFFD44FC2), Color(0xFFE91E8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B2FA0).withValues(alpha: 0.42),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _userName.isNotEmpty ? _userName : 'Welcome!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _motivationalQuote,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HoverableIconButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color cardColor;
  final Color accentColor;
  final bool isDark;
  const _HoverableIconButton({
    required this.onTap,
    required this.cardColor,
    required this.accentColor,
    required this.isDark,
  });

  @override
  State<_HoverableIconButton> createState() => _HoverableIconButtonState();
}

class _HoverableIconButtonState extends State<_HoverableIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _hover
                ? widget.accentColor.withValues(alpha: 0.16)
                : widget.cardColor,
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor
                    .withValues(alpha: widget.isDark ? 0.46 : 0.28),
                blurRadius: _hover ? 20 : 15,
                spreadRadius: widget.isDark ? 1.0 : 0.5,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _line(wide: true),
              const SizedBox(height: 4),
              _line(wide: false),
              const SizedBox(height: 4),
              _line(wide: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line({required bool wide}) => Container(
        width: wide ? 16 : 10,
        height: 2,
        decoration: BoxDecoration(
          color: widget.accentColor,
          borderRadius: BorderRadius.circular(2),
        ),
      );
}

class _HoverableModuleCard extends StatefulWidget {
  final String title;
  final String iconPath;
  final Color color;

  final Color? shadowColor;
  final Color lightColor;
  final Color cardColor;
  final Color borderColor;
  final bool isDark;
  final VoidCallback onTap;

  const _HoverableModuleCard({
    required this.title,
    required this.iconPath,
    required this.color,
    this.shadowColor,
    required this.lightColor,
    required this.cardColor,
    required this.borderColor,
    required this.isDark,
    required this.onTap,
  });

  Color get _shadow => shadowColor ?? color;

  @override
  State<_HoverableModuleCard> createState() => _HoverableModuleCardState();
}

class _HoverableModuleCardState extends State<_HoverableModuleCard> {
  bool _hover = false;
  bool _pressed = false;
  bool _opening = false;

  bool get _active => _hover || _pressed || _opening;

  Future<void> _handleTap() async {
    setState(() {
      _pressed = false;
      _opening = true;
    });
    await Future.delayed(const Duration(milliseconds: 190));
    if (!mounted) return;
    widget.onTap();
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) setState(() => _opening = false);
  }

  Color get _restCardColor =>
      widget.isDark ? widget.cardColor : widget.cardColor;

  Color get _activeCardColor => widget.isDark
      ? ThemeService.darkTintedChip(widget.color, amount: 0.16)
      : widget.lightColor;

  Color get _iconChipColor => widget.isDark
      ? ThemeService.darkTintedChip(widget.color, amount: 0.26)
      : Colors.white;

  @override
  Widget build(BuildContext context) {
    final scale = _opening
        ? 1.10
        : _pressed
            ? 0.96
            : (_hover ? 1.0 : 1.0);

    final restAlpha = widget.isDark ? 0.62 : 0.44;
    final activeAlpha = _opening ? 0.85 : 0.72;
    final restBlur = widget.isDark ? 34.0 : 28.0;
    final restSpread = widget.isDark ? 2.6 : 2.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => _handleTap(),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: Duration(milliseconds: _opening ? 190 : 150),
          curve: _opening ? Curves.easeOutBack : Curves.easeOut,
          transform: Matrix4.identity()
            ..scaleByDouble(scale, scale, 1.0, 1.0)
            ..translateByDouble(
                0.0, _hover && !_pressed && !_opening ? -3.0 : 0.0, 0.0, 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: _active ? _activeCardColor : _restCardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: widget._shadow
                    .withValues(alpha: _active ? activeAlpha : restAlpha),
                blurRadius: _opening ? 44 : (_active ? 36 : restBlur),
                offset: _active ? const Offset(0, 12) : const Offset(0, 8),
                spreadRadius: _opening ? 4 : (_active ? 3 : restSpread),
              ),
            ],
            border: Border.all(
              color: _active
                  ? widget.color.withValues(alpha: 0.4)
                  : (widget.isDark
                      ? widget.color.withValues(alpha: 0.26)
                      : widget.borderColor),
              width: 1.4,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: LayoutBuilder(
              builder: (context, innerConstraints) {
                final availW = innerConstraints.maxWidth.isFinite
                    ? innerConstraints.maxWidth
                    : 160.0;
                final baseIcon = (availW * 0.62).clamp(56.0, 108.0);
                final iconSize = _active ? baseIcon * 1.06 : baseIcon;
                final fontSize = (availW * 0.105).clamp(11.0, 15.5);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: iconSize,
                      height: iconSize,
                      padding: EdgeInsets.all(iconSize * 0.17),
                      decoration: BoxDecoration(
                        color: _iconChipColor,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: widget._shadow
                                .withValues(alpha: widget.isDark ? 0.46 : 0.48),
                            blurRadius: 18,
                            offset: const Offset(0, 5),
                            spreadRadius: 1,
                          ),
                        ],
                        border: Border.all(
                          color: widget.color
                              .withValues(alpha: widget.isDark ? 0.30 : 0.16),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          widget.iconPath,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.health_and_safety_rounded,
                            color: widget.color,
                            size: iconSize * 0.44,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark
                            ? ThemeService.textPrimary(true)
                            : widget.color,
                        height: 1.3,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverableShopBanner extends StatefulWidget {
  final VoidCallback onTap;
  const _HoverableShopBanner({required this.onTap});

  @override
  State<_HoverableShopBanner> createState() => _HoverableShopBannerState();
}

class _HoverableShopBannerState extends State<_HoverableShopBanner> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: double.infinity,
          height: 172,
          transform: Matrix4.identity()
            ..translateByDouble(0.0, _hover ? -3.0 : 0.0, 0.0, 1.0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF7A2790), Color(0xFFD44FC2), Color(0xFFE91E8C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B2FA0)
                    .withValues(alpha: _hover ? 0.50 : 0.36),
                blurRadius: _hover ? 28 : 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                Positioned(
                  right: -30,
                  top: -30,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  left: -20,
                  bottom: -36,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            width: _hover ? 52 : 48,
                            height: _hover ? 52 : 48,
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Image.asset(
                              'assets/icons/shopping-bag.png',
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.shopping_bag_rounded,
                                  color: Color(0xFF8B2FA0),
                                  size: 24),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('NEW',
                                style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.5)),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Mother And Baby Shop',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          const SizedBox(height: 2),
                          Text('Handpicked essentials for every stage',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  color: Colors.white.withValues(alpha: 0.85))),
                        ],
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: double.infinity,
                        padding:
                            EdgeInsets.symmetric(vertical: _hover ? 11 : 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Browse the shop',
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF8B2FA0))),
                            const SizedBox(width: 6),
                            const Icon(Icons.arrow_forward_rounded,
                                size: 15, color: Color(0xFF8B2FA0)),
                          ],
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
  }
}

class _HoverableDrawerItem extends StatefulWidget {
  final String iconPath;
  final IconData fallbackIcon;
  final Color accentColor;
  final bool isDark;
  final String label;
  final VoidCallback onTap;

  const _HoverableDrawerItem({
    required this.iconPath,
    required this.fallbackIcon,
    required this.accentColor,
    this.isDark = false,
    required this.label,
    required this.onTap,
  });

  @override
  State<_HoverableDrawerItem> createState() => _HoverableDrawerItemState();
}

class _HoverableDrawerItemState extends State<_HoverableDrawerItem> {
  bool _hover = false;
  bool _pressed = false;

  bool get _active => _hover || _pressed;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.96 : (_hover ? 1.03 : 1.0);
    final accent = widget.accentColor;

    final fillColor = widget.isDark
        ? Color.alphaBlend(
            accent.withValues(alpha: _active ? 0.16 : 0.10),
            ThemeService.darkSurfaceAlt,
          )
        : accent.withValues(alpha: _active ? 0.16 : 0.10);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          transform: Matrix4.identity()
            ..scaleByDouble(scale, scale, 1.0, 1.0)
            ..translateByDouble(
                0.0, _hover && !_pressed ? -3.0 : 0.0, 0.0, 1.0),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent.withValues(alpha: _active ? 0.65 : 0.38),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: _active ? 0.58 : 0.34),
                blurRadius: _active ? 30 : 18,
                offset: const Offset(0, 5),
                spreadRadius: _active ? 4 : 1,
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: _active ? 42 : 38,
                height: _active ? 42 : 38,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? ThemeService.darkTintedChip(accent, amount: 0.28)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: _active ? 0.55 : 0.38),
                      blurRadius: _active ? 18 : 12,
                      offset: const Offset(0, 3),
                      spreadRadius: _active ? 1.2 : 0.3,
                    ),
                  ],
                  border: Border.all(
                    color: accent.withValues(
                        alpha: _active ? 0.32 : (widget.isDark ? 0.28 : 0.16)),
                    width: 1,
                  ),
                ),
                child: Image.asset(
                  widget.iconPath,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, __, ___) => Icon(
                    widget.fallbackIcon,
                    color: accent,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: accent.withValues(alpha: _active ? 0.9 : 0.5),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
