import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../theme/app_colors.dart';
import 'add_to_diary_sheet.dart';

class RecipeCard extends StatefulWidget {
  final Recipe recipe;
  final bool initiallyExpanded;
  final VoidCallback? onOpenInList;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const RecipeCard({
    super.key,
    required this.recipe,
    this.initiallyExpanded = false,
    this.onOpenInList,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<RecipeCard> createState() => _RecipeCardState();
}

class _RecipeCardState extends State<RecipeCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  void didUpdateWidget(RecipeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initiallyExpanded && !oldWidget.initiallyExpanded) {
      setState(() => _expanded = true);
    }
  }

  Future<void> _addToDiary() async {
    final r = widget.recipe;
    final added = await showAddToDiarySheet(
      context: context,
      title: r.title,
      kcal100: r.kcal100,
      protein100: r.protein100,
      fat100: r.fat100,
      carb100: r.carb100,
    );
    if (added && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавлено в дневник'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Красивое отображение дробей
  String _fmt(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.isDark(context)
                ? const Color.fromRGBO(0, 0, 0, 0.3)
                : const Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.title,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        if (r.description.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            r.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary(context),
                            ),
                          ),
                        ],
                        const SizedBox(height: 3),
                        Text(
                          '🔥 ${_fmt(r.kcal100)} ккал/100г · Б ${_fmt(r.protein100)} · Ж ${_fmt(r.fat100)} · У ${_fmt(r.carb100)}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Кнопка меню для своих рецептов
                  if (widget.onEdit != null || widget.onDelete != null)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: 20,
                        color: AppColors.textSecondary(context),
                      ),
                      onSelected: (val) {
                        if (val == 'edit') widget.onEdit?.call();
                        if (val == 'delete') widget.onDelete?.call();
                      },
                      itemBuilder: (ctx) => [
                        if (widget.onEdit != null)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Редактировать'),
                          ),
                        if (widget.onDelete != null)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Удалить',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),

                  // Кнопка добавления в дневник
                  IconButton(
                    onPressed: _addToDiary,
                    icon: const Icon(
                      Icons.add_circle_outline,
                      size: 20,
                      color: Color(0xFF3F8F6B),
                    ),
                    tooltip: 'Добавить в дневник',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),

                  // Кнопка "Открыть в списке" (для карточек в программах)
                  if (widget.onOpenInList != null)
                    IconButton(
                      onPressed: widget.onOpenInList,
                      icon: const Icon(
                        Icons.open_in_new,
                        size: 18,
                        color: Color(0xFF3F8F6B),
                      ),
                      tooltip: 'Открыть в списке рецептов',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                    ),

                  // Стрелочка
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFFE07A5F),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(height: 1, color: AppColors.border(context)),
                        const SizedBox(height: 10),

                        // Бейджи характеристик
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _badge(
                              '🔥 ${_fmt(r.kcal100)} ккал/100г',
                              const Color(0xFFFFF1EC),
                              const Color(0xFFD35E3F),
                            ),
                            _badge(
                              'Б ${_fmt(r.protein100)} г',
                              const Color(0xFFEAF6F0),
                              const Color(0xFF3F8F6B),
                            ),
                            _badge(
                              'Ж ${_fmt(r.fat100)} г',
                              const Color(0xFFFFF6E0),
                              const Color(0xFFB8860B),
                            ),
                            _badge(
                              'У ${_fmt(r.carb100)} г',
                              const Color(0xFFEAF0F8),
                              const Color(0xFF4A6FA5),
                            ),
                            if (r.fiber > 0)
                              _badge(
                                '🌾 ${r.fiber} г',
                                const Color(0xFFEAF6E5),
                                const Color(0xFF5A8F3F),
                              ),
                            if (r.timeMinutes > 0)
                              _badge(
                                r.noCook
                                    ? '🚫🍳 без готовки'
                                    : '⏱ ${r.timeMinutes} мин',
                                const Color(0xFFF0F0FF),
                                const Color(0xFF5555AA),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Теги
                        if (r.tags.isNotEmpty) ...[
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: r.tags
                                .map((t) => _tagChip(context, t))
                                .toList(),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Ингредиенты
                        _sectionTitle('Ингредиенты'),
                        const SizedBox(height: 6),
                        ...r.ingredients.map(
                          (i) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    i[0],
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textPrimary(context),
                                    ),
                                  ),
                                ),
                                Text(
                                  i[1],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Приготовление
                        _sectionTitle('Приготовление'),
                        const SizedBox(height: 6),
                        ...List.generate(
                          r.steps.length,
                          (idx) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFE07A5F),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '${idx + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      r.steps[idx],
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.35,
                                        color: AppColors.textPrimary(context),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Альтернативы
                        if (r.alternatives.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _sectionTitle('🔄 Альтернативы'),
                          const SizedBox(height: 6),
                          ...r.alternatives.map(
                            (a) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '• ',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF3F8F6B),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      a,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        height: 1.4,
                                        color: AppColors.textPrimary(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        // Предупреждение
                        if (r.warning != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE5E5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '⚠️ ',
                                  style: TextStyle(fontSize: 14),
                                ),
                                Expanded(
                                  child: Text(
                                    r.warning!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: Color(0xFFB33A3A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Польза
                        if (r.benefits != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF6F0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '💚 ',
                                  style: TextStyle(fontSize: 14),
                                ),
                                Expanded(
                                  child: Text(
                                    r.benefits!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: Color(0xFF3F6F5B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: Color(0xFFE07A5F),
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Widget _tagChip(BuildContext context, String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.isDark(context)
            ? const Color(0xFF2E2A26)
            : const Color(0xFFF5F0EA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 11,
          color: AppColors.isDark(context)
              ? const Color(0xFFC9B5A0)
              : const Color(0xFF8A6A55),
        ),
      ),
    );
  }
}
