import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shop_category.dart';

class ShopCategoryService {
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('shop_categories');

  Stream<List<ShopCategory>> streamCategories() {
    return _col
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map((d) => ShopCategory.fromDoc(d)).toList());
  }

  Future<void> addCategory(
    String name, {
    String imageBase64 = '',
    List<String> countries = const [],
  }) async {
    await _col.add({
      'name': name.trim(),
      'imageBase64': imageBase64,
      'countries': countries,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateCategory(
    String id,
    String name, {
    String? imageBase64,
    List<String>? countries,
  }) async {
    final data = <String, dynamic>{'name': name.trim()};
    if (imageBase64 != null) data['imageBase64'] = imageBase64;
    if (countries != null) data['countries'] = countries;
    await _col.doc(id).update(data);
  }

  Future<void> deleteCategory(String id) async {
    await _col.doc(id).delete();
  }
}
