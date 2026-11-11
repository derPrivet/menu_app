import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recipe.dart';
import 'diary_events.dart';

class UserRecipeStorage {
  static const _key = 'user_recipes_v1';

  static Future<List<Recipe>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    final list = jsonDecode(jsonStr) as List;
    return list.map((e) => Recipe.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<void> save(Recipe recipe) async {
    final list = await loadAll();
    final index = list.indexWhere((r) => r.id == recipe.id);
    if (index >= 0) {
      list[index] = recipe;
    } else {
      list.add(recipe);
    }
    await _saveList(list);
    notifyDiaryChanged(); // чтобы обновить поиск в дневнике
  }

  static Future<void> delete(String id) async {
    final list = await loadAll();
    list.removeWhere((r) => r.id == id);
    await _saveList(list);
    notifyDiaryChanged();
  }

  static Future<void> _saveList(List<Recipe> list) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(list.map((e) => e.toJson()).toList());
    await prefs.setString(_key, jsonStr);
  }
}
