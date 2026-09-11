import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/shop_category.dart';
import '../../services/shop_category_service.dart';
import '../../services/firebase_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/country_picker.dart';
import 'admin_shop_category_products_screen.dart';

class AdminShopScreen extends StatefulWidget {
  const AdminShopScreen({super.key});

  @override
  State<AdminShopScreen> createState() => _AdminShopScreenState();
}

class _AdminShopScreenState extends State<AdminShopScreen> {
  final ShopCategoryService _categoryService = ShopCategoryService();
  final ImagePicker _picker = ImagePicker();

  Future<void> _showNoInternetSnack() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        content: Text('No internet connection',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
      ),
    );
  }

  /// Shared Add/Edit dialog for a category — name + an image the admin
  /// picks from the gallery, shown to users instead of a generic sticker
  /// icon. Passing [existing] switches the dialog into edit mode.
  Future<void> _categoryDialog(AppThemeColors theme,
      {ShopCategory? existing}) async {
    final online = FirestoreService.isOnline.value;
    if (!online) {
      _showNoInternetSnack();
      return;
    }
    if (!mounted) return;

    final isEditing = existing != null;
    final controller = TextEditingController(text: existing?.name ?? '');
    final formKey = GlobalKey<FormState>();
    Uint8List? pickedBytes;
    String? existingImageBase64 = existing?.imageBase64;
    bool pickingImage = false;
    List<String> selectedCountries =
        List<String>.from(existing?.countries ?? const []);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickImage() async {
            setDialogState(() => pickingImage = true);
            try {
              final xfile = await _picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 50,
                maxWidth: 600,
              );
              if (xfile != null) {
                final bytes = await xfile.readAsBytes();
                setDialogState(() {
                  pickedBytes = bytes;
                  existingImageBase64 = null;
                });
              }
            } finally {
              setDialogState(() => pickingImage = false);
            }
          }

          Widget preview;
          if (pickedBytes != null) {
            preview = ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(pickedBytes!,
                  width: double.infinity, height: 120, fit: BoxFit.cover),
            );
          } else if (existingImageBase64 != null &&
              existingImageBase64!.isNotEmpty) {
            Uint8List? bytes;
            try {
              bytes = base64Decode(existingImageBase64!);
            } catch (_) {
              bytes = null;
            }
            preview = bytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(bytes,
                        width: double.infinity, height: 120, fit: BoxFit.cover),
                  )
                : Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: theme.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.add_photo_alternate_outlined,
                        size: 34, color: theme.accent),
                  );
          } else {
            preview = Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: theme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.accent.withValues(alpha: 0.25)),
              ),
              child: Icon(Icons.add_photo_alternate_outlined,
                  size: 34, color: theme.accent),
            );
          }

          return AlertDialog(
            backgroundColor: theme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(isEditing ? 'Edit Category' : 'Add Category',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, color: theme.textPrimary)),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: pickingImage ? null : pickImage,
                      child: preview,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: pickingImage ? null : pickImage,
                      icon: pickingImage
                          ? SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: theme.accent))
                          : Icon(Icons.photo_library_outlined,
                              color: theme.accent, size: 18),
                      label: Text(
                        (pickedBytes != null ||
                                (existingImageBase64?.isNotEmpty ?? false))
                            ? 'Change Image'
                            : 'Choose Category Image',
                        style: GoogleFonts.poppins(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: theme.accent),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.accent),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: controller,
                      autofocus: !isEditing,
                      style: GoogleFonts.poppins(
                          fontSize: 14, color: theme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g. Mosquito Net',
                        hintStyle: GoogleFonts.poppins(
                            fontSize: 13, color: theme.textSecondary),
                        filled: true,
                        fillColor: theme.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter a category name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Visible in',
                              style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: theme.textPrimary)),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await showCountryMultiPicker(
                              ctx,
                              currentValues: selectedCountries,
                              title: 'Visible in these countries',
                            );
                            if (picked != null) {
                              setDialogState(() => selectedCountries = picked);
                            }
                          },
                          icon: Icon(Icons.public_rounded,
                              size: 16, color: theme.accent),
                          label: Text('Choose',
                              style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.accent)),
                        ),
                      ],
                    ),
                    selectedCountries.isEmpty
                        ? Text(
                            'Visible to everyone (no country restriction)',
                            style: GoogleFonts.poppins(
                                fontSize: 11, color: theme.textSecondary),
                          )
                        : Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: selectedCountries
                                .map((c) => Chip(
                                      label: Text(c,
                                          style: GoogleFonts.poppins(
                                              fontSize: 10.5,
                                              color: theme.textPrimary)),
                                      backgroundColor:
                                          theme.accent.withValues(alpha: 0.12),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      onDeleted: () => setDialogState(
                                          () => selectedCountries.remove(c)),
                                    ))
                                .toList(),
                          ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel',
                    style: GoogleFonts.poppins(color: theme.textSecondary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  final hasImage = pickedBytes != null ||
                      (existingImageBase64 != null &&
                          existingImageBase64!.isNotEmpty);
                  if (!hasImage) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('Please choose a category image.',
                            style: GoogleFonts.poppins(fontSize: 13)),
                      ),
                    );
                    return;
                  }
                  final online = FirestoreService.isOnline.value;
                  if (!online) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    _showNoInternetSnack();
                    return;
                  }
                  final imageBase64 = pickedBytes != null
                      ? base64Encode(pickedBytes!)
                      : (existingImageBase64 ?? '');
                  if (isEditing) {
                    await _categoryService.updateCategory(
                      existing.id,
                      controller.text.trim(),
                      imageBase64: imageBase64,
                      countries: selectedCountries,
                    );
                  } else {
                    await _categoryService.addCategory(
                      controller.text.trim(),
                      imageBase64: imageBase64,
                      countries: selectedCountries,
                    );
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text('Save',
                    style: GoogleFonts.poppins(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteCategory(
      AppThemeColors theme, ShopCategory category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete category?',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: theme.textPrimary)),
        content: Text(
          'This removes "${category.name}" from the Shop. Its products '
          'will remain in the database but won\'t be reachable from any '
          'category until reassigned.',
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
      await _categoryService.deleteCategory(category.id);
    }
  }

  Widget _thumb(AppThemeColors theme, String base64Str) {
    if (base64Str.isEmpty) {
      return Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.category_rounded, color: theme.accent),
      );
    }
    try {
      final bytes = base64Decode(base64Str);
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(bytes, width: 42, height: 42, fit: BoxFit.cover),
      );
    } catch (_) {
      return Container(
        width: 42,
        height: 42,
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
            title: Text('Shop Management',
                style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.accent)),
            centerTitle: true,
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: theme.accent,
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            label: Text('Add Category',
                style: GoogleFonts.poppins(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            onPressed: () => _categoryDialog(theme),
          ),
          body: StreamBuilder<List<ShopCategory>>(
            stream: _categoryService.streamCategories(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                    child: CircularProgressIndicator(color: theme.accent));
              }
              final categories = snapshot.data ?? [];
              if (categories.isEmpty) {
                return Center(
                  child: Text(
                    'No categories yet.\nTap "Add Category" to get started.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(color: theme.textSecondary),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                itemCount: categories.length,
                itemBuilder: (context, i) {
                  final category = categories[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
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
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      leading: _thumb(theme, category.imageBase64),
                      title: Text(category.name,
                          style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.textPrimary)),
                      subtitle: Text(
                          category.countries.isEmpty
                              ? 'Tap to manage products • All countries'
                              : 'Tap to manage products • ${category.countries.length} ${category.countries.length == 1 ? 'country' : 'countries'}',
                          style: GoogleFonts.poppins(
                              fontSize: 11.5, color: theme.textSecondary)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.edit_rounded,
                                color: theme.textSecondary, size: 19),
                            onPressed: () =>
                                _categoryDialog(theme, existing: category),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline_rounded,
                                color: theme.danger, size: 20),
                            onPressed: () =>
                                _confirmDeleteCategory(theme, category),
                          ),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminShopCategoryProductsScreen(
                            category: category.name,
                          ),
                        ),
                      ),
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
