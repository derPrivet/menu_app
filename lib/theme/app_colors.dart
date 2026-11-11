import 'package:flutter/material.dart';

/// Хелпер для адаптивных цветов под светлую/тёмную тему.
/// Использование: AppColors.cardBg(context), AppColors.border(context) и т.д.
class AppColors {
  static bool isDark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  /// Фон карточек (рецепты, программы, здоровье)
  static Color cardBg(BuildContext c) =>
      isDark(c) ? const Color(0xFF1E1E1E) : Colors.white;

  /// Фон «мягких» элементов (поиск, неактивные чипы)
  static Color subtleBg(BuildContext c) =>
      isDark(c) ? const Color(0xFF2A2A2A) : const Color(0xFFF7F5F2);

  /// Фон поиска и модалок
  static Color fieldBg(BuildContext c) =>
      isDark(c) ? const Color(0xFF1E1E1E) : Colors.white;

  /// Цвет границ / разделителей
  static Color border(BuildContext c) =>
      isDark(c) ? const Color(0xFF3A3A3A) : Colors.grey[300]!;

  /// Второстепенный текст
  static Color textSecondary(BuildContext c) =>
      isDark(c) ? const Color(0xFFAAAAAA) : Colors.grey[600]!;

  /// Основной текст
  static Color textPrimary(BuildContext c) =>
      isDark(c) ? Colors.white : const Color(0xFF2B2B2B);

  /// Фон неактивного фильтра (в модалке)
  static Color chipInactiveBg(BuildContext c) =>
      isDark(c) ? const Color(0xFF2A2A2A) : const Color(0xFFF7F5F2);
}
