class Recipe {
  final String id;
  final String category;
  final String title;
  final String description;
  final double kcal100;
  final double protein100;
  final double fat100;
  final double carb100;
  final int fiber;
  final int timeMinutes;
  final bool noCook;
  final List<String> tags;
  final List<List<String>> ingredients;
  final List<String> steps;
  final List<String> alternatives;
  final String? warning;
  final String? benefits;
  final String? programTag;
  final String? programSlot;
  final bool isUserRecipe;

  const Recipe({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.kcal100,
    required this.protein100,
    required this.fat100,
    required this.carb100,
    this.fiber = 0,
    this.timeMinutes = 0,
    this.noCook = false,
    this.tags = const [],
    required this.ingredients,
    required this.steps,
    this.alternatives = const [],
    this.warning,
    this.benefits,
    this.programTag,
    this.programSlot,
    this.isUserRecipe = false,
  });

  bool get isLight => kcal100 < 100;
  bool get isHighFiber => fiber >= 5;
  bool get isHighProtein => protein100 >= 25;
  bool get isMeat => tags.contains('мясное');
  bool get isFish => tags.contains('рыбное');
  bool get isDairy => tags.contains('молочное');
  bool get isVeggie => tags.contains('овощное');
  bool get isFast => timeMinutes > 0 && timeMinutes <= 15;
  bool get isNoGluten => tags.contains('без глютена');
  bool get isNoSugar => tags.contains('без сахара');

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'title': title,
    'description': description,
    'kcal100': kcal100,
    'protein100': protein100,
    'fat100': fat100,
    'carb100': carb100,
    'fiber': fiber,
    'timeMinutes': timeMinutes,
    'noCook': noCook,
    'tags': tags,
    'ingredients': ingredients,
    'steps': steps,
    'alternatives': alternatives,
    'warning': warning,
    'benefits': benefits,
    'programTag': programTag,
    'programSlot': programSlot,
    'isUserRecipe': isUserRecipe,
  };

  factory Recipe.fromJson(Map<String, dynamic> json) => Recipe(
    id: json['id'] as String,
    category: json['category'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    // Защита: если пришло целое число (старый рецепт), конвертируем его в дробное
    kcal100: (json['kcal100'] as num?)?.toDouble() ?? 0.0,
    protein100: (json['protein100'] as num?)?.toDouble() ?? 0.0,
    fat100: (json['fat100'] as num?)?.toDouble() ?? 0.0,
    carb100: (json['carb100'] as num?)?.toDouble() ?? 0.0,
    fiber: json['fiber'] as int? ?? 0,
    timeMinutes: json['timeMinutes'] as int? ?? 0,
    noCook: json['noCook'] as bool? ?? false,
    tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
    ingredients:
        (json['ingredients'] as List?)
            ?.map((e) => (e as List).map((s) => s.toString()).toList())
            .toList() ??
        [],
    steps: (json['steps'] as List?)?.map((e) => e.toString()).toList() ?? [],
    alternatives:
        (json['alternatives'] as List?)?.map((e) => e.toString()).toList() ??
        [],
    warning: json['warning'] as String?,
    benefits: json['benefits'] as String?,
    programTag: json['programTag'] as String?,
    programSlot: json['programSlot'] as String?,
    isUserRecipe: json['isUserRecipe'] as bool? ?? false,
  );
}
