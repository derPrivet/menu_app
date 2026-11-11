import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/diary.dart';

class DiaryStorage {
  static const _prefix = 'diary_';

  // Ключи для коридора калорий
  static const _goalMinKey = 'diary_goal_min_kcal';
  static const _goalMaxKey = 'diary_goal_max_kcal';
  static const _oldGoalKey = 'diary_goal_kcal';

  // Ключи для воды
  static const _waterPrefix = 'diary_water_';
  static const _waterGoalKey = 'diary_water_goal_ml';

  static String _dateKey(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static Future<List<DiaryEntry>> loadDay(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('$_prefix${_dateKey(date)}');
    if (jsonStr == null || jsonStr.isEmpty) return [];
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => DiaryEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> saveDay(DateTime date, List<DiaryEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    if (entries.isEmpty) {
      await prefs.remove('$_prefix${_dateKey(date)}');
      return;
    }
    final jsonStr = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString('$_prefix${_dateKey(date)}', jsonStr);
  }

  static Future<CalorieGoal?> loadGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final min = prefs.getInt(_goalMinKey);
    final max = prefs.getInt(_goalMaxKey);
    if (min != null && max != null) {
      return CalorieGoal(min: min, max: max);
    }
    final oldGoal = prefs.getInt(_oldGoalKey);
    if (oldGoal != null) {
      return CalorieGoal(min: oldGoal, max: oldGoal + 200);
    }
    return null;
  }

  static Future<void> saveGoal(CalorieGoal goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_goalMinKey, goal.min);
    await prefs.setInt(_goalMaxKey, goal.max);
    await prefs.remove(_oldGoalKey);
  }

  // --- ЛОГИКА ДЛЯ ВОДЫ ---
  static Future<int> loadWater(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_waterPrefix${_dateKey(date)}') ?? 0;
  }

  static Future<void> saveWater(DateTime date, int ml) async {
    final prefs = await SharedPreferences.getInstance();
    if (ml <= 0) {
      await prefs.remove('$_waterPrefix${_dateKey(date)}');
    } else {
      await prefs.setInt('$_waterPrefix${_dateKey(date)}', ml);
    }
  }

  static Future<int> loadWaterGoal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_waterGoalKey) ?? 2000; // По умолчанию 2 литра
  }

  static Future<void> saveWaterGoal(int ml) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_waterGoalKey, ml);
  }

  static Future<List<String>> allDates() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
        .getKeys()
        .where(
          (k) =>
              k.startsWith(_prefix) &&
              !k.contains('goal') &&
              !k.contains('water'),
        )
        .map((k) => k.substring(_prefix.length))
        .toList();
  }
}
