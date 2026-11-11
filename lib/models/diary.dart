class DiaryEntry {
  final String id;
  final String mealType; // breakfast / snack / lunch / dinner / lateSnack
  final String title;
  final int weight; // грамм
  final int kcal;
  final int protein;
  final int fat;
  final int carb;
  final DateTime addedAt;

  const DiaryEntry({
    required this.id,
    required this.mealType,
    required this.title,
    required this.weight,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carb,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'mealType': mealType,
    'title': title,
    'weight': weight,
    'kcal': kcal,
    'protein': protein,
    'fat': fat,
    'carb': carb,
    'addedAt': addedAt.toIso8601String(),
  };

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
    id: json['id'] as String,
    mealType: json['mealType'] as String,
    title: json['title'] as String,
    weight: json['weight'] as int,
    kcal: json['kcal'] as int,
    protein: json['protein'] as int,
    fat: json['fat'] as int,
    carb: json['carb'] as int,
    addedAt: DateTime.parse(json['addedAt'] as String),
  );
}

class MealType {
  static const breakfast = 'breakfast';
  static const snack = 'snack';
  static const lunch = 'lunch';
  static const dinner = 'dinner';
  static const lateSnack = 'lateSnack';

  static const all = [breakfast, snack, lunch, dinner, lateSnack];

  static String label(String type) {
    switch (type) {
      case breakfast:
        return '🌅 Завтрак';
      case snack:
        return '🥜 Перекус';
      case lunch:
        return '🍲 Обед';
      case dinner:
        return '🌙 Ужин';
      case lateSnack:
        return '🌜 Второй ужин';
    }
    return type;
  }
}

class CalorieGoal {
  final int min;
  final int max;

  const CalorieGoal({required this.min, required this.max});
}
