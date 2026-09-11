import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shop_product.dart';

class ShopService {
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('shop_products');

  /// Helper: sorts a list of ShopProduct by createdAt descending.
  /// Products without a createdAt timestamp go to the end.
  List<ShopProduct> _sortByNewest(List<ShopProduct> products) {
    final sorted = List<ShopProduct>.from(products);
    sorted.sort((a, b) {
      final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime); // descending (newest first)
    });
    return sorted;
  }

  // ── User side: only active products of a chosen category ───────
  // NOTE: Avoids composite indexes by filtering & sorting in Dart.
  Stream<List<ShopProduct>> streamActiveProductsByCategory(String category) {
    return _col
        .where('category', isEqualTo: category)
        .snapshots()
        .map((s) => s.docs
            .map((d) => ShopProduct.fromDoc(d))
            .where((p) => p.isActive)
            .toList())
        .map((list) => _sortByNewest(list));
  }

  // ── Admin side: all products (active + hidden) of a category ────
  // NOTE: Avoids composite indexes by sorting in Dart.
  Stream<List<ShopProduct>> streamAllProductsByCategory(String category) {
    return _col
        .where('category', isEqualTo: category)
        .snapshots()
        .map((s) => s.docs.map((d) => ShopProduct.fromDoc(d)).toList())
        .map((list) => _sortByNewest(list));
  }

  Future<void> addProduct(ShopProduct product) async {
    final data = product.toMap();
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _col.add(data);
  }

  Future<void> updateProduct(String id, ShopProduct product) async {
    final data = product.toMap();
    data['updatedAt'] = FieldValue.serverTimestamp();
    await _col.doc(id).update(data);
  }

  Future<void> toggleActive(String id, bool value) async {
    await _col.doc(id).update({
      'isActive': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteProduct(String id) async {
    await _col.doc(id).delete();
  }
}
