/// Простой продукт (не рецепт) — например, «яйцо варёное» или «творог 5%».
/// КБЖУ указаны на 100 г.
class BasicProduct {
  final String id;
  final String category;
  final String title;
  final int kcal; // на 100 г
  final int protein; // на 100 г
  final int fat; // на 100 г
  final int carb; // на 100 г
  final int gramsPerUnit; // вес 1 шт, г (0 = не применимо)

  const BasicProduct({
    required this.id,
    required this.category,
    required this.title,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carb,
    this.gramsPerUnit = 0,
  });
}
