import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/reminder.dart';
import '../services/reminder_storage.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

class AddReminderScreen extends StatefulWidget {
  final Reminder? existing;
  const AddReminderScreen({super.key, this.existing});

  @override
  State<AddReminderScreen> createState() => _AddReminderScreenState();
}

class _AddReminderScreenState extends State<AddReminderScreen> {
  final _titleCtrl = TextEditingController();
  TimeOfDay _time = TimeOfDay.now(); // <-- Теперь по умолчанию текущее время
  final Set<int> _selectedDays = {};
  bool _isSaving = false;

  // Переменная для шага минут
  int _minuteInterval = 1;
  final List<int> _stepOptions = [1, 5, 10, 15, 30];

  static const _dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final r = widget.existing!;
      _titleCtrl.text = r.title;
      _time = TimeOfDay(hour: r.hour, minute: r.minute);
      _selectedDays.addAll(r.daysOfWeek);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    // Устанавливаем время для барабана: либо текущее, либо выбранное ранее
    DateTime tempDate = DateTime(2026, 1, 1, _time.hour, _time.minute);

    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 320,
          color: AppColors.cardBg(context),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                    Text(
                      'Выберите время',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(
                        context,
                        TimeOfDay.fromDateTime(tempDate),
                      ),
                      child: const Text(
                        'Готово',
                        style: TextStyle(color: Color(0xFFE07A5F)),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: tempDate,
                  minuteInterval: _minuteInterval, // <-- Применяем шаг
                  onDateTimeChanged: (DateTime newDate) {
                    tempDate = newDate;
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите текст напоминания')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final reminder = Reminder(
      id:
          widget.existing?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleCtrl.text.trim(),
      hour: _time.hour,
      minute: _time.minute,
      daysOfWeek: _selectedDays.toList()..sort(),
      isEnabled: widget.existing?.isEnabled ?? true,
    );

    await ReminderStorage.save(reminder);

    try {
      await NotificationService.scheduleReminder(reminder);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ОШИБКА: $e'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.existing == null ? 'Новое напоминание' : 'Редактировать',
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
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
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
          Text(
            'О чем напомнить?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            maxLines: 2,
            style: TextStyle(color: AppColors.textPrimary(context)),
            decoration: InputDecoration(
              hintText: 'Например: Выпить 0,5 л воды',
              hintStyle: TextStyle(color: AppColors.textSecondary(context)),
              filled: true,
              fillColor: AppColors.fieldBg(context),
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
          const SizedBox(height: 24),

          Text(
            'Время',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: _pickTime,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.fieldBg(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Color(0xFFE07A5F)),
                  const SizedBox(width: 12),
                  Text(
                    '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Выбор шага минут
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Шаг минут:',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
              const SizedBox(width: 8),
              ...(_stepOptions.map((step) {
                final isSelected = _minuteInterval == step;
                return GestureDetector(
                  onTap: () => setState(() => _minuteInterval = step),
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF3F8F6B)
                          : AppColors.fieldBg(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF3F8F6B)
                            : AppColors.border(context),
                      ),
                    ),
                    child: Text(
                      '$step',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                );
              }).toList()),
            ],
          ),

          const SizedBox(height: 24),
          Text(
            'Дни недели (если не выбрано — каждый день)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (index) {
              final dayNum = index + 1;
              final isSelected = _selectedDays.contains(dayNum);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedDays.remove(dayNum);
                    } else {
                      _selectedDays.add(dayNum);
                    }
                  });
                },
                child: Container(
                  width: 45,
                  height: 45,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF2D6E4F), Color(0xFF3F8F6B)],
                          )
                        : null,
                    color: isSelected ? null : AppColors.fieldBg(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF3F8F6B)
                          : AppColors.border(context),
                    ),
                  ),
                  child: Text(
                    _dayNames[index],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary(context),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
