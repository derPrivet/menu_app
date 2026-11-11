import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';

class ReminderStorage {
  static const _key = 'user_reminders_v1';

  // Загрузка всех напоминаний
  static Future<List<Reminder>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_key);
    if (jsonStr == null || jsonStr.isEmpty) return [];

    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => Reminder.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // Сохранение списка
  static Future<void> saveAll(List<Reminder> reminders) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(reminders.map((e) => e.toJson()).toList());
    await prefs.setString(_key, jsonStr);
  }

  // Добавление или обновление одного напоминания
  static Future<void> save(Reminder reminder) async {
    final list = await loadAll();
    final index = list.indexWhere((r) => r.id == reminder.id);
    if (index >= 0) {
      list[index] = reminder;
    } else {
      list.add(reminder);
    }
    await saveAll(list);
  }

  // Удаление по ID
  static Future<void> delete(String id) async {
    final list = await loadAll();
    list.removeWhere((r) => r.id == id);
    await saveAll(list);
  }
}
