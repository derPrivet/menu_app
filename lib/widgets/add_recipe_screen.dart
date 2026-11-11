import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Для фильтрации ввода
import '../models/recipe.dart';
import '../services/user_recipe_storage.dart';
import '../theme/app_colors.dart';

class AddRecipeScreen extends StatefulWidget {
  final Recipe? existing;
  const AddRecipeScreen({super.key, this.existing});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _kcalCtrl = TextEditingController();
  final _proteinCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _carbCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();

  String _category = 'breakfast';
  final List<TextEditingController> _ingNameCtrls = [];
  final List<TextEditingController> _ingQtyCtrls = [];
  final List<TextEditingController> _stepCtrls = [];

  static const _categories = [
    ['breakfast', '🌅 Завтрак'],
    ['lunch', '🍲 Обед'],
    ['dinner', '🌙 Ужин'],
    ['snack', '🥜 Перекус'],
    ['dessert', '🍰 Десерт'],
    ['drink', '🥤 Напиток'],
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final r = widget.existing!;
      _titleCtrl.text = r.title;
      _descCtrl.text = r.description;
      // Убираем .0 у целых чисел при редактировании, чтобы не было "560.0"
      _kcalCtrl.text = _formatForInput(r.kcal100);
      _proteinCtrl.text = _formatForInput(r.protein100);
      _fatCtrl.text = _formatForInput(r.fat100);
      _carbCtrl.text = _formatForInput(r.carb100);
      _timeCtrl.text = r.timeMinutes > 0 ? r.timeMinutes.toString() : '';
      _category = r.category;
      for (var i = 0; i < r.ingredients.length; i++) {
        _ingNameCtrls.add(TextEditingController(text: r.ingredients[i][0]));
        _ingQtyCtrls.add(
          TextEditingController(
            text: r.ingredients[i].length > 1 ? r.ingredients[i][1] : '',
          ),
        );
      }
      for (var s in r.steps) {
        _stepCtrls.add(TextEditingController(text: s));
      }
    }
    if (_ingNameCtrls.isEmpty) _addIngredientField();
    if (_stepCtrls.isEmpty) _addStepField();
  }

  String _formatForInput(double val) {
    if (val == 0) return '';
    // Если число целое (например 560.0), выводим "560", иначе "4.5"
    return val % 1 == 0 ? val.toInt().toString() : val.toString();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _kcalCtrl.dispose();
    _proteinCtrl.dispose();
    _fatCtrl.dispose();
    _carbCtrl.dispose();
    _timeCtrl.dispose();
    for (var c in _ingNameCtrls) {
      c.dispose();
    }
    for (var c in _ingQtyCtrls) {
      c.dispose();
    }
    for (var c in _stepCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addIngredientField() {
    setState(() {
      _ingNameCtrls.add(TextEditingController());
      _ingQtyCtrls.add(TextEditingController());
    });
  }

  void _removeIngredientField(int index) {
    setState(() {
      _ingNameCtrls[index].dispose();
      _ingQtyCtrls[index].dispose();
      _ingNameCtrls.removeAt(index);
      _ingQtyCtrls.removeAt(index);
    });
  }

  void _addStepField() {
    setState(() {
      _stepCtrls.add(TextEditingController());
    });
  }

  void _removeStepField(int index) {
    setState(() {
      _stepCtrls[index].dispose();
      _stepCtrls.removeAt(index);
    });
  }

  // Парсер дробей (понимает и точку, и запятую)
  double _parseDouble(String text) {
    final normalized = text.trim().replaceAll(',', '.');
    return double.tryParse(normalized) ?? 0.0;
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите название рецепта')));
      return;
    }

    final ingredients = <List<String>>[];
    for (var i = 0; i < _ingNameCtrls.length; i++) {
      final name = _ingNameCtrls[i].text.trim();
      if (name.isNotEmpty) {
        ingredients.add([name, _ingQtyCtrls[i].text.trim()]);
      }
    }
    if (ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы один ингредиент')),
      );
      return;
    }

    final steps = _stepCtrls
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final recipe = Recipe(
      id:
          widget.existing?.id ??
          'user_${DateTime.now().millisecondsSinceEpoch}',
      category: _category,
      title: title,
      description: _descCtrl.text.trim(),
      // СОХРАНЯЕМ БЕЗ ОКРУГЛЕНИЯ
      kcal100: _parseDouble(_kcalCtrl.text),
      protein100: _parseDouble(_proteinCtrl.text),
      fat100: _parseDouble(_fatCtrl.text),
      carb100: _parseDouble(_carbCtrl.text),
      timeMinutes: int.tryParse(_timeCtrl.text) ?? 0,
      ingredients: ingredients,
      steps: steps,
      isUserRecipe: true,
    );

    await UserRecipeStorage.save(recipe);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Новый рецепт' : 'Редактировать',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFD96A4F), Color(0xFFE07A5F), Color(0xFFF2A488)],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text(
              'Сохранить',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _label('Название *'),
          _field(_titleCtrl, hint: 'Бабушкины сырники'),
          const SizedBox(height: 16),
          _label('Описание'),
          _field(_descCtrl, hint: 'Кратко о блюде', maxLines: 2),
          const SizedBox(height: 16),
          _label('Категория'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _categories.map((c) {
              final active = _category == c[0];
              return GestureDetector(
                onTap: () => setState(() => _category = c[0]),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: active
                        ? const LinearGradient(
                            colors: [Color(0xFFC05A3F), Color(0xFFE07A5F)],
                          )
                        : null,
                    color: active ? null : AppColors.fieldBg(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active
                          ? const Color(0xFFE07A5F)
                          : AppColors.border(context),
                    ),
                  ),
                  child: Text(
                    c[1],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: active
                          ? Colors.white
                          : AppColors.textPrimary(context),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _label('Ингредиенты *'),
          ...List.generate(_ingNameCtrls.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _field(_ingNameCtrls[i], hint: 'Название'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _field(_ingQtyCtrls[i], hint: 'Кол-во'),
                  ),
                  IconButton(
                    onPressed: () => _removeIngredientField(i),
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.textSecondary(context),
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: _addIngredientField,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Добавить ингредиент'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF3F8F6B),
            ),
          ),
          const SizedBox(height: 16),
          _label('Приготовление'),
          ...List.generate(_stepCtrls.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, right: 8),
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE07A5F),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _field(
                      _stepCtrls[i],
                      hint: 'Описание шага',
                      maxLines: 3,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeStepField(i),
                    icon: const Icon(Icons.close, size: 18),
                    color: AppColors.textSecondary(context),
                  ),
                ],
              ),
            );
          }),
          TextButton.icon(
            onPressed: _addStepField,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Добавить шаг'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF3F8F6B),
            ),
          ),
          const SizedBox(height: 16),

          _label('КБЖУ на 100 г'),
          Row(
            children: [
              Expanded(child: _field(_kcalCtrl, hint: 'Ккал', isNumber: true)),
              const SizedBox(width: 8),
              Expanded(
                child: _field(_proteinCtrl, hint: 'Белки', isNumber: true),
              ),
              const SizedBox(width: 8),
              Expanded(child: _field(_fatCtrl, hint: 'Жиры', isNumber: true)),
              const SizedBox(width: 8),
              Expanded(
                child: _field(_carbCtrl, hint: 'Углев.', isNumber: true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _field(
                  _timeCtrl,
                  hint: 'Время готовки (мин)',
                  isNumber: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE07A5F),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Сохранить рецепт',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary(context),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c, {
    String? hint,
    int maxLines = 1,
    bool isNumber = false,
  }) {
    return TextField(
      controller: c,
      // Клавиатура с точкой/запятой
      keyboardType: isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      maxLines: maxLines,
      // Разрешаем вводить только цифры, точку и запятую
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
          : null,
      style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: AppColors.textSecondary(context),
          fontSize: 13,
        ),
        filled: true,
        fillColor: AppColors.fieldBg(context),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
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
    );
  }
}
