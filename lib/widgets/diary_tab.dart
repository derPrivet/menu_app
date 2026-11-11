import 'package:flutter/material.dart';
import '../models/diary.dart';
import '../models/meal_option.dart';
import '../models/recipe.dart';
import '../models/user_product.dart'; // <--- ДОБАВИЛИ
import '../data/marathon_data.dart';
import '../data/basic_products.dart';
import '../services/diary_storage.dart';
import '../services/diary_events.dart';
import '../services/user_product_storage.dart'; // <--- ДОБАВИЛИ
import '../theme/app_colors.dart';

const _accentGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFC05A3F), Color(0xFFE07A5F)],
);

String _fmt(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

class _DishSource {
  final String id;
  final String title;
  final double kcal100;
  final double protein100;
  final double fat100;
  final double carb100;
  final bool fromMarathon;
  final bool isProduct;

  const _DishSource({
    required this.id,
    required this.title,
    required this.kcal100,
    required this.protein100,
    required this.fat100,
    required this.carb100,
    this.fromMarathon = false,
    this.isProduct = false,
  });
}

class DiaryTab extends StatefulWidget {
  final List<Recipe> allRecipes;
  const DiaryTab({super.key, required this.allRecipes});

  @override
  State<DiaryTab> createState() => _DiaryTabState();
}

class _DiaryTabState extends State<DiaryTab> {
  DateTime _date = DateTime.now();
  List<DiaryEntry> _entries = [];
  CalorieGoal? _goal;

  int _waterMl = 0;
  int _waterGoal = 2000;

  bool _loading = true;

  String _activeTab = 'food';

  // Переменная для своих продуктов
  List<UserProduct> _userProducts = [];

  List<_DishSource> get _allDishes {
    final list = <_DishSource>[];

    for (final r in widget.allRecipes) {
      list.add(
        _DishSource(
          id: r.id,
          title: r.title,
          kcal100: r.kcal100,
          protein100: r.protein100,
          fat100: r.fat100,
          carb100: r.carb100,
        ),
      );
    }

    final mealOptions = <MealOption>[
      ...marathonProgram.breakfasts,
      ...marathonProgram.snacks,
      ...marathonProgram.lunches,
      ...marathonProgram.dinners,
      ...marathonProgram.lateSnacks,
      ...marathonProgram.fastingDay,
    ];
    for (final m in mealOptions) {
      list.add(
        _DishSource(
          id: 'marathon_${m.id}',
          title: m.title,
          kcal100: m.kcal100.toDouble(),
          protein100: m.protein100.toDouble(),
          fat100: m.fat100.toDouble(),
          carb100: m.carb100.toDouble(),
          fromMarathon: true,
        ),
      );
    }

    for (final p in basicProducts) {
      list.add(
        _DishSource(
          id: 'product_${p.id}',
          title: p.title,
          kcal100: p.kcal.toDouble(),
          protein100: p.protein.toDouble(),
          fat100: p.fat.toDouble(),
          carb100: p.carb.toDouble(),
          isProduct: true,
        ),
      );
    }

    // ДОБАВЛЯЕМ СВОИ ПРОДУКТЫ СЮДА
    for (final p in _userProducts) {
      list.add(
        _DishSource(
          id: 'user_product_${p.id}',
          title: p.title,
          kcal100: p.kcal100,
          protein100: p.protein100,
          fat100: p.fat100,
          carb100: p.carb100,
          isProduct: true, // Чтобы в списке была иконка 🥕
        ),
      );
    }

    return list;
  }

  @override
  void initState() {
    super.initState();
    diaryVersionNotifier.addListener(_onDiaryChanged);
    _load();
    _loadUserProducts(); // <--- Загружаем продукты при старте
  }

  @override
  void dispose() {
    diaryVersionNotifier.removeListener(_onDiaryChanged);
    super.dispose();
  }

  void _onDiaryChanged() {
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final goal = await DiaryStorage.loadGoal();
    final entries = await DiaryStorage.loadDay(_date);
    final water = await DiaryStorage.loadWater(_date);
    final waterGoal = await DiaryStorage.loadWaterGoal();

    if (mounted) {
      setState(() {
        _goal = goal;
        _entries = entries;
        _waterMl = water;
        _waterGoal = waterGoal;
        _loading = false;
      });
    }
  }

  // Метод загрузки своих продуктов
  Future<void> _loadUserProducts() async {
    final products = await UserProductStorage.loadAll();
    if (mounted) setState(() => _userProducts = products);
  }

  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
  }

  void _shiftDay(int delta) {
    setState(() => _date = _date.add(Duration(days: delta)));
    _load();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1), // <--- Разрешаем будущее
      helpText: 'Выберите дату',
      cancelText: 'Отмена',
      confirmText: 'ОК',
      fieldLabelText: 'Дата',
      fieldHintText: 'дд.мм.гггг',
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
      _load();
    }
  }

  int get _totalKcal => _entries.fold(0, (s, e) => s + e.kcal);
  int get _totalProtein => _entries.fold(0, (s, e) => s + e.protein);
  int get _totalFat => _entries.fold(0, (s, e) => s + e.fat);
  int get _totalCarb => _entries.fold(0, (s, e) => s + e.carb);

  Future<void> _editGoal() async {
    final minController = TextEditingController(
      text: _goal?.min.toString() ?? '1700',
    );
    final maxController = TextEditingController(
      text: _goal?.max.toString() ?? '1900',
    );

    final result = await showDialog<CalorieGoal>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Коридор калорий'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Укажите нижнюю и верхнюю границу. Попадание в этот диапазон считается идеальным.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Мин',
                      suffixText: 'ккал',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: maxController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Макс',
                      suffixText: 'ккал',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final min = int.tryParse(minController.text.trim());
              final max = int.tryParse(maxController.text.trim());
              if (min != null && max != null && min > 0 && max > min) {
                Navigator.pop(ctx, CalorieGoal(min: min, max: max));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE07A5F),
              foregroundColor: Colors.white,
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result != null) {
      await DiaryStorage.saveGoal(result);
      setState(() => _goal = result);
    }
  }

  Future<void> _editWaterGoal() async {
    final controller = TextEditingController(text: _waterGoal.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Цель по воде'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(suffixText: 'мл', hintText: '2000'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              if (v != null && v > 0) Navigator.pop(ctx, v);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4FA8D1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result != null) {
      await DiaryStorage.saveWaterGoal(result);
      setState(() => _waterGoal = result);
    }
  }

  Future<void> _addWater(int amount) async {
    final newTotal = _waterMl + amount;
    setState(() => _waterMl = newTotal);
    await DiaryStorage.saveWater(_date, newTotal);
  }

  Future<void> _resetWater() async {
    setState(() => _waterMl = 0);
    await DiaryStorage.saveWater(_date, 0);
  }

  Future<void> _addDish(String mealType) async {
    final dish = await showModalBottomSheet<_DishSource>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DishPickerSheet(dishes: _allDishes),
    );
    if (dish == null || !mounted) return;

    final entry = await showModalBottomSheet<DiaryEntry>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WeightInputSheet(dish: dish, mealType: mealType),
    );
    if (entry == null || !mounted) return;

    setState(() => _entries = [..._entries, entry]);
    await DiaryStorage.saveDay(_date, _entries);
    notifyDiaryChanged();
  }

  Future<void> _removeEntry(DiaryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: Text(
          '${entry.title}\n${entry.weight} г · ${entry.kcal} ккал',
          style: TextStyle(color: AppColors.textSecondary(ctx)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: Color(0xFFD35E3F)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _entries = _entries.where((e) => e.id != entry.id).toList());
    await DiaryStorage.saveDay(_date, _entries);
    notifyDiaryChanged();
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
    final base = '${_date.day} ${months[_date.month - 1]}';
    return _date.year != now.year ? '$base ${_date.year}' : base;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        _buildDateSelector(),
        _buildTabSwitcher(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            children: [
              if (_activeTab == 'food') ...[
                _buildProgressCard(),
                const SizedBox(height: 16),
                ...MealType.all.map((type) => _buildMealSection(type)),
              ] else ...[
                _buildWaterTabContent(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _shiftDay(-1),
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Вчера',
          ),
          Expanded(
            child: InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isToday ? 'Сегодня' : _formatDate(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.calendar_month,
                          size: 18,
                          color: AppColors.textSecondary(context),
                        ),
                      ],
                    ),
                    if (_isToday)
                      Text(
                        _formatDate(),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _isToday ? null : () => _shiftDay(1),
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Завтра',
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.fieldBg(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTabButton('food', 'Питание', Icons.restaurant),
            ),
            Expanded(child: _buildTabButton('water', 'Вода', Icons.water_drop)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String type, String label, IconData icon) {
    final isActive = _activeTab == type;
    final activeColor = type == 'food'
        ? const Color(0xFFE07A5F)
        : const Color(0xFF4FA8D1);

    return GestureDetector(
      onTap: () => setState(() => _activeTab = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.white : AppColors.textSecondary(context),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isActive
                    ? Colors.white
                    : AppColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final kcal = _totalKcal;
    final min = _goal?.min ?? 0;
    final max = _goal?.max ?? 0;
    final hasGoal = min > 0 && max > 0;

    final progress = hasGoal ? (kcal / max).clamp(0.0, 1.0) : 0.0;

    String statusText = '';
    Color progressColor = Colors.white;
    Color barColor = Colors.white24;

    if (hasGoal) {
      if (kcal < min) {
        statusText = 'До нижней границы: ${min - kcal} ккал';
        progressColor = Colors.white70;
      } else if (kcal >= min && kcal <= max) {
        statusText = '✅ Вы в идеальном балансе!';
        progressColor = Colors.greenAccent;
      } else {
        statusText = '⚠️ Перебор на ${kcal - max} ккал';
        progressColor = Colors.redAccent;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: _accentGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hasGoal ? '🔥 $kcal / $min - $max ккал' : '🔥 $kcal ккал',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _editGoal,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Коридор',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
                backgroundColor: barColor,
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

  Widget _buildWaterTabContent() {
    final progress = _waterGoal > 0
        ? (_waterMl / _waterGoal).clamp(0.0, 1.0)
        : 0.0;
    final isDone = _waterMl >= _waterGoal;

    final glasses = (_waterMl / 200).floor();

    return Column(
      children: [
        const SizedBox(height: 20),
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 12,
                  backgroundColor: AppColors.isDark(context)
                      ? Colors.grey.shade800
                      : Colors.blue.shade50,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF4FA8D1),
                  ),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.water_drop,
                    size: 48,
                    color: const Color(0xFF4FA8D1).withValues(alpha: 0.5),
                  ),
                  Text(
                    '$_waterMl',
                    style: const TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4FA8D1),
                    ),
                  ),
                  Text(
                    'из $_waterGoal мл',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _waterButton('+ 100 мл', () => _addWater(100)),
              _waterButton('+ 200 мл', () => _addWater(200)),
              _waterButton('+ 300 мл', () => _addWater(300)),
              _waterButton('+ 500 мл', () => _addWater(500)),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _editWaterGoal,
              icon: const Icon(Icons.edit, size: 18, color: Color(0xFF4FA8D1)),
              label: const Text(
                'Изменить цель',
                style: TextStyle(color: Color(0xFF4FA8D1)),
              ),
            ),
            const SizedBox(width: 16),
            TextButton.icon(
              onPressed: _resetWater,
              icon: Icon(
                Icons.refresh,
                size: 18,
                color: AppColors.textSecondary(context),
              ),
              label: Text(
                'Сбросить',
                style: TextStyle(color: AppColors.textSecondary(context)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 30),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(context)),
          ),
          child: Column(
            children: [
              Text(
                isDone ? '🎉 Отличная работа!' : '💡 Полезно знать',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isDone
                    ? 'Вы выполнили норму воды на сегодня. Это отлично влияет на кожу, пищеварение и уровень энергии.'
                    : 'Вы выпили $_waterMl мл воды (это примерно $glasses ст.). Вода ускоряет метаболизм и помогает контролировать аппетит. Не забывайте пить небольшими порциями в течение дня.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _waterButton(String text, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4FA8D1),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
    final items = _entries.where((e) => e.mealType == type).toList();
    final totalKcal = items.fold(0, (s, e) => s + e.kcal);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.isDark(context)
                ? const Color.fromRGBO(0, 0, 0, 0.3)
                : const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  MealType.label(type),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const Spacer(),
                if (totalKcal > 0)
                  Text(
                    '$totalKcal ккал',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFC05A3F),
                    ),
                  ),
              ],
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 2),
                child: Text(
                  'Ещё ничего не добавлено',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              )
            else
              ...items.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.title,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.25,
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '${e.weight} г · Б ${e.protein} · Ж ${e.fat} · У ${e.carb}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${e.kcal} ккал',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeEntry(e),
                        icon: Icon(
                          Icons.close,
                          size: 14,
                          color: AppColors.textSecondary(context),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Удалить',
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _addDish(type),
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
                      'Добавить блюдо',
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
          ],
        ),
      ),
    );
  }
}

// ============ ШАГ 1: ВЫБОР БЛЮДА ============
class _DishPickerSheet extends StatefulWidget {
  final List<_DishSource> dishes;
  const _DishPickerSheet({required this.dishes});

  @override
  State<_DishPickerSheet> createState() => _DishPickerSheetState();
}

class _DishPickerSheetState extends State<_DishPickerSheet> {
  String _query = '';

  List<_DishSource> get _filtered {
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return widget.dishes;
    return widget.dishes
        .where((d) => d.title.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      'Выбрать блюдо',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: 'Закрыть',
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TextField(
                  autofocus: true,
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(color: AppColors.textPrimary(context)),
                  decoration: InputDecoration(
                    hintText: '🔍 Поиск блюда или продукта',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary(context),
                    ),
                    filled: true,
                    fillColor: AppColors.fieldBg(context),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFFE07A5F),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border(context)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border(context)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          Flexible(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Ничего не найдено 🔍',
                        style: TextStyle(
                          color: AppColors.textSecondary(context),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final d = filtered[i];
                      return InkWell(
                        onTap: () => Navigator.pop(context, d),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            d.title,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary(
                                                context,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (d.fromMarathon)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFF1EC),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              '🎯',
                                              style: TextStyle(fontSize: 11),
                                            ),
                                          ),
                                        if (d.isProduct)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEAF6F0),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              '🥕',
                                              style: TextStyle(fontSize: 11),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '🔥 ${_fmt(d.kcal100)} ккал/100г · Б ${_fmt(d.protein100)} · Ж ${_fmt(d.fat100)} · У ${_fmt(d.carb100)}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textSecondary(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: AppColors.textSecondary(context),
                                size: 20,
                              ),
                            ],
                          ),
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

// ============ ШАГ 2: ВВОД ВЕСА ============
class _WeightInputSheet extends StatefulWidget {
  final _DishSource dish;
  final String mealType;
  const _WeightInputSheet({required this.dish, required this.mealType});

  @override
  State<_WeightInputSheet> createState() => _WeightInputSheetState();
}

class _WeightInputSheetState extends State<_WeightInputSheet> {
  final _controller = TextEditingController(text: '100');

  @override
  void initState() {
    super.initState();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  int get _weight => int.tryParse(_controller.text.trim()) ?? 0;

  int get _kcal => (widget.dish.kcal100 * _weight / 100).round();
  int get _protein => (widget.dish.protein100 * _weight / 100).round();
  int get _fat => (widget.dish.fat100 * _weight / 100).round();
  int get _carb => (widget.dish.carb100 * _weight / 100).round();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final w = _weight;
    if (w <= 0) return;
    final entry = DiaryEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      mealType: widget.mealType,
      title: widget.dish.title,
      weight: w,
      kcal: _kcal,
      protein: _protein,
      fat: _fat,
      carb: _carb,
      addedAt: DateTime.now(),
    );
    Navigator.pop(context, entry);
  }

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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Text(
              widget.dish.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '🔥 ${_fmt(widget.dish.kcal100)} ккал/100г · Б ${_fmt(widget.dish.protein100)} · Ж ${_fmt(widget.dish.fat100)} · У ${_fmt(widget.dish.carb100)}',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Вес съеденного',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.fieldBg(context),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.border(context),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.border(context),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'г',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.isDark(context)
                    ? const Color(0xFF1A3A2A)
                    : const Color(0xFFEAF6F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Итого',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '🔥 $_kcal ккал',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3F8F6B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Б $_protein г · Ж $_fat г · У $_carb г',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: AppColors.border(context)),
                    ),
                    child: Text(
                      'Отмена',
                      style: TextStyle(color: AppColors.textPrimary(context)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _weight > 0 ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE07A5F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Добавить',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
