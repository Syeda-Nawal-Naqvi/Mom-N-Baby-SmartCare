import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/shop_product.dart';
import '../../services/shop_service.dart';
import '../../services/theme_service.dart';
import 'admin_shop_add_edit_screen.dart';

class AdminShopCategoryProductsScreen extends StatefulWidget {
  final String category;

  const AdminShopCategoryProductsScreen({super.key, required this.category});

  @override
  State<AdminShopCategoryProductsScreen> createState() =>
      _AdminShopCategoryProductsScreenState();
}

class _AdminShopCategoryProductsScreenState
    extends State<AdminShopCategoryProductsScreen> {
  final ShopService _shopService = ShopService();

  // Kept in sync with the latest StreamBuilder snapshot so the
  // "Delete Category" action always knows exactly which products
  // belong to this category right now, without a second query.
  List<ShopProduct> _currentProducts = [];
  bool _deletingCategory = false;

  Future<void> _confirmDelete(AppThemeColors theme, ShopProduct p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete product?',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: theme.textPrimary)),
        content: Text(
          'This will permanently remove "${p.name}". Consider hiding it '
          '(toggle off) instead if it might come back in stock.',
          style: GoogleFonts.poppins(fontSize: 13, color: theme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: theme.danger),
            child:
                Text('Delete', style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _shopService.deleteProduct(p.id);
    }
  }

  /// Deletes the entire category: every product currently in
  /// [_currentProducts] is removed one by one via the same
  /// `ShopService.deleteProduct` used for single-product delete (so no
  /// new backend method is required), then the admin is taken back to
  /// the category list since this category no longer has anything in
  /// it.
  Future<void> _confirmDeleteCategory(AppThemeColors theme) async {
    final count = _currentProducts.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete "${widget.category}"?',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: theme.textPrimary)),
        content: Text(
          count == 0
              ? 'This category has no products in it. It will be removed.'
              : 'This will permanently delete this category AND all $count '
                  'product${count == 1 ? '' : 's'} inside it. This cannot '
                  'be undone.',
          style: GoogleFonts.poppins(fontSize: 13, color: theme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: theme.danger),
            child: Text('Delete Category',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;

    setState(() => _deletingCategory = true);
    try {
      // Snapshot the list before looping — deleting a product removes
      // it from the live stream mid-loop, which would otherwise mutate
      // _currentProducts while we're iterating over it.
      final toDelete = List<ShopProduct>.from(_currentProducts);
      for (final p in toDelete) {
        await _shopService.deleteProduct(p.id);
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '"${widget.category}" and its ${toDelete.length} product${toDelete.length == 1 ? '' : 's'} deleted'),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _deletingCategory = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting category: $e')),
      );
    }
  }

  Widget _thumb(AppThemeColors theme, String base64Str) {
    if (base64Str.isEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.image_rounded, color: theme.accent),
      );
    }
    try {
      final bytes = base64Decode(base64Str);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(bytes, width: 56, height: 56, fit: BoxFit.cover),
      );
    } catch (_) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.broken_image_rounded, color: theme.accent),
      );
    }
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
            title: Text(widget.category,
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.accent)),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: 'Delete category',
                icon: _deletingCategory
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: theme.danger),
                      )
                    : Icon(Icons.delete_forever_rounded, color: theme.danger),
                onPressed: _deletingCategory
                    ? null
                    : () => _confirmDeleteCategory(theme),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: theme.accent,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text('Add Product',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AdminShopAddEditScreen(category: widget.category),
              ),
            ),
          ),
          body: StreamBuilder<List<ShopProduct>>(
            stream: _shopService.streamAllProductsByCategory(widget.category),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                    child: CircularProgressIndicator(color: theme.accent));
              }
              if (snapshot.hasError) {
                // Most common cause: Firestore needs a composite index for
                // this query (category + isActive/orderBy). The error
                // message Firestore throws contains a direct link to
                // auto-create it — shown here (instead of a silent "No
                // products yet") so it's actually visible and
                // clickable/copyable during setup.
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: theme.danger, size: 40),
                        const SizedBox(height: 12),
                        Text('Couldn\'t load products',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: theme.textPrimary)),
                        const SizedBox(height: 8),
                        SelectableText(
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                              fontSize: 11.5, color: theme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final products = snapshot.data ?? [];
              // Keep the running list in sync for _confirmDeleteCategory
              // to use — scheduled after this frame so we never call
              // setState from inside build().
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _currentProducts = products;
              });
              if (products.isEmpty) {
                return Center(
                  child: Text(
                    'No products in "${widget.category}" yet.\nTap "Add Product" to get started.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: theme.textSecondary),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                itemCount: products.length,
                itemBuilder: (context, i) {
                  final p = products[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: theme.accent.withValues(alpha: 0.14)),
                      boxShadow: [
                        BoxShadow(
                          color: theme.accent
                              .withValues(alpha: theme.isDark ? 0.14 : 0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        _thumb(theme, p.imageBase64),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: theme.textPrimary)),
                              const SizedBox(height: 2),
                              Text(p.brand,
                                  style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: theme.textSecondary)),
                              if (p.tag != null && p.tag!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(p.tag!,
                                      style: GoogleFonts.poppins(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: theme.accent)),
                                ),
                              ],
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Switch(
                                    value: p.isActive,
                                    activeThumbColor: theme.accent,
                                    onChanged: (v) =>
                                        _shopService.toggleActive(p.id, v),
                                  ),
                                  Text(p.isActive ? 'Active' : 'Hidden',
                                      style: GoogleFonts.poppins(
                                          fontSize: 11,
                                          color: p.isActive
                                              ? ThemeService.success
                                              : theme.textSecondary)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit_rounded,
                                  color: theme.textSecondary, size: 20),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AdminShopAddEditScreen(
                                    category: widget.category,
                                    product: p,
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded,
                                  color: theme.danger, size: 20),
                              onPressed: () => _confirmDelete(theme, p),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
