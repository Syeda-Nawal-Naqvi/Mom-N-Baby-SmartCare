import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/theme_service.dart';

/// Admin's own profile card — avatar initial, editable display name, email,
/// "Administrator" badge, and member-since date.
///
/// Restyled to match the user-side ProfileScreen exactly: same gradient
/// hero card, same "ACCOUNT DETAILS" section label, and the same
/// bordered/shadowed info-card language — so switching between the user
/// and admin apps feels like one consistent product instead of two.
///
/// Deliberately separate from [AdminSettingsScreen]: this screen is just
/// "who am I", reached from the drawer's "Profile" item. Account security
/// (change email/password), notification preferences, and the danger zone
/// (logout / delete account) stay on the Settings screen, reached from the
/// drawer's "Settings" item — mirroring the Profile/Settings split already
/// used on the user side of the app.
class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const double _maxContentWidth = 560;

  String _name = '';
  String _email = '';
  String _createdAt = '';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = _auth.currentUser;
    _email = user?.email ?? '';
    final uid = user?.uid;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!mounted) return;
      setState(() {
        _name = (doc.data()?['name'] ?? 'Admin').toString();
        final ts = doc.data()?['createdAt'];
        if (ts is Timestamp) {
          final dt = ts.toDate();
          _createdAt = '${dt.day}/${dt.month}/${dt.year}';
        }
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _name = user?.displayName ?? 'Admin';
          _isLoading = false;
        });
      }
    }
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

  Future<void> _showNameDialog(AppThemeColors theme) async {
    final ctrl = TextEditingController(text: _name);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Update Name',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: theme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Maximum 30 characters allowed.',
              style:
                  GoogleFonts.poppins(fontSize: 12, color: theme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLength: 30,
              autofocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.deny(RegExp(r'[0-9]')),
              ],
              style:
                  GoogleFonts.poppins(fontSize: 14, color: theme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter your full name',
                hintStyle: GoogleFonts.poppins(
                    color: theme.textSecondary, fontSize: 13),
                counterStyle: GoogleFonts.poppins(
                    fontSize: 11, color: theme.textSecondary),
                filled: true,
                fillColor: theme.surfaceAlt,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.accent, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final value = ctrl.text.trim();
              if (value.isEmpty) return;
              Navigator.pop(ctx);
              await _saveName(value);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.accent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child:
                Text('Save', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveName(String value) async {
    setState(() => _isSaving = true);
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      await _firestore
          .collection('users')
          .doc(uid)
          .set({'name': value}, SetOptions(merge: true));
      try {
        await _auth.currentUser?.updateDisplayName(value);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _name = value;
        _isSaving = false;
      });
      _showToast('Name updated successfully!', isSuccess: true);
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        _showToast('Failed to update name.', isSuccess: false);
      }
    }
  }

  void _onEmailTap() {
    _showToast('To change email, go to Settings → Change Email',
        isSuccess: false);
  }

  Widget _sectionLabel(String text, Color color) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildInfoCard({
    required String label,
    required Widget child,
    required Color accentColor,
    required AppThemeColors theme,
  }) {
    final isDark = theme.isDark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: isDark ? 0.24 : 0.16),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.24 : 0.14),
            blurRadius: 18,
            spreadRadius: 0.4,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: accentColor,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ThemeAware(
      builder: (context, theme) {
        final fieldColor = theme.textPrimary;

        return Scaffold(
          backgroundColor: theme.bg,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_rounded,
                  color: theme.accent, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: _isLoading
              ? Center(child: CircularProgressIndicator(color: theme.accent))
              : SafeArea(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    child: Center(
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(maxWidth: _maxContentWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'My Profile',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: theme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage your admin account',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: theme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 30),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22, vertical: 24),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.accent,
                                    theme.accentLight,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.accent.withValues(alpha: 0.40),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.20),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.4)),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _name.isNotEmpty
                                            ? _name[0].toUpperCase()
                                            : 'A',
                                        style: GoogleFonts.poppins(
                                          fontSize: 26,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _name.isNotEmpty ? _name : 'Admin',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.35)),
                                    ),
                                    child: Text(
                                      'Administrator',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 36),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _sectionLabel(
                                  'ACCOUNT DETAILS', theme.textSecondary),
                            ),
                            const SizedBox(height: 14),
                            _buildInfoCard(
                              label: 'FULL NAME',
                              accentColor: const Color(0xFF10B981),
                              theme: theme,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _name.isNotEmpty ? _name : '—',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: fieldColor,
                                      ),
                                    ),
                                  ),
                                  _isSaving
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF10B981),
                                          ),
                                        )
                                      : GestureDetector(
                                          onTap: () => _showNameDialog(theme),
                                          child: Container(
                                            width: 34,
                                            height: 34,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981)
                                                  .withValues(alpha: 0.10),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: const Icon(
                                              Icons.edit_rounded,
                                              color: Color(0xFF10B981),
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildInfoCard(
                              label: 'EMAIL ADDRESS',
                              accentColor: theme.accent,
                              theme: theme,
                              child: GestureDetector(
                                onTap: _onEmailTap,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _email.isNotEmpty ? _email : '—',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: fieldColor,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.info_outline_rounded,
                                      size: 18,
                                      color: theme.accent,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildInfoCard(
                              label: 'ROLE',
                              accentColor: const Color(0xFF8B5CF6),
                              theme: theme,
                              child: Row(
                                children: [
                                  Icon(Icons.verified_rounded,
                                      size: 18, color: const Color(0xFF8B5CF6)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Administrator',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: fieldColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_createdAt.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              _buildInfoCard(
                                label: 'ADMIN SINCE',
                                accentColor: const Color(0xFF66BB6A),
                                theme: theme,
                                child: Text(
                                  _createdAt,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: fieldColor,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
