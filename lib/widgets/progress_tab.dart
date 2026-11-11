import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/metric_entry.dart';
import '../services/metric_storage.dart';
import '../theme/app_colors.dart';

class ProgressTab extends StatefulWidget {
  const ProgressTab({super.key});

  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> {
  String _currentType = 'weight'; // 'weight' или 'sugar'
  final TextEditingController _valueController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  List<MetricEntry> _history = [];
  bool _isLoading = true;

  // Переменная для режима "только список"
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await MetricStorage.loadByType(_currentType);
    if (!mounted) return;
    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  void _switchType(String type) {
    if (_currentType == type) return;
    setState(() {
      _currentType = type;
      _valueController.clear();
      _selectedDate = DateTime.now();
    });
    _loadHistory();
  }

  void _shiftDate(int delta) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: delta));
    });
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveValue() async {
    final text = _valueController.text.trim().replaceAll(',', '.');
    final value = double.tryParse(text);

    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Пожалуйста, введите корректное значение для ${_getLabel()}',
          ),
        ),
      );
      return;
    }

    final entry = MetricEntry(
      date: _selectedDate,
      type: _currentType,
      value: value,
    );
    await MetricStorage.saveEntry(entry);

    _valueController.clear();
    setState(() {
      _selectedDate = DateTime.now();
    });
    await _loadHistory();

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_getLabel()} ${value.toStringAsFixed(1)} ${_getUnit()} за ${_formatDate(entry.date)} сохранен!',
          ),
          backgroundColor: const Color(0xFF3F8F6B),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteEntry(MetricEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: Text(
          'Удалить ${_getLabel().toLowerCase()} ${entry.value.toStringAsFixed(1)} за ${_formatDate(entry.date)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await MetricStorage.deleteEntry(entry.date, entry.type);
      await _loadHistory();

      if (!mounted) return;

      final messenger = ScaffoldMessenger.of(context);
      messenger.clearSnackBars();

      messenger.showSnackBar(
        SnackBar(
          content: Text('Запись за ${_formatDate(entry.date)} удалена'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'ОТМЕНА',
            onPressed: () async {
              if (!mounted) return;
              messenger.hideCurrentSnackBar();
              await MetricStorage.saveEntry(entry);
              await _loadHistory();
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Запись восстановлена'),
                    backgroundColor: Color(0xFF3F8F6B),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ),
      );

      Future.delayed(const Duration(seconds: 3), () {
        messenger.hideCurrentSnackBar();
      });
    }
  }

  String _getLabel() => _currentType == 'weight' ? 'Вес' : 'Сахар';
  String _getUnit() => _currentType == 'weight' ? 'кг' : 'ммоль/л';
  Color _getColor() => _currentType == 'weight'
      ? const Color(0xFF3F8F6B)
      : const Color(0xFFE07A5F);
  Color _getLightColor() => _currentType == 'weight'
      ? const Color(0xFFEAF6F0)
      : const Color(0xFFFFF1EC);

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  // УМНАЯ ФУНКЦИЯ РАСЧЕТА ШАГА
  double _calculateInterval(double min, double max) {
    double range = max - min;
    if (range <= 0) return 1;

    double roughInterval = range / 5;
    double magnitude = 1;
    while (roughInterval >= 10) {
      magnitude *= 10;
      roughInterval /= 10;
    }

    if (roughInterval <= 1.5) return 1 * magnitude;
    if (roughInterval <= 3.0) return 2 * magnitude;
    if (roughInterval <= 7.0) return 5 * magnitude;
    return 10 * magnitude;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          // === ПЕРЕКЛЮЧАТЕЛЬ (Вес / Сахар) ===
          // Скрываем, если включен режим полного экрана
          if (!_isFullScreen)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.fieldBg(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTabButton(
                        'weight',
                        'Вес',
                        Icons.monitor_weight,
                      ),
                    ),
                    Expanded(
                      child: _buildTabButton(
                        'sugar',
                        'Сахар',
                        Icons.water_drop,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // === БЛОК ВВОДА ===
          // Скрываем, если включен режим полного экрана
          if (!_isFullScreen)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              color: _getLightColor(),
              child: Column(
                children: [
                  // ПЛАШКА ДАТЫ СО СТРЕЛКАМИ
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => _shiftDate(-1),
                        icon: Icon(Icons.chevron_left, color: _getColor()),
                        tooltip: 'Предыдущий день',
                      ),
                      Expanded(
                        child: Builder(
                          builder: (context) {
                            final now = DateTime.now();
                            final isToday =
                                _selectedDate.year == now.year &&
                                _selectedDate.month == now.month &&
                                _selectedDate.day == now.day;
                            const months = [
                              'января',
                              'февраля',
                              'марта',
                              'апреля',
                              'мая',
                              'июня',
                              'июля',
                              'августа',
                              'сентября',
                              'октября',
                              'ноября',
                              'декабря',
                            ];
                            final dateStr =
                                '${_selectedDate.day} ${months[_selectedDate.month - 1]} ${_selectedDate.year}';

                            return InkWell(
                              onTap: _pickDate,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: _getColor().withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isToday ? Icons.today : Icons.history,
                                      size: 18,
                                      color: _getColor(),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isToday
                                          ? 'Сегодня, $dateStr'
                                          : 'Просмотр: $dateStr',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: _getColor(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.edit_calendar,
                                      size: 18,
                                      color: _getColor(),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      IconButton(
                        onPressed: () => _shiftDate(1),
                        icon: Icon(Icons.chevron_right, color: _getColor()),
                        tooltip: 'Следующий день',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Поле ввода
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _valueController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Ваш ${_getLabel().toLowerCase()} (например, ${_currentType == 'weight' ? '75.5' : '5.2'})',
                            suffixText: _getUnit(),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _getColor().withValues(alpha: 0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: _getColor().withValues(alpha: 0.3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _saveValue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _getColor(),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Сохранить',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // === ГРАФИК И СПИСОК ===
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _history.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.monitor_heart_outlined,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Пока нет записей по показателю "${_getLabel()}".\nВведите значение выше, чтобы начать!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      // График (скрывается, если включен режим полного экрана)
                      if (!_isFullScreen)
                        Expanded(
                          flex: 4,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              16.0,
                              16.0,
                              24.0,
                              0.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Динамика: ${_getLabel()}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _getColor(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: LineChart(
                                    LineChartData(
                                      gridData: const FlGridData(
                                        show: true,
                                        drawVerticalLine: false,
                                      ),
                                      titlesData: FlTitlesData(
                                        topTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        rightTitles: const AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: false,
                                          ),
                                        ),
                                        bottomTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            interval: 1,
                                            reservedSize: 30,
                                            getTitlesWidget: (value, meta) {
                                              final index = value.round();
                                              if ((value - index).abs() >
                                                  0.01) {
                                                return const SizedBox.shrink();
                                              }
                                              if (index < 0 ||
                                                  index >= _history.length) {
                                                return const SizedBox.shrink();
                                              }
                                              final date = _history[index].date;
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 6.0,
                                                ),
                                                child: Text(
                                                  '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        leftTitles: AxisTitles(
                                          sideTitles: SideTitles(
                                            showTitles: true,
                                            reservedSize: 48,
                                            interval: _calculateInterval(
                                              _getMinY(),
                                              _getMaxY(),
                                            ),
                                            getTitlesWidget: (value, meta) {
                                              if (value <= meta.min ||
                                                  value >= meta.max) {
                                                return const SizedBox.shrink();
                                              }
                                              String text = value >= 1000
                                                  ? value.toInt().toString()
                                                  : value.toStringAsFixed(1);
                                              return SideTitleWidget(
                                                axisSide: meta.axisSide,
                                                space: 6,
                                                child: Text(
                                                  text,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      borderData: FlBorderData(show: false),
                                      minX: -0.3,
                                      maxX: _history.length > 1
                                          ? (_history.length - 0.7)
                                          : 1.0,
                                      minY: _getMinY(),
                                      maxY: _getMaxY(),
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: _history.asMap().entries.map((
                                            e,
                                          ) {
                                            return FlSpot(
                                              e.key.toDouble(),
                                              e.value.value,
                                            );
                                          }).toList(),
                                          isCurved: false,
                                          color: _getColor(),
                                          barWidth: 3,
                                          isStrokeCapRound: true,
                                          dotData: FlDotData(
                                            show: true,
                                            getDotPainter:
                                                (
                                                  spot,
                                                  percent,
                                                  barData,
                                                  index,
                                                ) {
                                                  return FlDotCirclePainter(
                                                    radius: 5,
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                    strokeColor: _getColor(),
                                                  );
                                                },
                                          ),
                                          belowBarData: BarAreaData(
                                            show: true,
                                            color: _getColor().withValues(
                                              alpha: 0.1,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Список записей
                      Expanded(
                        flex: _isFullScreen ? 1 : 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.cardBg(context),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 6.0,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'История записей',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary(context),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          'Всего: ${_history.length}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary(
                                              context,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // КНОПКА РАЗВОРОТА НА ВЕСЬ ЭКРАН
                                        InkWell(
                                          onTap: () => setState(
                                            () =>
                                                _isFullScreen = !_isFullScreen,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getColor().withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  _isFullScreen
                                                      ? Icons.fullscreen_exit
                                                      : Icons.fullscreen,
                                                  color: _getColor(),
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _isFullScreen
                                                      ? 'Свернуть'
                                                      : 'Весь экран',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: _getColor(),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.only(bottom: 24.0),
                                  itemCount: _history.length,
                                  separatorBuilder: (context, index) => Divider(
                                    height: 1,
                                    color: AppColors.border(context),
                                    indent: 44,
                                    endIndent: 16,
                                  ),
                                  itemBuilder: (context, index) {
                                    final entry =
                                        _history[_history.length - 1 - index];

                                    return InkWell(
                                      onTap: () {},
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 12,
                                              backgroundColor: _getColor(),
                                              child: Icon(
                                                _currentType == 'weight'
                                                    ? Icons.monitor_weight
                                                    : Icons.water_drop,
                                                color: Colors.white,
                                                size: 12,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    '${entry.value.toStringAsFixed(1)} ${_getUnit()}',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  Text(
                                                    _formatDate(entry.date),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color:
                                                          AppColors.textSecondary(
                                                            context,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                                size: 18,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(
                                                minWidth: 28,
                                                minHeight: 28,
                                              ),
                                              onPressed: () =>
                                                  _deleteEntry(entry),
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
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String type, String label, IconData icon) {
    final isActive = _currentType == type;
    return GestureDetector(
      onTap: () => _switchType(type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? _getColor() : Colors.transparent,
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

  double _getMinY() {
    if (_history.isEmpty) return 0;
    final values = _history.map((e) => e.value).toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = max - min;
    final padding = range > 0
        ? range * 0.1
        : (_currentType == 'weight' ? 2.0 : 0.5);
    return (min - padding).toDouble();
  }

  double _getMaxY() {
    if (_history.isEmpty) return 100;
    final values = _history.map((e) => e.value).toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = max - min;
    final padding = range > 0
        ? range * 0.1
        : (_currentType == 'weight' ? 2.0 : 0.5);
    return (max + padding).toDouble();
  }
}
