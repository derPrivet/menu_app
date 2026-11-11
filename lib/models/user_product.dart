class UserProduct {
  final String id;
  final String title;
  final double kcal100;
  final double protein100;
  final double fat100;
  final double carb100;
  final List<String> tags; // Теги: 'Молочка', 'Мясо' и т.д.

  const UserProduct({
    required this.id,
    required this.title,
    required this.kcal100,
    required this.protein100,
    required this.fat100,
    required this.carb100,
    required this.tags,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'kcal100': kcal100,
    'protein100': protein100,
    'fat100': fat100,
    'carb100': carb100,
    'tags': tags,
  };

  factory UserProduct.fromJson(Map<String, dynamic> json) => UserProduct(
    id: json['id'] as String,
    title: json['title'] as String,
    kcal100: (json['kcal100'] as num).toDouble(),
    protein100: (json['protein100'] as num).toDouble(),
    fat100: (json['fat100'] as num).toDouble(),
    carb100: (json['carb100'] as num).toDouble(),
    tags:
        (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        [],
  );
}
