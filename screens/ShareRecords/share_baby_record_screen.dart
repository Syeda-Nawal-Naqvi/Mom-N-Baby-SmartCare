import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_validator/email_validator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/cache_service.dart';
import '../../services/email_share_service.dart';
import '../../services/firebase_service.dart';
import '../../services/pdf_report_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/app_widgets.dart';

/// ═══════════════════════════════════════════════════════════════════
/// Share Baby Record — Step 1: pick which baby's record to share.
/// Same card language as BabyRecordsGraphsScreen's baby picker.
/// ───────────────────────────────────────────────────────────────────
/// OFFLINE BEHAVIOUR (SharedPreferences-backed):
///   - While ONLINE: a live Firestore stream drives the grid, and every
///     *new* snapshot is mirrored into SharedPreferences via CacheService
///     in the background (fire-and-forget) under key `_cacheKey`.
///   - While OFFLINE: FirestoreService.isOnline flips to false, the
///     screen switches to reading the last-saved list straight out of
///     SharedPreferences instead of touching Firestore at all, so the
///     picker still shows the babies (no spinner, no blank screen).
///
/// NOTE: the cache write is de-duplicated against the last-seen
/// snapshot (see `_lastCachedSnapshot`) so it does NOT fire on every
/// widget rebuild — only when Firestore actually emits new data. Doing
/// I/O unconditionally inside `builder:` is a build-phase side effect
/// and was previously firing on every rebuild of this subtree.
/// ═══════════════════════════════════════════════════════════════════
class ShareBabyPickerScreen extends StatefulWidget {
  const ShareBabyPickerScreen({super.key});

  @override
  State<ShareBabyPickerScreen> createState() => _ShareBabyPickerScreenState();
}

class _ShareBabyPickerScreenState extends State<ShareBabyPickerScreen> {
  static const String _cacheKey = 'share_babies_list';

  static const List<Color> _babyPalette = [
    Color(0xFFE91E8C),
    Color(0xFF3B82F6),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFF7C3AED),
    Color(0xFF06B6D4),
  ];

  // Tracks the last snapshot we already persisted so we only write to
  // SharedPreferences when Firestore actually emits something new —
  // not on every rebuild of the surrounding widget tree.
  QuerySnapshot<Map<String, dynamic>>? _lastCachedSnapshot;

  Future<void> _cacheSnapshotIfNew(
      QuerySnapshot<Map<String, dynamic>> snapshot) async {
    if (identical(snapshot, _lastCachedSnapshot)) return;
    _lastCachedSnapshot = snapshot;
    final list = snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    // Fire-and-forget — never let a cache-write failure affect the UI.
    unawaited(CacheService.saveList(_cacheKey, list));
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
            title: Text(
              'Share Baby Record',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, color: theme.textPrimary),
            ),
          ),
          body: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: FirestoreService.isOnline,
                  builder: (context, online, _) {
                    if (online) {
                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirestoreService.stream('babies'),
                        builder: (context, snapshot) {
                          if (snapshot.hasData) {
                            // Only actually writes when the snapshot is new.
                            _cacheSnapshotIfNew(snapshot.data!);
                          }
                          if (!snapshot.hasData) {
                            return Center(
                              child: CircularProgressIndicator(
                                  color: theme.accent),
                            );
                          }
                          final items = snapshot.data!.docs
                              .map((d) => _BabyItem(id: d.id, data: d.data()))
                              .toList();
                          return _BabyGrid(
                            items: items,
                            theme: theme,
                            palette: _babyPalette,
                          );
                        },
                      );
                    }

                    // OFFLINE: read the last mirrored list from
                    // SharedPreferences instead of hitting Firestore.
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: CacheService.loadList(_cacheKey),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return Center(
                            child:
                                CircularProgressIndicator(color: theme.accent),
                          );
                        }
                        final cached = snap.data!;
                        if (cached.isEmpty) {
                          return const AppEmptyState(
                            message:
                                'No offline data available yet.\nConnect to '
                                'the internet once to load your babies.',
                            icon: Icons.wifi_off_rounded,
                          );
                        }
                        final items = cached
                            .map((m) => _BabyItem(
                                id: (m['id'] ?? '').toString(), data: m))
                            .toList();
                        return _BabyGrid(
                          items: items,
                          theme: theme,
                          palette: _babyPalette,
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
}

/// Simple holder so the grid doesn't care whether the data came from a
/// live [QueryDocumentSnapshot] or a cached [Map] read from
/// SharedPreferences — both get normalised to this shape first.
class _BabyItem {
  final String id;
  final Map<String, dynamic> data;
  const _BabyItem({required this.id, required this.data});
}

class _BabyGrid extends StatelessWidget {
  final List<_BabyItem> items;
  final AppThemeColors theme;
  final List<Color> palette;

  const _BabyGrid({
    required this.items,
    required this.theme,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const AppEmptyState(
        message:
            'No baby profiles yet.\nCreate one from the Baby Health Tracker first.',
        icon: Icons.child_care_rounded,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(18),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.92,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final data = item.data;
        final name = (data['name'] ?? '').toString().isEmpty
            ? 'Baby'
            : data['name'].toString();
        final gender = (data['gender'] ?? '').toString();
        final color = palette[index % palette.length];
        return _BabyShareCard(
          name: name,
          gender: gender,
          accentColor: color,
          theme: theme,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ShareBabyDetailScreen(
                babyId: item.id,
                babyName: name,
                accentColor: color,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BabyShareCard extends StatefulWidget {
  final String name;
  final String gender;
  final Color accentColor;
  final AppThemeColors theme;
  final VoidCallback onTap;

  const _BabyShareCard({
    required this.name,
    required this.gender,
    required this.accentColor,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_BabyShareCard> createState() => _BabyShareCardState();
}

class _BabyShareCardState extends State<_BabyShareCard> {
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

  IconData get _genderIcon {
    final g = widget.gender.toLowerCase();
    if (g.startsWith('m')) return Icons.boy_rounded;
    if (g.startsWith('f')) return Icons.girl_rounded;
    return Icons.child_care_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final scale = _opening ? 1.08 : (_pressed ? 0.96 : 1.0);
    final isDark = widget.theme.isDark;

    final restColor = isDark
        ? Color.alphaBlend(
            widget.accentColor.withValues(alpha: 0.10), widget.theme.surface)
        : Colors.white;
    final activeColor = isDark
        ? Color.alphaBlend(
            widget.accentColor.withValues(alpha: 0.22), widget.theme.surface)
        : Color.alphaBlend(
            widget.accentColor.withValues(alpha: 0.09), Colors.white);
    final baseColor = _active ? activeColor : restColor;
    final tileColor = isDark ? widget.theme.surfaceAlt : Colors.white;

    final shadowColor = isDark
        ? widget.accentColor
            .withValues(alpha: _active ? (_opening ? 0.55 : 0.42) : 0.16)
        : (_active
            ? widget.accentColor.withValues(alpha: _opening ? 0.55 : 0.42)
            : Colors.black.withValues(alpha: 0.10));

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
            color: baseColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: _opening ? 34 : (_active ? 26 : 16),
                offset: _active ? const Offset(0, 10) : const Offset(0, 6),
                spreadRadius: _opening ? 3 : (_active ? 2 : 0.5),
              ),
            ],
            border: Border.all(
              color: _active
                  ? widget.accentColor.withValues(alpha: 0.4)
                  : (isDark
                      ? widget.accentColor.withValues(alpha: 0.14)
                      : Colors.transparent),
              width: 1.4,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: _active ? 66 : 60,
                  height: _active ? 66 : 60,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: tileColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.34),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                        spreadRadius: 0.5,
                      ),
                    ],
                    border: Border.all(
                      color: widget.accentColor.withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                  child: Image.asset(
                    'assets/icons/baby.png',
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) =>
                        Icon(_genderIcon, color: widget.accentColor, size: 26),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  widget.name,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: widget.accentColor,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(Icons.picture_as_pdf_rounded,
                    size: 14, color: widget.accentColor.withValues(alpha: 0.7)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════
/// Share Baby Record — Step 2: compile + email ONE baby's record.
/// Same verified-email-by-default pattern as ShareMotherRecordScreen.
/// Sending itself always requires internet (checked before compiling
/// the PDF), regardless of whether this screen was reached via the
/// live list or the offline cache.
/// ═══════════════════════════════════════════════════════════════════
class ShareBabyDetailScreen extends StatefulWidget {
  final String babyId;
  final String babyName;
  final Color accentColor;

  const ShareBabyDetailScreen({
    super.key,
    required this.babyId,
    required this.babyName,
    required this.accentColor,
  });

  @override
  State<ShareBabyDetailScreen> createState() => _ShareBabyDetailScreenState();
}

class _ShareBabyDetailScreenState extends State<ShareBabyDetailScreen> {
  bool _useDifferentEmail = false;
  final TextEditingController _emailController = TextEditingController();
  bool _isSending = false;

  String get _verifiedEmail => FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? get _resolvedRecipient {
    if (!_useDifferentEmail) return _verifiedEmail;
    final typed = _emailController.text.trim();
    return typed.isEmpty ? null : typed;
  }

  bool get _isRecipientValid {
    final email = _resolvedRecipient;
    return email != null && EmailValidator.validate(email);
  }

  Future<void> _handleSend() async {
    if (!_isRecipientValid) return;

    if (!FirestoreService.isOnline.value) {
      _showNoInternetDialog();
      return;
    }

    setState(() => _isSending = true);
    try {
      final pdfBytes = await PdfReportService.generateBabyReport(
        babyId: widget.babyId,
        babyName: widget.babyName,
      );
      await EmailShareService.sendReportEmail(
        recipientEmail: _resolvedRecipient!,
        subject:
            '${widget.babyName} — Health Report | Mother And Baby SmartCare',
        bodyText: "Sharing ${widget.babyName}'s health report from Mother "
            'And Baby SmartCare. The detailed PDF report is attached for '
            'your reference.',
        pdfBytes: pdfBytes,
        fileName: '${widget.babyName}_Health_Report.pdf',
      );
      if (!mounted) return;
      // The mail app is now open with everything pre-filled — the user
      // still has to tap Send inside it, so this confirms hand-off, not
      // delivery.
      _showResultDialog(
        success: true,
        title: 'Mail App Opened',
        message: 'Your email app has opened with the report attached and '
            "addressed to $_resolvedRecipient. Review it and tap Send "
            'to deliver it.',
      );
    } on NoInternetException {
      if (!mounted) return;
      _showNoInternetDialog();
    } on NoEmailAppException catch (e) {
      if (!mounted) return;
      _showResultDialog(
        success: false,
        title: 'No Email App Found',
        message: '${e.message} Please set up a mail account (e.g. Gmail) '
            'on this device and try again.',
      );
    } catch (e) {
      if (!mounted) return;
      // Show the ACTUAL reason instead of a generic message, so
      // failures are debuggable instead of a dead-end "try again".
      // (Previously this branch swallowed the real exception text.)
      _showResultDialog(
        success: false,
        title: 'Send Failed',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: Icon(Icons.wifi_off_rounded, color: widget.accentColor, size: 34),
        title: Text('No Internet Connection',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'Sharing a PDF report requires an active internet connection. '
          'Please check your connection and try again.',
          style: GoogleFonts.poppins(fontSize: 13.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accentColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('OK', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showResultDialog({
    required bool success,
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: Icon(
          success ? Icons.mark_email_read_rounded : Icons.error_outline_rounded,
          color: success ? Colors.green : Colors.red,
          size: 34,
        ),
        title: Text(title,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(message, style: GoogleFonts.poppins(fontSize: 13.5)),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accentColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('OK', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accentColor;
    return ThemeAware(
      builder: (context, theme) {
        return Scaffold(
          backgroundColor: theme.bg,
          appBar: AppBar(
            backgroundColor: theme.surface,
            elevation: 0,
            iconTheme: IconThemeData(color: accent),
            title: Text(
              '${widget.babyName} — Share',
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700, color: theme.textPrimary),
            ),
          ),
          body: Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BabySummaryCard(
                        color: accent,
                        title: "${widget.babyName}'s Complete Health Record",
                        description:
                            'Includes Weight, Vaccinations, Allergies, '
                            'Milestones and Medical History, compiled into '
                            'a single PDF.',
                        theme: theme,
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Send to',
                        style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: theme.textPrimary),
                      ),
                      const SizedBox(height: 10),
                      _BabyRecipientPanel(
                        accent: accent,
                        theme: theme,
                        verifiedEmail: _verifiedEmail,
                        useDifferentEmail: _useDifferentEmail,
                        emailController: _emailController,
                        onToggle: (v) => setState(() => _useDifferentEmail = v),
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.info_outline_rounded,
                                size: 16, color: theme.textSecondary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tapping "Send" opens your email app with the '
                                'report already attached — review it and tap '
                                'Send inside that app to deliver it.',
                                style: GoogleFonts.poppins(
                                    fontSize: 11.5, color: theme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: (_isRecipientValid && !_isSending)
                              ? _handleSend
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            disabledBackgroundColor:
                                accent.withValues(alpha: 0.35),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: _isSending
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.4, color: Colors.white),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.send_rounded,
                                        color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Text('Send PDF',
                                        style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white)),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BabySummaryCard extends StatelessWidget {
  final Color color;
  final String title;
  final String description;
  final AppThemeColors theme;

  const _BabySummaryCard({
    required this.color,
    required this.title,
    required this.description,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: theme.isDark ? 0.28 : 0.14),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.picture_as_pdf_rounded, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary)),
                const SizedBox(height: 4),
                Text(description,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: theme.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Recipient panel — verified email by default, optional custom email.
/// Uses `RadioGroup<bool>` (current Flutter API), matching the pattern in
/// ShareMotherRecordScreen's `_RecipientPanel`. Previously this widget
/// used the deprecated per-Radio `groupValue`/`onChanged` API, which is
/// now removed/deprecated in current Flutter and inconsistent with the
/// mother-record screen.
class _BabyRecipientPanel extends StatelessWidget {
  final Color accent;
  final AppThemeColors theme;
  final String verifiedEmail;
  final bool useDifferentEmail;
  final TextEditingController emailController;
  final ValueChanged<bool> onToggle;
  final VoidCallback onChanged;

  const _BabyRecipientPanel({
    required this.accent,
    required this.theme,
    required this.verifiedEmail,
    required this.useDifferentEmail,
    required this.emailController,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioGroup<bool>(
      groupValue: useDifferentEmail,
      onChanged: (v) => onToggle(v ?? false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onToggle(false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: !useDifferentEmail
                    ? accent.withValues(alpha: theme.isDark ? 0.18 : 0.08)
                    : theme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: !useDifferentEmail ? accent : theme.border,
                  width: !useDifferentEmail ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  Radio<bool>(
                    value: false,
                    activeColor: accent,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Your registered email',
                                style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: theme.textSecondary)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.verified_rounded,
                                      size: 12, color: Colors.green),
                                  const SizedBox(width: 3),
                                  Text('Verified',
                                      style: GoogleFonts.poppins(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.green)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          verifiedEmail.isEmpty
                              ? 'No email found'
                              : verifiedEmail,
                          style: GoogleFonts.poppins(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: theme.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onToggle(true),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: useDifferentEmail
                    ? accent.withValues(alpha: theme.isDark ? 0.18 : 0.08)
                    : theme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: useDifferentEmail ? accent : theme.border,
                  width: useDifferentEmail ? 1.6 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Radio<bool>(
                        value: true,
                        activeColor: accent,
                      ),
                      Text('Send to a different email',
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (useDifferentEmail)
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 12, right: 6, bottom: 4),
                      child: TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) => onChanged(),
                        style: GoogleFonts.poppins(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'e.g. doctor@example.com',
                          hintStyle: GoogleFonts.poppins(
                              fontSize: 13, color: theme.textSecondary),
                          filled: true,
                          fillColor: theme.surfaceAlt,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: theme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: accent, width: 1.5),
                          ),
                          errorText: emailController.text.isEmpty ||
                                  EmailValidator.validate(
                                      emailController.text.trim())
                              ? null
                              : 'Enter a valid email address',
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
