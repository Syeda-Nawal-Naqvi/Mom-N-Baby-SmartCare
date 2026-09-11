import 'package:cloud_firestore/cloud_firestore.dart';

class ShopProduct {
  final String id;
  final String name;
  final String imageBase64;
  final String productUrl;
  final String category;
  final String brand;
  final String? tag; // Bestseller, New, Sale, Trending, or null
  final bool isActive;

  /// Country names this SPECIFIC product is visible in. EMPTY list =
  /// visible everywhere the parent category is visible (default). This
  /// lets two products in the same category differ — e.g. one brand
  /// only ships to Pakistan, another only to the US — without needing
  /// separate categories.
  final List<String> countries;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  const ShopProduct({
    required this.id,
    required this.name,
    required this.imageBase64,
    required this.productUrl,
    required this.category,
    required this.brand,
    required this.isActive,
    this.tag,
    this.countries = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory ShopProduct.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ShopProduct(
      id: doc.id,
      name: (data['name'] ?? '') as String,
      imageBase64: (data['imageBase64'] ?? '') as String,
      productUrl: (data['productUrl'] ?? '') as String,
      category: (data['category'] ?? '') as String,
      brand: (data['brand'] ?? '') as String,
      tag: data['tag'] as String?,
      isActive: (data['isActive'] ?? true) as bool,
      countries: (data['countries'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'imageBase64': imageBase64,
      'productUrl': productUrl,
      'category': category,
      'brand': brand,
      'tag': tag,
      'isActive': isActive,
      'countries': countries,
    };
  }

  /// True if this product should be shown to someone in [userCountry].
  /// Same "empty = everywhere" rule as [ShopCategory.visibleTo].
  bool visibleTo(String userCountry) {
    if (countries.isEmpty) return true;
    if (userCountry.trim().isEmpty) return true;
    return countries.contains(userCountry);
  }
}
