import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/shop_product.dart';
import '../../services/shop_service.dart';
import '../../services/firebase_service.dart';
import '../../services/theme_service.dart';
import '../../widgets/country_picker.dart';

class AdminShopAddEditScreen extends StatefulWidget {
  final String category;
  final ShopProduct? product;

  const AdminShopAddEditScreen({
    super.key,
    required this.category,
    this.product,
  });

  @override
  State<AdminShopAddEditScreen> createState() => _AdminShopAddEditScreenState();
}

class _AdminShopAddEditScreenState extends State<AdminShopAddEditScreen> {
  static const List<String> _tagOptions = [
    'Bestseller',
    'New',
    'Sale',
    'Trending',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _productUrlCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final ShopService _shopService = ShopService();

  Uint8List? _pickedImageBytes;
  String? _existingImageBase64;
  String? _selectedTag;
  bool _isActive = true;
  bool _saving = false;
  bool _pickingImage = false;
  List<String> _selectedCountries = [];

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _nameCtrl.text = p.name;
      _productUrlCtrl.text = p.productUrl;
      _brandCtrl.text = p.brand;
      _selectedTag = p.tag;
      _isActive = p.isActive;
      _existingImageBase64 = p.imageBase64;
      _selectedCountries = List<String>.from(p.countries);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _productUrlCtrl.dispose();
    _brandCtrl.dispose();
    super.dispose();
  }

  Future<void> _showSnack(String message) async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        content: Text(message,
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white)),
      ),
    );
  }

  Future<void> _pickImage() async {
    setState(() => _pickingImage = true);
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 45,
        maxWidth: 800,
      );
      if (xfile != null) {
        final bytes = await xfile.readAsBytes();
        setState(() {
          _pickedImageBytes = bytes;
          _existingImageBase64 = null;
        });
      }
    } catch (_) {
      _showSnack('Could not open gallery. Please try again.');
    } finally {
      if (mounted) setState(() => _pickingImage = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final hasImage = _pickedImageBytes != null ||
        (_existingImageBase64 != null && _existingImageBase64!.isNotEmpty);
    if (!hasImage) {
      _showSnack('Please choose a product image from the gallery.');
      return;
    }

    final online = FirestoreService.isOnline.value;
    if (!online) {
      _showSnack('No internet connection');
      return;
    }

    setState(() => _saving = true);

    try {
      final imageBase64 = _pickedImageBytes != null
          ? base64Encode(_pickedImageBytes!)
          : (_existingImageBase64 ?? '');

      if (_isEditing) {
        final updated = ShopProduct(
          id: widget.product!.id,
          name: _nameCtrl.text.trim(),
          imageBase64: imageBase64,
          productUrl: _productUrlCtrl.text.trim(),
          category: widget.category,
          brand: _brandCtrl.text.trim(),
          tag: _selectedTag,
          isActive: _isActive,
          countries: _selectedCountries,
        );
        await _shopService.updateProduct(widget.product!.id, updated);
      } else {
        final product = ShopProduct(
          id: '',
          name: _nameCtrl.text.trim(),
          imageBase64: imageBase64,
          productUrl: _productUrlCtrl.text.trim(),
          category: widget.category,
          brand: _brandCtrl.text.trim(),
          tag: _selectedTag,
          isActive: _isActive,
          countries: _selectedCountries,
        );
        await _shopService.addProduct(product);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showSnack('Failed to save product. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(AppThemeColors theme, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(fontSize: 13, color: theme.textSecondary),
      filled: true,
      fillColor: theme.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildImagePicker(AppThemeColors theme) {
    Widget preview;
    if (_pickedImageBytes != null) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.memory(_pickedImageBytes!,
            width: double.infinity, height: 180, fit: BoxFit.cover),
      );
    } else if (_existingImageBase64 != null &&
        _existingImageBase64!.isNotEmpty) {
      Uint8List? bytes;
      try {
        bytes = base64Decode(_existingImageBase64!);
      } catch (_) {
        bytes = null;
      }
      preview = bytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(bytes,
                  width: double.infinity, height: 180, fit: BoxFit.cover),
            )
          : _imagePlaceholder(theme);
    } else {
      preview = _imagePlaceholder(theme);
    }

    return GestureDetector(
      onTap: _pickingImage ? null : _pickImage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          preview,
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickingImage ? null : _pickImage,
              icon: _pickingImage
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: theme.accent),
                    )
                  : Icon(Icons.photo_library_outlined, color: theme.accent),
              label: Text(
                (_pickedImageBytes != null ||
                        (_existingImageBase64?.isNotEmpty ?? false))
                    ? 'Change Image'
                    : 'Choose from Gallery',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.accent),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.accent),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(AppThemeColors theme) {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: theme.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.accent.withValues(alpha: 0.25)),
      ),
      child: Center(
        child: Icon(Icons.add_photo_alternate_outlined,
            size: 42, color: theme.accent),
      ),
    );
  }

  Widget _buildTagSelector(AppThemeColors theme) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final tag in _tagOptions)
          GestureDetector(
            onTap: () =>
                setState(() => _selectedTag = _selectedTag == tag ? null : tag),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: _selectedTag == tag ? theme.accent : theme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _selectedTag == tag ? theme.accent : theme.border,
                ),
              ),
              child: Text(
                tag,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _selectedTag == tag ? Colors.white : theme.textPrimary,
                ),
              ),
            ),
          ),
      ],
    );
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
              _isEditing ? 'Edit Product' : 'Add Product',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.accent),
            ),
            centerTitle: true,
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
              children: [
                Text('Category: ${widget.category}',
                    style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: theme.accent)),
                const SizedBox(height: 14),
                _buildImagePicker(theme),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameCtrl,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: theme.textPrimary,
                      fontWeight: FontWeight.w500),
                  decoration: _dec(theme, 'Product name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _productUrlCtrl,
                  keyboardType: TextInputType.url,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: theme.textPrimary,
                      fontWeight: FontWeight.w500),
                  decoration: _dec(
                      theme, 'Product URL (e.g. https://amnaassons.com/...)'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final uri = Uri.tryParse(v.trim());
                    if (uri == null || !uri.isAbsolute) {
                      return 'Enter a valid URL';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _brandCtrl,
                  style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: theme.textPrimary,
                      fontWeight: FontWeight.w500),
                  decoration: _dec(theme, 'Brand name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 18),
                Text('Tag (optional)',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary)),
                const SizedBox(height: 10),
                _buildTagSelector(theme),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text('Visible in (optional)',
                          style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.textPrimary)),
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final picked = await showCountryMultiPicker(
                          context,
                          currentValues: _selectedCountries,
                          title: 'Visible in these countries',
                        );
                        if (picked != null) {
                          setState(() => _selectedCountries = picked);
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
                _selectedCountries.isEmpty
                    ? Text(
                        'Visible everywhere the category is visible',
                        style: GoogleFonts.poppins(
                            fontSize: 11.5, color: theme.textSecondary),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _selectedCountries
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
                                  onDeleted: () => setState(
                                      () => _selectedCountries.remove(c)),
                                ))
                            .toList(),
                      ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Active (visible to users)',
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.textPrimary)),
                  value: _isActive,
                  activeThumbColor: theme.accent,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.accent,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(
                            _isEditing ? 'Update Product' : 'Add Product',
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
