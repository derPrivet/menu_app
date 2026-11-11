import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/metric_entry.dart';

class MetricStorage {
  static const String _key = 'health_metrics_v1';

  // Сохранение записи (заменяет запись за тот же день и того же типа)
  static Future<void> saveEntry(MetricEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadAll();

    // Удаляем старую запись за этот же день и этого же типа
    history.removeWhere(
      (e) =>
          e.type == entry.type &&
          e.date.year == entry.date.year &&
          e.date.month == entry.date.month &&
          e.date.day == entry.date.day,
    );

    history.add(entry);
    history.sort(
      (a, b) => a.date.compareTo(b.date),
    ); // сортировка по возрастанию даты

    final encoded = jsonEncode(history.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  // Удаление записи по дате и типу
  static Future<void> deleteEntry(DateTime date, String type) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await loadAll();

    history.removeWhere(
      (e) =>
          e.type == type &&
          e.date.year == date.year &&
          e.date.month == date.month &&
          e.date.day == date.day,
    );

    final encoded = jsonEncode(history.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  // Загрузка ВСЕЙ истории (нужно для сохранения и удаления)
  static Future<List<MetricEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final String? encoded = prefs.getString(_key);
    if (encoded == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(encoded);
      return decoded
          .map((e) => MetricEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Ошибка загрузки истории: $e');
      return [];
    }
  }

  // Загрузка истории только для конкретного типа (для графика)
  static Future<List<MetricEntry>> loadByType(String type) async {
    final all = await loadAll();
    return all.where((e) => e.type == type).toList();
  }
}
