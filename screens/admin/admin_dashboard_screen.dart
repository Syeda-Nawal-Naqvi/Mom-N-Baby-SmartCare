import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/admin_service.dart';
import '../../services/admin_intro_banner_service.dart';
import '../../services/app_notification_service.dart';
import '../../services/notification_watcher_mixin.dart';
import '../../services/admin_feedback_watcher_mixin.dart';
import '../../services/theme_service.dart';
import 'admin_users_screen.dart';
import 'admin_feedback_screen.dart';
import 'admin_send_notification_screen.dart';
import 'admin_mothers_screen.dart';
import 'admin_babies_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_profile_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_shop_screen.dart';
import 'admin_help_requests_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with NotificationWatcherMixin, AdminFeedbackWatcherMixin {
  final AdminService _adminService = AdminService();
  final AppNotificationService _notifService = AppNotificationService();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _adminName = '';
  Map<String, int> _analytics = const {};
  bool _loading = true;
  String? _loadError;
  bool _showAccountsBanner = false;

  @override
  void initState() {
    super.initState();
    _adminService.startLiveAnalytics();
    _adminService.liveAnalytics.addListener(_onAnalyticsChanged);
    _adminService.ensureAdminDirectoryEntry();
    startWatchingNotifications();
    startWatchingFeedback();
    _load();
    _checkAccountsBanner();
  }

  Future<void> _checkAccountsBanner() async {
    final show = await AdminIntroBannerService.shouldShow();
    if (!mounted) return;
    setState(() => _showAccountsBanner = show);
  }

  void _dismissAccountsBanner() {
    setState(() => _showAccountsBanner = false);
    AdminIntroBannerService.markDismissed();
  }

  @override
  void dispose() {
    _adminService.liveAnalytics.removeListener(_onAnalyticsChanged);
    _adminService.stopLiveAnalytics();
    stopWatchingNotifications();
    stopWatchingFeedback();
    super.dispose();
  }

  void _onAnalyticsChanged() {
    if (mounted) {
      setState(() {
        _analytics = Map<String, int>.from(
          _adminService.liveAnalytics.value,
        );
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;

      if (uid != null) {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();

        if (doc.exists) {
          _adminName = doc.data()?['name'] ?? 'Admin';
        }
      }

      final analytics = await _adminService.getAnalytics();

      if (!mounted) return;

      setState(() {
        _analytics = analytics;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadError = e.toString();
        _analytics = const {
          'totalUsers': 0,
          'activeUsers': 0,
          'blockedUsers': 0,
          'admins': 0,
          'mothers': 0,
          'fathers': 0,
          'caretakers': 0,
          'pendingFeedback': 0,
          'totalMothers': 0,
          'totalBabies': 0,
        };
        _loading = false;
      });
    }
  }

  Future<void> _goToAdminSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminSettingsScreen(),
      ),
    );

    if (mounted) _load();
  }

  Future<void> _goToAdminProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AdminProfileScreen(),
      ),
    );

    if (mounted) _load();
  }

  Future<void> _runCleanupOrphans(AppThemeColors theme) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Clean up orphaned data?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: theme.textPrimary,
          ),
        ),
        content: Text(
          'This permanently deletes any baby profile, mother profile, '
          'health record, notification, or feedback entry left behind by '
          'a user account that no longer exists. This only affects data '
          'that already has no owner — it cannot be undone, but it will '
          'not touch any current user\'s data.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: theme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: theme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accent,
            ),
            child: Text(
              'Clean up',
              style: GoogleFonts.poppins(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: CircularProgressIndicator(
          color: theme.accent,
        ),
      ),
    );

    try {
      final removed = await _adminService.cleanupOrphans();

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            removed == 0
                ? 'No orphaned data found — everything is clean.'
                : 'Removed $removed orphaned record${removed == 1 ? '' : 's'}.',
          ),
        ),
      );

      _load();
    } catch (e) {
      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cleanup failed: $e'),
        ),
      );
    }
  }

  void _goToUsers({String? roleFilter}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminUsersScreen(
          initialRoleFilter: roleFilter,
        ),
      ),
    );
  }

  int _crossAxisCountFor(double width) {
    if (width >= 1000) return 4;
    if (width >= 640) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: theme.bg,
          appBar: AppBar(
            backgroundColor: theme.surface,
            elevation: 0,
            automaticallyImplyLeading: false,
            title: Text(
              'Admin Panel',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary,
              ),
            ),
            actions: [
              StreamBuilder<int>(
                stream: _notifService.streamUnreadCount(),
                builder: (context, snapshot) {
                  final count = snapshot.data ?? 0;

                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_outlined,
                          color: Color(0xFFF5B301),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminNotificationsScreen(),
                          ),
                        ),
                      ),
                      if (count > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              count > 9 ? '9+' : '$count',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              _HamburgerButton(
                accentColor: theme.accent,
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              const SizedBox(width: 8),
            ],
          ),
          drawer: _buildDrawer(context, theme),
          body: _loading
              ? Center(
                  child: CircularProgressIndicator(
                    color: theme.accent,
                  ),
                )
              : (_loadError != null)
                  ? RefreshIndicator(
                      onRefresh: _load,
                      color: theme.accent,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: Colors.red.shade400,
                            size: 56,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Admin dashboard couldn\'t load',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: theme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _loadError!,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: theme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _load,
                              icon: const Icon(
                                Icons.refresh_rounded,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.accent,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              label: Text(
                                'Retry',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: theme.accent,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${_adminName.isNotEmpty ? _adminName : "Admin"} 👋',
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: theme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Here\'s what\'s happening in your app',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: theme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'Accounts',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: theme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_showAccountsBanner) ...[
                              _InfoBanner(
                                theme: theme,
                                text: 'Every registered user, grouped by role. '
                                    'Tap a card to see that group\'s full '
                                    'list.',
                                onDismiss: _dismissAccountsBanner,
                              ),
                              const SizedBox(height: 12),
                            ],
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final cols = _crossAxisCountFor(
                                  constraints.maxWidth,
                                );

                                return GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: cols,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                  childAspectRatio: 1.05,
                                  children: [
                                    _statCard(
                                      theme,
                                      'Total Users',
                                      '${_analytics['totalUsers'] ?? 0}',
                                      Icons.people_alt_rounded,
                                      const Color(0xFF3B82F6),
                                      onTap: () => _goToUsers(),
                                    ),
                                    _statCard(
                                      theme,
                                      'Active Users',
                                      '${_analytics['activeUsers'] ?? 0}',
                                      Icons.person_rounded,
                                      const Color(0xFF10B981),
                                      onTap: () => _goToUsers(),
                                    ),
                                    _statCard(
                                      theme,
                                      'Blocked Users',
                                      '${_analytics['blockedUsers'] ?? 0}',
                                      Icons.block_rounded,
                                      Colors.red.shade400,
                                      onTap: () => _goToUsers(),
                                    ),
                                    _statCard(
                                      theme,
                                      'Admins',
                                      '${_analytics['admins'] ?? 0}',
                                      Icons.admin_panel_settings_rounded,
                                      const Color(0xFF8B5CF6),
                                      onTap: () => _goToUsers(
                                        roleFilter: 'admin',
                                      ),
                                    ),
                                    _statCard(
                                      theme,
                                      'Mother Accounts',
                                      '${_analytics['mothers'] ?? 0}',
                                      Icons.pregnant_woman_rounded,
                                      const Color(0xFFEC4899),
                                      iconAsset: 'assets/icons/woman.png',
                                      onTap: () => _goToUsers(
                                        roleFilter: 'mother',
                                      ),
                                    ),

                                    // UPDATED FATHER ICON
                                    _statCard(
                                      theme,
                                      'Father Accounts',
                                      '${_analytics['fathers'] ?? 0}',
                                      Icons.man_rounded,
                                      const Color(0xFF3B82F6),
                                      iconAsset: 'assets/icons/father.png',
                                      onTap: () => _goToUsers(
                                        roleFilter: 'father',
                                      ),
                                    ),

                                    // UPDATED CARETAKER ICON
                                    _statCard(
                                      theme,
                                      'Caretaker Accounts',
                                      '${_analytics['caretakers'] ?? 0}',
                                      Icons.volunteer_activism_rounded,
                                      const Color(0xFFF59E0B),
                                      iconAsset: 'assets/icons/caretaker.png',
                                      onTap: () => _goToUsers(
                                        roleFilter: 'caretaker',
                                      ),
                                    ),

                                    _statCard(
                                      theme,
                                      'Pending Feedback',
                                      '${_analytics['pendingFeedback'] ?? 0}',
                                      Icons.feedback_rounded,
                                      const Color(0xFFF59E0B),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const AdminFeedbackScreen(),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 26),
                            Text(
                              'Health Records',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: theme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final cols = _crossAxisCountFor(
                                  constraints.maxWidth,
                                );

                                return GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: cols,
                                  crossAxisSpacing: 14,
                                  mainAxisSpacing: 14,
                                  childAspectRatio: 1.05,
                                  children: [
                                    _statCard(
                                      theme,
                                      'Mother Health Profiles',
                                      '${_analytics['totalMothers'] ?? 0}',
                                      Icons.assignment_ind_rounded,
                                      const Color(0xFFEC4899),
                                      iconAsset: 'assets/icons/woman.png',
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const AdminMothersScreen(),
                                        ),
                                      ),
                                    ),
                                    _statCard(
                                      theme,
                                      'Baby Profiles',
                                      '${_analytics['totalBabies'] ?? 0}',
                                      Icons.child_care_rounded,
                                      const Color(0xFF06B6D4),
                                      iconAsset: 'assets/icons/baby.png',
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const AdminBabiesScreen(),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'Quick Actions',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _actionTile(
                              theme,
                              icon: Icons.people_alt_rounded,
                              color: const Color(0xFF3B82F6),
                              label: 'Manage Users',
                              subtitle: 'Block, promote, or remove users',
                              onTap: () => _goToUsers(),
                            ),
                            const SizedBox(height: 10),
                            _actionTile(
                              theme,
                              icon: Icons.pregnant_woman_rounded,
                              iconAsset: 'assets/icons/woman.png',
                              color: const Color(0xFFEC4899),
                              label: 'Mother Profiles',
                              subtitle: 'View or delete mother health profiles',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AdminMothersScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _actionTile(
                              theme,
                              icon: Icons.child_care_rounded,
                              iconAsset: 'assets/icons/baby.png',
                              color: const Color(0xFF06B6D4),
                              label: 'Baby Profiles',
                              subtitle:
                                  'View-only — babies belong to the family',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AdminBabiesScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _actionTile(
                              theme,
                              icon: Icons.cleaning_services_rounded,
                              color: const Color(0xFF64748B),
                              label: 'Clean Up Orphaned Data',
                              subtitle:
                                  'Remove leftover records from deleted users',
                              onTap: () => _runCleanupOrphans(theme),
                            ),
                            const SizedBox(height: 10),
                            _actionTile(
                              theme,
                              icon: Icons.feedback_rounded,
                              color: const Color(0xFF10B981),
                              label: 'Feedback Management',
                              subtitle: 'View, reply to, or delete feedback',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AdminFeedbackScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _actionTile(
                              theme,
                              icon: Icons.campaign_rounded,
                              color: theme.accent,
                              label: 'Send Notification',
                              subtitle: 'Message one user or broadcast to all',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AdminSendNotificationScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _actionTile(
                              theme,
                              icon: Icons.storefront_rounded,
                              color: const Color(0xFF8B2FA0),
                              label: 'Shop Management',
                              subtitle: 'Add, edit, or remove shop products',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AdminShopScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _actionTile(
                              theme,
                              icon: Icons.support_agent_rounded,
                              color: const Color(0xFFF59E0B),
                              label: 'Help Requests',
                              subtitle: 'Locked-out users — reply by email',
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AdminHelpRequestsScreen(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
        );
      },
    );
  }

  Widget _iconOrAsset(
    IconData icon,
    Color color,
    double size, {
    String? iconAsset,
  }) {
    if (iconAsset == null) {
      return Icon(
        icon,
        color: color,
        size: size,
      );
    }

    return Image.asset(
      iconAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        icon,
        color: color,
        size: size,
      ),
    );
  }

  Widget _statCard(
    AppThemeColors theme,
    String label,
    String value,
    IconData icon,
    Color color, {
    String? iconAsset,
    VoidCallback? onTap,
  }) {
    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(
            alpha: theme.isDark ? 0.32 : 0.18,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(
              alpha: theme.isDark ? 0.42 : 0.24,
            ),
            blurRadius: 20,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: _iconOrAsset(
              icon,
              color,
              22,
              iconAsset: iconAsset,
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: theme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: 10.5,
              color: theme.textSecondary,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: card,
    );
  }

  Widget _actionTile(
    AppThemeColors theme, {
    required IconData icon,
    required Color color,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    String? iconAsset,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(
              alpha: theme.isDark ? 0.30 : 0.16,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(
                alpha: theme.isDark ? 0.36 : 0.20,
              ),
              blurRadius: 16,
              spreadRadius: 0.5,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _iconOrAsset(
                icon,
                color,
                22,
                iconAsset: iconAsset,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    AppThemeColors theme,
  ) {
    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: theme.isDark
              ? LinearGradient(
                  colors: [
                    theme.surface,
                    theme.surfaceAlt,
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
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _goToAdminProfile();
                  },
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.accent,
                          theme.accentLight,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.accent.withValues(
                            alpha: 0.45,
                          ),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _adminName.isNotEmpty ? _adminName : 'Admin',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.textPrimary,
                  ),
                ),
                Text(
                  'Administrator',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: theme.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        _AdminDrawerItem(
                          icon: Icons.person_rounded,
                          label: 'Profile',
                          accentColor: const Color(0xFFE91E8C),
                          theme: theme,
                          onTap: () {
                            Navigator.pop(context);
                            _goToAdminProfile();
                          },
                        ),
                        const SizedBox(height: 14),
                        _AdminDrawerItem(
                          icon: Icons.settings_rounded,
                          label: 'Settings',
                          subtitle: 'Account, security, notifications',
                          accentColor: const Color(0xFF38BDF8),
                          theme: theme,
                          onTap: () {
                            Navigator.pop(context);
                            _goToAdminSettings();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                _AdminDrawerItem(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  accentColor: Colors.red.shade400,
                  theme: theme,
                  onTap: () => _logout(context, theme),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout(
    BuildContext context,
    AppThemeColors theme,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Sign out?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: theme.textPrimary,
          ),
        ),
        content: Text(
          'You will need to log in again to access the admin panel.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: theme.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: theme.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accent,
            ),
            child: Text(
              'Sign out',
              style: GoogleFonts.poppins(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await FirebaseAuth.instance.signOut();

    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/login',
        (route) => false,
      );
    }
  }
}

class _InfoBanner extends StatelessWidget {
  final AppThemeColors theme;
  final String text;
  final VoidCallback onDismiss;

  const _InfoBanner({
    required this.theme,
    required this.text,
    required this.onDismiss,
  });

  static const Color _blue = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        14,
        10,
        8,
        10,
      ),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _blue.withValues(
            alpha: theme.isDark ? 0.32 : 0.22,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(
              alpha: theme.isDark ? 0.28 : 0.16,
            ),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: _blue.withValues(
                alpha: theme.isDark ? 0.20 : 0.12,
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: _blue,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                color: theme.textSecondary,
                height: 1.35,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 17,
              color: theme.textSecondary.withValues(alpha: 0.7),
            ),
            splashRadius: 15,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _AdminDrawerItem extends StatefulWidget {
  final IconData icon;
  final Color accentColor;
  final AppThemeColors theme;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _AdminDrawerItem({
    required this.icon,
    required this.accentColor,
    required this.theme,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  State<_AdminDrawerItem> createState() => _AdminDrawerItemState();
}

class _AdminDrawerItemState extends State<_AdminDrawerItem> {
  bool _hover = false;
  bool _pressed = false;

  bool get _active => _hover || _pressed;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.96 : (_hover ? 1.03 : 1.0);
    final accent = widget.accentColor;
    final isDark = widget.theme.isDark;

    final fillColor = isDark
        ? Color.alphaBlend(
            accent.withValues(
              alpha: _active ? 0.16 : 0.10,
            ),
            widget.theme.surfaceAlt,
          )
        : accent.withValues(
            alpha: _active ? 0.16 : 0.10,
          );

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
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          transform: Matrix4.identity()
            ..scaleByDouble(
              scale,
              scale,
              1.0,
              1.0,
            )
            ..translateByDouble(
              0.0,
              _hover && !_pressed ? -3.0 : 0.0,
              0.0,
              1.0,
            ),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: fillColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent.withValues(
                alpha: _active ? 0.65 : 0.38,
              ),
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(
                  alpha: _active ? 0.58 : 0.34,
                ),
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
                decoration: BoxDecoration(
                  color: isDark
                      ? ThemeService.darkTintedChip(
                          accent,
                          amount: 0.28,
                        )
                      : Colors.white,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(
                        alpha: _active ? 0.55 : 0.38,
                      ),
                      blurRadius: _active ? 18 : 12,
                      offset: const Offset(0, 3),
                      spreadRadius: _active ? 1.2 : 0.3,
                    ),
                  ],
                  border: Border.all(
                    color: accent.withValues(
                      alpha: _active ? 0.32 : (isDark ? 0.28 : 0.16),
                    ),
                    width: 1,
                  ),
                ),
                child: Icon(
                  widget.icon,
                  color: accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                    if (widget.subtitle != null)
                      Text(
                        widget.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 10.5,
                          color: widget.theme.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: accent.withValues(
                  alpha: _active ? 0.9 : 0.5,
                ),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HamburgerButton extends StatefulWidget {
  final Color accentColor;
  final VoidCallback onTap;

  const _HamburgerButton({
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_HamburgerButton> createState() => _HamburgerButtonState();
}

class _HamburgerButtonState extends State<_HamburgerButton> {
  bool _hover = false;

  Widget _line(bool wide) => AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: wide ? 18 : 12,
        height: 2,
        decoration: BoxDecoration(
          color: widget.accentColor,
          borderRadius: BorderRadius.circular(2),
        ),
      );

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
            color: widget.accentColor.withValues(
              alpha: _hover ? 0.20 : 0.12,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _line(true),
              const SizedBox(height: 4),
              _line(false),
              const SizedBox(height: 4),
              _line(true),
            ],
          ),
        ),
      ),
    );
  }
}
