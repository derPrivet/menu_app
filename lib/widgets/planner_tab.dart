import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../models/meal_plan.dart';
import '../models/diary.dart';
import '../models/user_product.dart';
import '../data/basic_products.dart'; // <--- ДОБАВИЛИ ИМПОРТ БАЗОВЫХ ПРОДУКТОВ
import '../services/planner_storage.dart';
import '../services/diary_storage.dart';
import '../services/diary_events.dart';
import '../services/user_product_storage.dart';
import '../theme/app_colors.dart';

const _plannerGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF2D6E4F), Color(0xFF3F8F6B)],
);

// Вспомогательный класс для выбора продуктов (свои + базовые)
class _ProductSource {
  final String id;
  final String title;
  final double kcal100;
  final double protein100;
  final double fat100;
  final double carb100;

  const _ProductSource({
    required this.id,
    required this.title,
    required this.kcal100,
    required this.protein100,
    required this.fat100,
    required this.carb100,
  });
}

class PlannerTab extends StatefulWidget {
  final List<Recipe> allRecipes;
  const PlannerTab({super.key, required this.allRecipes});

  @override
  State<PlannerTab> createState() => _PlannerTabState();
}

class _PlannerTabState extends State<PlannerTab> {
  DateTime _date = DateTime.now();
  List<PlannedMeal> _plan = [];
  CalorieGoal? _goal;
  bool _loading = true;

  List<UserProduct> _userProducts = [];

  @override
  void initState() {
    super.initState();
    _loadPlan();
    _loadUserProducts();
  }

  Future<void> _loadPlan() async {
    setState(() => _loading = true);
    final plan = await PlannerStorage.loadPlan(_date);
    final goal = await DiaryStorage.loadGoal();
    if (mounted) {
      setState(() {
        _plan = plan;
        _goal = goal;
        _loading = false;
      });
    }
  }

  Future<void> _loadUserProducts() async {
    final products = await UserProductStorage.loadAll();
    if (mounted) setState(() => _userProducts = products);
  }

  // Объединяем личные продукты и базовые
  List<_ProductSource> get _allProducts {
    final list = <_ProductSource>[];

    // 1. Личные продукты (Йогурт и т.д.)
    for (final p in _userProducts) {
      list.add(
        _ProductSource(
          id: 'user_product_${p.id}',
          title: p.title,
          kcal100: p.kcal100,
          protein100: p.protein100,
          fat100: p.fat100,
          carb100: p.carb100,
        ),
      );
    }

    // 2. Базовые продукты (Яблоко, Банан, Гречка и т.д.)
    for (final p in basicProducts) {
      list.add(
        _ProductSource(
          id: 'product_${p.id}',
          title: p.title,
          kcal100: p.kcal.toDouble(),
          protein100: p.protein.toDouble(),
          fat100: p.fat.toDouble(),
          carb100: p.carb.toDouble(),
        ),
      );
    }

    return list;
  }

  void _shiftDate(int delta) {
    setState(() => _date = _date.add(Duration(days: delta)));
    _loadPlan();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      helpText: 'На какой день план?',
      cancelText: 'Отмена',
      confirmText: 'ОК',
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
      _loadPlan();
    }
  }

  Recipe? _findRecipe(String id) {
    try {
      return widget.allRecipes.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  ({int kcal, int protein, int fat, int carb}) _calcNutrients(
    PlannedMeal meal,
  ) {
    // 1. Проверяем личные продукты
    if (meal.recipeId.startsWith('user_product_')) {
      final productId = meal.recipeId.replaceFirst('user_product_', '');
      try {
        final p = _userProducts.firstWhere((prod) => prod.id == productId);
        final factor = meal.weight / 100.0;
        return (
          kcal: (p.kcal100 * factor).round(),
          protein: (p.protein100 * factor).round(),
          fat: (p.fat100 * factor).round(),
          carb: (p.carb100 * factor).round(),
        );
      } catch (_) {
        return (kcal: 0, protein: 0, fat: 0, carb: 0);
      }
    }

    // 2. Проверяем базовые продукты
    if (meal.recipeId.startsWith('product_')) {
      final productId = meal.recipeId.replaceFirst('product_', '');
      try {
        final p = basicProducts.firstWhere((prod) => prod.id == productId);
        final factor = meal.weight / 100.0;
        return (
          kcal: (p.kcal * factor).round(),
          protein: (p.protein * factor).round(),
          fat: (p.fat * factor).round(),
          carb: (p.carb * factor).round(),
        );
      } catch (_) {
        return (kcal: 0, protein: 0, fat: 0, carb: 0);
      }
    }

    // 3. Иначе ищем в рецептах
    final recipe = _findRecipe(meal.recipeId);
    if (recipe == null) return (kcal: 0, protein: 0, fat: 0, carb: 0);

    final factor = meal.weight / 100.0;
    return (
      kcal: (recipe.kcal100 * factor).round(),
      protein: (recipe.protein100 * factor).round(),
      fat: (recipe.fat100 * factor).round(),
      carb: (recipe.carb100 * factor).round(),
    );
  }

  int get _totalKcal => _plan.fold(0, (s, m) => s + _calcNutrients(m).kcal);
  int get _totalProtein =>
      _plan.fold(0, (s, m) => s + _calcNutrients(m).protein);
  int get _totalFat => _plan.fold(0, (s, m) => s + _calcNutrients(m).fat);
  int get _totalCarb => _plan.fold(0, (s, m) => s + _calcNutrients(m).carb);

  Future<void> _addMeal(String mealType) async {
    final recipe = await showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RecipePickerSheet(recipes: widget.allRecipes),
    );
    if (recipe == null || !mounted) return;

    final weight = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _WeightInputSheet(title: recipe.title, kcal100: recipe.kcal100),
    );
    if (weight == null || !mounted) return;

    final newMeal = PlannedMeal(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      mealType: mealType,
      recipeId: recipe.id,
      recipeTitle: recipe.title,
      weight: weight,
    );

    setState(() => _plan = [..._plan, newMeal]);
    await PlannerStorage.savePlan(_date, _plan);
  }

  Future<void> _addUserProduct(String mealType) async {
    final allProds = _allProducts;
    if (allProds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Список продуктов пуст.')));
      return;
    }

    final product = await showModalBottomSheet<_ProductSource>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ProductPickerSheet(products: allProds),
    );
    if (product == null || !mounted) return;

    final weight = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) =>
          _WeightInputSheet(title: product.title, kcal100: product.kcal100),
    );
    if (weight == null || !mounted) return;

    final newMeal = PlannedMeal(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      mealType: mealType,
      recipeId: product.id,
      recipeTitle: product.title,
      weight: weight,
    );

    setState(() => _plan = [..._plan, newMeal]);
    await PlannerStorage.savePlan(_date, _plan);
  }

  Future<void> _removeMeal(PlannedMeal meal) async {
    setState(() => _plan = _plan.where((m) => m.id != meal.id).toList());
    await PlannerStorage.savePlan(_date, _plan);
  }

  Future<void> _markAsEaten(PlannedMeal meal) async {
    final nutrients = _calcNutrients(meal);

    final entry = DiaryEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      mealType: meal.mealType,
      title: meal.recipeTitle,
      weight: meal.weight.toInt(),
      kcal: nutrients.kcal,
      protein: nutrients.protein,
      fat: nutrients.fat,
      carb: nutrients.carb,
      addedAt: DateTime.now(),
    );

    final existingEntries = await DiaryStorage.loadDay(_date);
    existingEntries.add(entry);
    await DiaryStorage.saveDay(_date, existingEntries);

    notifyDiaryChanged();

    final updatedPlan = _plan.map((m) {
      if (m.id == meal.id) {
        return PlannedMeal(
          id: m.id,
          mealType: m.mealType,
          recipeId: m.recipeId,
          recipeTitle: m.recipeTitle,
          weight: m.weight,
          isEaten: true,
        );
      }
      return m;
    }).toList();

    setState(() => _plan = updatedPlan);
    await PlannerStorage.savePlan(_date, _plan);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавлено в дневник!'),
          backgroundColor: Color(0xFF3F8F6B),
        ),
      );
    }
  }

  String _formatDate() {
    const months = [
      'янв',
      'фев',
      'мар',
      'апр',
      'мая',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];
    final now = DateTime.now();
    final isToday =
        _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
    final base = '${_date.day} ${months[_date.month - 1]}';
    final yearStr = _date.year != now.year ? ' ${_date.year}' : '';
    return isToday ? 'Сегодня, $base$yearStr' : 'План на $base$yearStr';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final mealTypes = [
      MealType.breakfast,
      MealType.lunch,
      MealType.dinner,
      MealType.snack,
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _shiftDate(-1),
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Предыдущий день',
              ),
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border(context)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          size: 18,
                          color: Color(0xFF3F8F6B),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _shiftDate(1),
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Следующий день',
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            children: [
              _buildSummaryCard(),
              const SizedBox(height: 12),
              ...mealTypes.map((type) => _buildMealSection(type)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final kcal = _totalKcal;
    final min = _goal?.min ?? 0;
    final max = _goal?.max ?? 0;
    final hasGoal = min > 0 && max > 0;

    final progress = hasGoal ? (kcal / max).clamp(0.0, 1.0) : 0.0;

    String statusText = '';
    Color progressColor = Colors.white;

    if (hasGoal) {
      if (kcal < min) {
        statusText = 'До нижней границы: ${min - kcal} ккал';
        progressColor = Colors.white70;
      } else if (kcal >= min && kcal <= max) {
        statusText = '✅ План вписывается в коридор!';
        progressColor = Colors.greenAccent;
      } else {
        statusText = '⚠️ Перебор на ${kcal - max} ккал';
        progressColor = Colors.redAccent;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _plannerGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🍽 ', style: TextStyle(fontSize: 18)),
              Expanded(
                child: Text(
                  hasGoal
                      ? 'План: $kcal / $min-$max ккал'
                      : 'План на день: $kcal ккал',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (hasGoal) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              statusText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              _macroChip('Б', _totalProtein),
              const SizedBox(width: 8),
              _macroChip('Ж', _totalFat),
              const SizedBox(width: 8),
              _macroChip('У', _totalCarb),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroChip(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label $value г',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildMealSection(String type) {
    final meals = _plan.where((m) => m.mealType == type).toList();
    final sectionKcal = meals.fold(0, (s, m) => s + _calcNutrients(m).kcal);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.isDark(context)
                ? Colors.black26
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  MealType.label(type),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const Spacer(),
                if (sectionKcal > 0)
                  Text(
                    '$sectionKcal ккал',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3F8F6B),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (meals.isNotEmpty)
              ...meals.map((meal) {
                final nutrients = _calcNutrients(meal);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.fieldBg(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meal.recipeTitle,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: meal.isEaten
                                    ? AppColors.textSecondary(context)
                                    : AppColors.textPrimary(context),
                                decoration: meal.isEaten
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${meal.weight.toInt()} г · 🔥 ${nutrients.kcal} ккал · Б ${nutrients.protein} · Ж ${nutrients.fat} · У ${nutrients.carb}',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (meal.isEaten)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6.0),
                          child: Icon(
                            Icons.check_circle,
                            color: Color(0xFF3F8F6B),
                            size: 24,
                          ),
                        )
                      else
                        IconButton(
                          onPressed: () => _markAsEaten(meal),
                          icon: const Icon(
                            Icons.check_circle_outline,
                            color: Color(0xFF3F8F6B),
                            size: 24,
                          ),
                          tooltip: 'Съедено',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),

                      const SizedBox(width: 6),

                      IconButton(
                        onPressed: () => _removeMeal(meal),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Удалить из плана',
                      ),
                    ],
                  ),
                );
              }),

            GestureDetector(
              onTap: () => _addMeal(type),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF3F8F6B).withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 16, color: Color(0xFF3F8F6B)),
                    SizedBox(width: 6),
                    Text(
                      'Запланировать блюдо',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3F8F6B),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            GestureDetector(
              onTap: () => _addUserProduct(type),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFE07A5F).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.eco, size: 16, color: Color(0xFFE07A5F)),
                    SizedBox(width: 6),
                    Text(
                      'Добавить продукт',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE07A5F),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ ВЫБОР РЕЦЕПТА ============
class _RecipePickerSheet extends StatefulWidget {
  final List<Recipe> recipes;
  const _RecipePickerSheet({required this.recipes});

  @override
  State<_RecipePickerSheet> createState() => _RecipePickerSheetState();
}

class _RecipePickerSheetState extends State<_RecipePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.recipes
        .where((r) => r.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: '🔍 Поиск рецепта',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFFE07A5F),
                    ),
                    filled: true,
                    fillColor: AppColors.fieldBg(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final r = filtered[i];
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    title: Text(r.title),
                    subtitle: Text('🔥 ${r.kcal100.toInt()} ккал/100г'),
                    onTap: () => Navigator.pop(context, r),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============ ВЫБОР ПРОДУКТА (СВОИ + БАЗОВЫЕ) ============
class _ProductPickerSheet extends StatefulWidget {
  final List<_ProductSource> products;
  const _ProductPickerSheet({required this.products});

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products
        .where((p) => p.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: '🔍 Поиск продукта',
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFFE07A5F),
                    ),
                    filled: true,
                    fillColor: AppColors.fieldBg(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final p = filtered[i];
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    title: Text(p.title),
                    subtitle: Text('🔥 ${p.kcal100.toInt()} ккал/100г'),
                    onTap: () => Navigator.pop(context, p),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============ ВВОД ВЕСА ============
class _WeightInputSheet extends StatefulWidget {
  final String title;
  final double kcal100;
  const _WeightInputSheet({required this.title, required this.kcal100});

  @override
  State<_WeightInputSheet> createState() => _WeightInputSheetState();
}

class _WeightInputSheetState extends State<_WeightInputSheet> {
  final _controller = TextEditingController(text: '100');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBg(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Вес порции (г)',
                suffixText: 'г',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final w = double.tryParse(_controller.text);
                  if (w != null && w > 0) Navigator.pop(context, w);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3F8F6B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Добавить в план'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
