class MealOption {
  final String id;
  final String category;
  final String title;
  final String? composition;
  final int kcal100;
  final int protein100;
  final int fat100;
  final int carb100;
  final List<String> ingredients;
  final List<String> steps;
  final String? note;
  final int servings;

  const MealOption({
    required this.id,
    required this.category,
    required this.title,
    this.composition,
    required this.kcal100,
    required this.protein100,
    required this.fat100,
    required this.carb100,
    this.ingredients = const [],
    this.steps = const [],
    this.note,
    this.servings = 1,
  });

  bool get isRecipe => steps.isNotEmpty;
  bool get isSimple => ingredients.length <= 2 && steps.isEmpty;
}
