import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/shop_category.dart';
import '../../services/shop_category_service.dart';
import '../../services/shop_intro_banner_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/collaboration_card.dart';
import '../../widgets/hover_zoom_card.dart';
import 'shop_category_products_screen.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  // Brand pink — kept fixed for headings/accents in both modes, matching
  // the app's mother/baby brand color, while every neutral
  // surface/background/text color comes from ThemeService.
  static const Color primary = Color(0xFFE91E8C);

  // Rotating multi-color palette for category cards — (background tint,
  // accent) pairs, cycled by index so consecutive categories read as
  // distinct, colorful tiles instead of one repeated color.
  static const List<_CategoryPalette> _palette = [
    _CategoryPalette(Color(0xFFFFE4F2), Color(0xFFE91E8C)),
    _CategoryPalette(Color(0xFFE7EAFE), Color(0xFF3B82F6)),
    _CategoryPalette(Color(0xFFD1FAE5), Color(0xFF10B981)),
    _CategoryPalette(Color(0xFFFEF3C7), Color(0xFFF59E0B)),
    _CategoryPalette(Color(0xFFEDE9FE), Color(0xFF8B5CF6)),
    _CategoryPalette(Color(0xFFFFE1E1), Color(0xFFEF4444)),
  ];

  final ShopCategoryService _categoryService = ShopCategoryService();

  bool _showIntroBanner = false;
  String _userCountry = '';
  bool _countryLoaded = false;

  @override
  void initState() {
    super.initState();
    _checkIntroBanner();
    _loadUserCountry();
  }

  Future<void> _loadUserCountry() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() => _countryLoaded = true);
        return;
      }
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!mounted) return;
      setState(() {
        _userCountry = (doc.data()?['country'] ?? '').toString();
        _countryLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _countryLoaded = true);
    }
  }

  Future<void> _checkIntroBanner() async {
    final show = await ShopIntroBannerService.shouldShow();
    if (!mounted) return;
    setState(() => _showIntroBanner = show);
  }

  void _dismissIntroBanner() {
    setState(() => _showIntroBanner = false);
    ShopIntroBannerService.markDismissed();
  }

  /// Picks a responsive column count so category/product grids never
  /// overflow on a phone, tablet, or laptop-width window.
  int _crossAxisCountFor(double width) {
    if (width >= 1000) return 5;
    if (width >= 720) return 4;
    if (width >= 480) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeNotifier>().isDarkMode;
    final bg = ThemeService.bg(isDark);
    final surface = ThemeService.surface(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: primary),
        title: Text('Mother & Baby Shop',
            style: GoogleFonts.poppins(
                fontSize: 17, fontWeight: FontWeight.bold, color: primary)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_showIntroBanner)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _IntroInfoBanner(
                  isDark: isDark,
                  surface: surface,
                  textSecondary: textSecondary,
                  onDismiss: _dismissIntroBanner,
                ),
              ),
            Expanded(
              child: StreamBuilder<List<ShopCategory>>(
                stream: _categoryService.streamCategories(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting ||
                      !_countryLoaded) {
                    return const Center(
                        child: CircularProgressIndicator(color: primary));
                  }
                  final categories = snapshot.data ?? [];
                  if (categories.isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.storefront_rounded,
                                size: 56,
                                color: textSecondary.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text('No categories yet',
                                style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary)),
                            const SizedBox(height: 4),
                            Text('Please check back soon',
                                style: GoogleFonts.poppins(
                                    fontSize: 12, color: textSecondary)),
                            const SizedBox(height: 24),
                            const CollaborationCard(),
                          ],
                        ),
                      ),
                    );
                  }

                  final visibleCategories = categories
                      .where((c) => c.visibleTo(_userCountry))
                      .toList();

                  // Categories exist, but none are scoped to this user's
                  // country — this is a deliberately different message
                  // from "No categories yet" above, since the shop IS
                  // stocked, just not for this region yet.
                  if (visibleCategories.isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_off_rounded,
                                size: 56,
                                color: textSecondary.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              'Shop is currently not available\nin your region',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _userCountry.isEmpty
                                  ? 'We\'re working on bringing the shop to more countries soon.'
                                  : 'We\'re working on bringing the shop to $_userCountry soon.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                  fontSize: 12, color: textSecondary),
                            ),
                            const SizedBox(height: 24),
                            const CollaborationCard(),
                          ],
                        ),
                      ),
                    );
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount =
                          _crossAxisCountFor(constraints.maxWidth);
                      return CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            sliver: SliverToBoxAdapter(
                              child: Text('Shop by Category',
                                  style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: primary)),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                            sliver: SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.92,
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, i) {
                                  final category = visibleCategories[i];
                                  final palette = _palette[i % _palette.length];
                                  return _CategoryCard(
                                    category: category,
                                    palette: palette,
                                    isDark: isDark,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ShopCategoryProductsScreen(
                                          category: category.name,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                childCount: visibleCategories.length,
                              ),
                            ),
                          ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                            sliver: const SliverToBoxAdapter(
                              child: CollaborationCard(),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPalette {
  final Color bg;
  final Color accent;
  const _CategoryPalette(this.bg, this.accent);
}

/// Category tile — shows the admin-set category image (falls back to a
/// generic icon if none was set), a multi-color tinted background, a
/// colored shadow, and the same hover/press "zoom" feel as the Home
/// screen's health-tracker cards.
class _CategoryCard extends StatelessWidget {
  final ShopCategory category;
  final _CategoryPalette palette;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.palette,
    required this.isDark,
    required this.onTap,
  });

  Widget _image() {
    if (category.imageBase64.isEmpty) {
      return Icon(Icons.category_rounded, color: palette.accent, size: 30);
    }
    Uint8List? bytes;
    try {
      bytes = base64Decode(category.imageBase64);
    } catch (_) {
      bytes = null;
    }
    if (bytes == null) {
      return Icon(Icons.category_rounded, color: palette.accent, size: 30);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.memory(bytes, fit: BoxFit.cover),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surface = ThemeService.surface(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final cardBg = isDark
        ? ThemeService.darkTintedChip(palette.accent, amount: 0.16)
        : surface;
    final iconTileBg = isDark
        ? ThemeService.darkTintedChip(palette.accent, amount: 0.30)
        : palette.bg;

    return HoverZoomCard(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: palette.accent.withValues(alpha: isDark ? 0.30 : 0.20),
              blurRadius: 14,
              offset: const Offset(0, 6),
              spreadRadius: 0.5,
            ),
          ],
          border: Border.all(
            color: palette.accent.withValues(alpha: isDark ? 0.24 : 0.14),
            width: 1.2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: LayoutBuilder(
            builder: (context, c) {
              final availW = c.maxWidth.isFinite ? c.maxWidth : 120.0;
              final imgSize = (availW * 0.6).clamp(40.0, 64.0);
              final fontSize = (availW * 0.11).clamp(10.5, 13.0);
              return Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: imgSize,
                    height: imgSize,
                    padding: EdgeInsets.all(imgSize * 0.14),
                    decoration: BoxDecoration(
                      color: iconTileBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _image(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    category.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                      height: 1.25,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One-time-only info banner: "you will be redirected to our partner
/// store...". Behaves like a dismissible feedback banner — shows once,
/// disappears for good after the user taps ×, tracked via
/// [ShopIntroBannerService].
class _IntroInfoBanner extends StatelessWidget {
  final bool isDark;
  final Color surface;
  final Color textSecondary;
  final VoidCallback onDismiss;

  static const Color _blue = Color(0xFF3B82F6);

  const _IntroInfoBanner({
    required this.isDark,
    required this.surface,
    required this.textSecondary,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _blue.withValues(alpha: isDark ? 0.32 : 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: isDark ? 0.30 : 0.18),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.info_outline_rounded, color: _blue, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You will be directed to our partner store to view details '
              'and complete your purchase. Prices and availability are '
              'managed by the seller and may change at any time.',
              style: GoogleFonts.poppins(
                  fontSize: 11.5, color: textSecondary, height: 1.35),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                size: 18, color: textSecondary.withValues(alpha: 0.7)),
            splashRadius: 16,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
