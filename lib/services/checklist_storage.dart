import 'package:shared_preferences/shared_preferences.dart';

class ChecklistStorage {
  static const _prefix = 'checklist_';

  // ===== Обычные чек-листы (список покупок) =====

  static Future<Set<String>> load(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('$_prefix$key') ?? [];
    return list.toSet();
  }

  static Future<void> save(String key, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_prefix$key', ids.toList());
  }

  static Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
  }

  // ===== Ежедневные чек-листы (правила марафона) =====

  /// Загрузка с автопросбросом: если дата сохранения не сегодня —
  /// галочки очищаются, ставится новая дата.
  static Future<Set<String>> loadDaily(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    final savedDate = prefs.getString('$_prefix${key}_date');
    if (savedDate != today) {
      await prefs.setString('$_prefix${key}_date', today);
      await prefs.remove('$_prefix$key');
      return {};
    }
    final list = prefs.getStringList('$_prefix$key') ?? [];
    return list.toSet();
  }

  static Future<void> saveDaily(String key, Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('$_prefix$key', ids.toList());
    await prefs.setString('$_prefix${key}_date', _todayKey());
  }

  static Future<void> clearDaily(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_prefix$key');
    await prefs.setString('$_prefix${key}_date', _todayKey());
  }

  static String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
