import 'package:cloud_firestore/cloud_firestore.dart';

class ShopCategory {
  final String id;
  final String name;
  final String imageBase64;
  final Timestamp? createdAt;

  /// Country names this category is visible in. EMPTY list = visible
  /// everywhere (the default, so existing categories keep working
  /// unchanged). Non-empty = only users whose profile country is in
  /// this list will see the category at all.
  final List<String> countries;

  const ShopCategory({
    required this.id,
    required this.name,
    this.imageBase64 = '',
    this.countries = const [],
    this.createdAt,
  });

  factory ShopCategory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return ShopCategory(
      id: doc.id,
      name: (data['name'] ?? '') as String,
      imageBase64: (data['imageBase64'] ?? '') as String,
      countries: (data['countries'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      createdAt: data['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'imageBase64': imageBase64, 'countries': countries};
  }

  /// True if this category should be shown to someone in [userCountry].
  /// An empty [countries] list (or an unknown/blank [userCountry], e.g.
  /// a user who hasn't set one yet) means "visible to everyone" — the
  /// restriction only kicks in once the admin has explicitly picked at
  /// least one country AND the viewer has a country on their profile.
  bool visibleTo(String userCountry) {
    if (countries.isEmpty) return true;
    if (userCountry.trim().isEmpty) return true;
    return countries.contains(userCountry);
  }
}
