import 'package:flutter/material.dart';
import '../models/diary.dart';
import '../services/diary_storage.dart';
import '../services/diary_events.dart';
import '../theme/app_colors.dart';

const _greenGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF2D6E4F), Color(0xFF3F8F6B)],
);

/// Показывает модалку «Добавить в дневник».
/// Принимает КБЖУ на 100 грамм (теперь дробные).
Future<bool> showAddToDiarySheet({
  required BuildContext context,
  required String title,
  required double kcal100,
  required double protein100,
  required double fat100,
  required double carb100,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddToDiarySheet(
      title: title,
      kcal100: kcal100,
      protein100: protein100,
      fat100: fat100,
      carb100: carb100,
    ),
  );
  return result ?? false;
}

class _AddToDiarySheet extends StatefulWidget {
  final String title;
  final double kcal100;
  final double protein100;
  final double fat100;
  final double carb100;

  const _AddToDiarySheet({
    required this.title,
    required this.kcal100,
    required this.protein100,
    required this.fat100,
    required this.carb100,
  });

  @override
  State<_AddToDiarySheet> createState() => _AddToDiarySheetState();
}

class _AddToDiarySheetState extends State<_AddToDiarySheet> {
  final _controller = TextEditingController(text: '100');
  String _mealType = MealType.breakfast;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _controller.text.length,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _weight => int.tryParse(_controller.text.trim()) ?? 0;

  // В дневник мы сохраняем целые числа (округляем),
  // чтобы не было "210.34 ккал" в списке.
  int get _portionKcal => (widget.kcal100 * _weight / 100).round();
  int get _portionProtein => (widget.protein100 * _weight / 100).round();
  int get _portionFat => (widget.fat100 * _weight / 100).round();
  int get _portionCarb => (widget.carb100 * _weight / 100).round();

  // Красивое отображение дробей (4.0 -> 4, 4.5 -> 4.5)
  String _format(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

  Future<void> _save() async {
    final w = _weight;
    if (w <= 0 || _saving) return;
    setState(() => _saving = true);

    final today = DateTime.now();
    final entries = await DiaryStorage.loadDay(today);

    final entry = DiaryEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      mealType: _mealType,
      title: widget.title,
      weight: w,
      kcal: _portionKcal,
      protein: _portionProtein,
      fat: _portionFat,
      carb: _portionCarb,
      addedAt: DateTime.now(),
    );

    entries.add(entry);
    await DiaryStorage.saveDay(today, entries);

    notifyDiaryChanged();

    if (mounted) Navigator.pop(context, true);
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
        child: SingleChildScrollView(
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
                widget.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '🔥 ${_format(widget.kcal100)} ккал/100г · Б ${_format(widget.protein100)} · Ж ${_format(widget.fat100)} · У ${_format(widget.carb100)}',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'В какой приём добавить?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: MealType.all.map((type) {
                  final active = _mealType == type;
                  return GestureDetector(
                    onTap: () => setState(() => _mealType = type),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: active ? _greenGradient : null,
                        color: active ? null : AppColors.fieldBg(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: active
                              ? const Color(0xFF3F8F6B)
                              : AppColors.border(context),
                        ),
                      ),
                      child: Text(
                        MealType.label(type),
                        style: TextStyle(
                          fontSize: 12.5,
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
                      '🔥 $_portionKcal ккал',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3F8F6B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Б $_portionProtein г · Ж $_portionFat г · У $_portionCarb г',
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
                      onPressed: _saving
                          ? null
                          : () => Navigator.pop(context, false),
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
                      onPressed: _weight > 0 && !_saving ? _save : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE07A5F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
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
      ),
    );
  }
}
