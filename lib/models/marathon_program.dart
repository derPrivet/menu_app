import 'meal_option.dart';

class MarathonProgram {
  final String id;
  final String title;
  final String emoji;
  final String description;
  final List<String> rules;
  final List<List<String>> dailyChecklist; // [[id, title], ...]
  final List<MealOption> breakfasts;
  final List<MealOption> snacks;
  final List<MealOption> lunches;
  final List<MealOption> dinners;
  final List<MealOption> lateSnacks;
  final List<MealOption> fastingDay;
  final List<String> fastingRules;
  final List<ShoppingCategory> shoppingList;
  final String? plateAdvice;
  final String? timingAdvice;
  final bool active;

  const MarathonProgram({
    required this.id,
    required this.title,
    required this.emoji,
    required this.description,
    this.rules = const [],
    this.dailyChecklist = const [],
    this.breakfasts = const [],
    this.snacks = const [],
    this.lunches = const [],
    this.dinners = const [],
    this.lateSnacks = const [],
    this.fastingDay = const [],
    this.fastingRules = const [],
    this.shoppingList = const [],
    this.plateAdvice,
    this.timingAdvice,
    this.active = true,
  });
}

class ShoppingCategory {
  final String emoji;
  final String title;
  final List<String> items;

  const ShoppingCategory({
    required this.emoji,
    required this.title,
    required this.items,
  });
}
