import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_product.dart';

class UserProductStorage {
  static const _key = 'user_products';

  static Future<List<UserProduct>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => UserProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveAll(List<UserProduct> products) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(products.map((e) => e.toJson()).toList());
    await prefs.setString(_key, jsonStr);
  }

  static Future<void> addProduct(UserProduct product) async {
    final products = await loadAll();
    products.add(product);
    await saveAll(products);
  }

  static Future<void> deleteProduct(String id) async {
    final products = await loadAll();
    products.removeWhere((p) => p.id == id);
    await saveAll(products);
  }
}
