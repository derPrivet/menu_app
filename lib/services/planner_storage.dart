import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/meal_plan.dart';

class PlannerStorage {
  static const _prefix = 'meal_plan_';

  static String _dateKey(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // Загрузка плана на конкретный день
  static Future<List<PlannedMeal>> loadPlan(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('$_prefix${_dateKey(date)}');
    if (jsonStr == null || jsonStr.isEmpty) return [];

    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => PlannedMeal.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Сохранение плана на день
  static Future<void> savePlan(DateTime date, List<PlannedMeal> meals) async {
    final prefs = await SharedPreferences.getInstance();
    if (meals.isEmpty) {
      await prefs.remove('$_prefix${_dateKey(date)}');
      return;
    }
    final jsonStr = jsonEncode(meals.map((e) => e.toJson()).toList());
    await prefs.setString('$_prefix${_dateKey(date)}', jsonStr);
  }
}
