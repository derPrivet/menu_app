import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/diary.dart';
import '../services/profile_storage.dart';
import '../services/diary_storage.dart';
import '../services/diary_events.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _ageCtrl;
  late TextEditingController _heightCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _targetWeightCtrl;

  String _gender = 'female';
  String _activity = 'light';
  String _formula = 'mifflin';
  String _goal = 'lose';

  bool _loading = true;
  bool _calculating = false;

  int? _calcMin;
  int? _calcMax;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _ageCtrl = TextEditingController();
    _heightCtrl = TextEditingController();
    _weightCtrl = TextEditingController();
    _targetWeightCtrl = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _targetWeightCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileStorage.loadProfile();
    if (mounted) {
      setState(() {
        _nameCtrl.text = profile.name;
        _gender = profile.gender;
        _ageCtrl.text = profile.age.toString();
        _heightCtrl.text = profile.height.toStringAsFixed(0);
        _weightCtrl.text = profile.weight.toStringAsFixed(1);
        _targetWeightCtrl.text = profile.targetWeight.toStringAsFixed(1);
        _activity = profile.activityLevel;
        _formula = profile.formula;
        _goal = profile.goal;
        _loading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final profile = UserProfile(
      name: _nameCtrl.text.trim(),
      gender: _gender,
      age: int.tryParse(_ageCtrl.text) ?? 30,
      height: double.tryParse(_heightCtrl.text.replaceAll(',', '.')) ?? 165,
      weight: double.tryParse(_weightCtrl.text.replaceAll(',', '.')) ?? 65,
      targetWeight:
          double.tryParse(_targetWeightCtrl.text.replaceAll(',', '.')) ?? 60,
      activityLevel: _activity,
      formula: _formula,
      goal: _goal,
    );

    await ProfileStorage.saveProfile(profile);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Профиль сохранен!'),
          backgroundColor: Color(0xFF3F8F6B),
        ),
      );
    }
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _calculating = true);

    final weight = double.tryParse(_weightCtrl.text.replaceAll(',', '.')) ?? 65;
    final height =
        double.tryParse(_heightCtrl.text.replaceAll(',', '.')) ?? 165;
    final age = int.tryParse(_ageCtrl.text) ?? 30;

    double bmr = 0;
    if (_formula == 'mifflin') {
      if (_gender == 'male') {
        bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
      } else {
        bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
      }
    } else {
      if (_gender == 'male') {
        bmr = 88.36 + (13.4 * weight) + (4.8 * height) - (5.7 * age);
      } else {
        bmr = 447.6 + (9.2 * weight) + (3.1 * height) - (4.3 * age);
      }
    }

    double tdee = 0;
    switch (_activity) {
      case 'sedentary':
        tdee = bmr * 1.2;
        break;
      case 'light':
        tdee = bmr * 1.375;
        break;
      case 'moderate':
        tdee = bmr * 1.55;
        break;
      case 'high':
        tdee = bmr * 1.725;
        break;
    }

    int min, max;
    if (_goal == 'lose') {
      min = (tdee * 0.8).round();
      max = (tdee * 0.85).round();
    } else if (_goal == 'maintain') {
      min = (tdee * 0.95).round();
      max = (tdee * 1.05).round();
    } else {
      min = (tdee * 1.1).round();
      max = (tdee * 1.15).round();
    }

    setState(() {
      _calcMin = min;
      _calcMax = max;
      _calculating = false;
    });

    _saveProfile();
  }

  Future<void> _applyGoalToDiary() async {
    if (_calcMin == null || _calcMax == null) return;

    await DiaryStorage.saveGoal(CalorieGoal(min: _calcMin!, max: _calcMax!));
    notifyDiaryChanged();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Коридор калорий добавлен в дневник!'),
          backgroundColor: Color(0xFFE07A5F),
        ),
      );
    }
  }

  // Вспомогательный метод для выделения текста при клике
  void _selectAll(TextEditingController controller) {
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    String goalLabel = _goal == 'lose'
        ? 'для похудения'
        : (_goal == 'maintain' ? 'для поддержания веса' : 'для набора массы');
    String goalEmoji = _goal == 'lose'
        ? '📉'
        : (_goal == 'maintain' ? '⚖️' : '📈');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Личные данные'),
            TextFormField(
              controller: _nameCtrl,
              onTap: () => _selectAll(_nameCtrl),
              decoration: const InputDecoration(
                labelText: 'Имя',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_gender),
                    initialValue: _gender,
                    decoration: const InputDecoration(
                      labelText: 'Пол',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'female', child: Text('Женский')),
                      DropdownMenuItem(value: 'male', child: Text('Мужской')),
                    ],
                    onChanged: (v) => setState(() => _gender = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _ageCtrl,
                    onTap: () => _selectAll(_ageCtrl),
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Возраст',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _heightCtrl,
                    onTap: () => _selectAll(_heightCtrl),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Рост (см)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _weightCtrl,
                    onTap: () => _selectAll(_weightCtrl),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Вес (кг)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _buildSectionTitle('Цели и образ жизни'),
            DropdownButtonFormField<String>(
              key: ValueKey(_goal),
              initialValue: _goal,
              decoration: const InputDecoration(
                labelText: 'Ваша цель',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'lose', child: Text('📉 Похудение')),
                DropdownMenuItem(
                  value: 'maintain',
                  child: Text('⚖️ Поддержание веса'),
                ),
                DropdownMenuItem(value: 'gain', child: Text('📈 Набор массы')),
              ],
              onChanged: (v) => setState(() => _goal = v!),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              key: ValueKey(_activity),
              initialValue: _activity,
              decoration: const InputDecoration(
                labelText: 'Уровень активности',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'sedentary',
                  child: Text('Сидячий (офис, мало движения)'),
                ),
                DropdownMenuItem(
                  value: 'light',
                  child: Text('Небольшой (1-2 тренировки)'),
                ),
                DropdownMenuItem(
                  value: 'moderate',
                  child: Text('Средний (3-4 тренировки)'),
                ),
                DropdownMenuItem(
                  value: 'high',
                  child: Text('Высокий (ежедневный спорт)'),
                ),
              ],
              onChanged: (v) => setState(() => _activity = v!),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              key: ValueKey(_formula),
              initialValue: _formula,
              decoration: const InputDecoration(
                labelText: 'Формула расчета',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'mifflin',
                  child: Text('Миффлина-Сан Жеора (точнее)'),
                ),
                DropdownMenuItem(
                  value: 'harris',
                  child: Text('Харриса-Бенедикта (классика)'),
                ),
              ],
              onChanged: (v) => setState(() => _formula = v!),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _calculating ? null : _calculate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3F8F6B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _calculating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Рассчитать коридор',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _saveProfile,
                child: const Text('Просто сохранить профиль'),
              ),
            ),

            // --- БЛОК РЕЗУЛЬТАТА ---
            if (_calcMin != null && _calcMax != null) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                width: double
                    .infinity, // <-- Добавили, чтобы контейнер растягивался на всю ширину
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1EC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE07A5F)),
                ),
                child: Column(
                  children: [
                    Text(
                      '$goalEmoji Твой коридор $goalLabel:',
                      textAlign: TextAlign.center, // <-- ВЫРАВНИВАНИЕ ПО ЦЕНТРУ
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_calcMin – $_calcMax ккал',
                      textAlign: TextAlign.center, // <-- ВЫРАВНИВАНИЕ ПО ЦЕНТРУ
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC05A3F),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _applyGoalToDiary,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE07A5F),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Добавить в дневник'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF3F8F6B),
        ),
      ),
    );
  }
}
