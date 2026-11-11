class PlannedMeal {
  final String id;
  final String mealType; // breakfast, lunch, dinner, snack
  final String recipeId; // ID блюда из базы
  final String recipeTitle; // Название (чтобы не искать каждый раз)
  final double weight; // Вес порции в граммах
  final bool isEaten; // Съедено или нет

  PlannedMeal({
    required this.id,
    required this.mealType,
    required this.recipeId,
    required this.recipeTitle,
    required this.weight,
    this.isEaten = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'mealType': mealType,
    'recipeId': recipeId,
    'recipeTitle': recipeTitle,
    'weight': weight,
    'isEaten': isEaten,
  };

  factory PlannedMeal.fromJson(Map<String, dynamic> json) => PlannedMeal(
    id: json['id'] as String,
    mealType: json['mealType'] as String,
    recipeId: json['recipeId'] as String,
    recipeTitle: json['recipeTitle'] as String,
    weight: (json['weight'] as num).toDouble(),
    isEaten: json['isEaten'] as bool? ?? false,
  );
}
