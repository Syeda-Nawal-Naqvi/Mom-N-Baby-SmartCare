import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/shop_product.dart';
import '../../services/shop_service.dart';
import '../../services/firebase_service.dart';
import '../../services/theme_service.dart';

class ShopCategoryProductsScreen extends StatefulWidget {
  final String category;

  const ShopCategoryProductsScreen({super.key, required this.category});

  @override
  State<ShopCategoryProductsScreen> createState() =>
      _ShopCategoryProductsScreenState();
}

class _ShopCategoryProductsScreenState
    extends State<ShopCategoryProductsScreen> {
  static const Color primary = Color(0xFFE91E8C);

  final ShopService _shopService = ShopService();
  String _userCountry = '';
  bool _countryLoaded = false;

  @override
  void initState() {
    super.initState();
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

  Future<void> _openProduct(String url) async {
    final online = FirestoreService.isOnline.value;
    if (!online) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black87,
          content: Text('No internet connection',
              style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
        ),
      );
      return;
    }

    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Could not open the product page',
              style: GoogleFonts.poppins(fontSize: 13)),
        ),
      );
    }
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
        title: Text(widget.category,
            style: GoogleFonts.poppins(
                fontSize: 17, fontWeight: FontWeight.bold, color: textPrimary)),
      ),
      body: StreamBuilder<List<ShopProduct>>(
        stream: _shopService.streamActiveProductsByCategory(widget.category),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              !_countryLoaded) {
            return const Center(
                child: CircularProgressIndicator(color: primary));
          }
          final products = snapshot.data ?? [];
          if (products.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 56, color: textSecondary.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text('No products yet',
                        style: GoogleFonts.poppins(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: textPrimary)),
                    const SizedBox(height: 4),
                    Text('Please check back soon',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: textSecondary)),
                  ],
                ),
              ),
            );
          }

          final visibleProducts =
              products.where((p) => p.visibleTo(_userCountry)).toList();

          // Products exist in this category overall, but none are
          // scoped to this user's country — same "not available in
          // your region" treatment as the category grid, kept as a
          // Center + SingleChildScrollView so long text never overflows
          // on narrow screens.
          if (visibleProducts.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_off_rounded,
                        size: 56, color: textSecondary.withValues(alpha: 0.5)),
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
                          ? 'We\'re working on bringing these products to more countries soon.'
                          : 'We\'re working on bringing these products to $_userCountry soon.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: 0.68,
            ),
            itemCount: visibleProducts.length,
            itemBuilder: (context, i) => _ProductCard(
              product: visibleProducts[i],
              isDark: isDark,
              onShopNow: () => _openProduct(visibleProducts[i].productUrl),
            ),
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  static const Color primary = Color(0xFFE91E8C);

  final ShopProduct product;
  final bool isDark;
  final VoidCallback onShopNow;

  const _ProductCard(
      {required this.product, required this.isDark, required this.onShopNow});

  Widget _image() {
    final placeholderBg = isDark
        ? ThemeService.darkTintedChip(primary, amount: 0.18)
        : const Color(0xFFFFE4F2);
    if (product.imageBase64.isEmpty) {
      return Container(
        color: placeholderBg,
        child: const Icon(Icons.image_not_supported_rounded, color: primary),
      );
    }
    try {
      final bytes = base64Decode(product.imageBase64);
      return Image.memory(bytes, fit: BoxFit.cover, width: double.infinity);
    } catch (_) {
      return Container(
        color: placeholderBg,
        child: const Icon(Icons.broken_image_rounded, color: primary),
      );
    }
  }

  Color _tagColor(String tag) {
    switch (tag) {
      case 'Bestseller':
        return const Color(0xFFF59E0B);
      case 'New':
        return const Color(0xFF10B981);
      case 'Sale':
        return Colors.red.shade400;
      case 'Trending':
        return const Color(0xFF8B5CF6);
      default:
        return primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final surface = ThemeService.surface(isDark);
    final textPrimary = ThemeService.textPrimary(isDark);
    final textSecondary = ThemeService.textSecondary(isDark);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  child: SizedBox(width: double.infinity, child: _image()),
                ),
                if (product.tag != null && product.tag!.isNotEmpty)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _tagColor(product.tag!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        product.tag!,
                        style: GoogleFonts.poppins(
                            fontSize: 9.5,
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  product.brand,
                  style:
                      GoogleFonts.poppins(fontSize: 10.5, color: textSecondary),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onShopNow,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'Shop Now',
                      style: GoogleFonts.poppins(
                          fontSize: 10.5, fontWeight: FontWeight.w600),
                    ),
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
