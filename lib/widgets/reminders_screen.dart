import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart'; // <-- Новый импорт
import '../models/reminder.dart';
import '../services/reminder_storage.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import 'add_reminder_screen.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  List<Reminder> _reminders = [];
  bool _loading = true;
  bool _isBatteryOptimizationIgnored = true; // По умолчанию считаем, что все ок

  @override
  void initState() {
    super.initState();
    _loadReminders();
    _checkBatteryOptimization();
  }

  Future<void> _checkBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (mounted) {
      setState(() {
        _isBatteryOptimizationIgnored = status.isGranted;
      });
    }
  }

  Future<void> _requestBatteryOptimization() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    if (mounted) {
      setState(() {
        _isBatteryOptimizationIgnored = status.isGranted;
      });
    }
  }

  Future<void> _loadReminders() async {
    final list = await ReminderStorage.loadAll();
    if (mounted) {
      setState(() {
        _reminders = list;
        _loading = false;
      });
    }
  }

  Future<void> _openAddScreen({Reminder? existing}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddReminderScreen(existing: existing)),
    );

    if (result == true && mounted) {
      _loadReminders();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Напоминание сохранено!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleReminder(Reminder r, bool val) async {
    final index = _reminders.indexWhere((item) => item.id == r.id);
    if (index == -1) return;

    final updated = Reminder(
      id: r.id,
      title: r.title,
      hour: r.hour,
      minute: r.minute,
      daysOfWeek: r.daysOfWeek,
      isEnabled: val,
    );

    setState(() {
      _reminders[index] = updated;
    });

    await ReminderStorage.save(updated);

    try {
      if (val) {
        await NotificationService.scheduleReminder(updated);
      } else {
        await NotificationService.cancelReminder(updated.id);
      }
    } catch (e) {
      debugPrint('Ошибка обновления будильника: $e');
    }
  }

  Future<void> _deleteReminder(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить напоминание?'),
        content: Text('«$title» будет удалено безвозвратно.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _reminders.removeWhere((r) => r.id == id);
    });

    await ReminderStorage.delete(id);
    try {
      await NotificationService.cancelReminder(id);
    } catch (e) {
      debugPrint('Ошибка отмены будильника: $e');
    }
  }

  Future<void> _checkPendingNotifications() async {
    final pending = await NotificationService.getPendingNotifications();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('В системе: ${pending.length} будильников'),
        content: SizedBox(
          width: double.maxFinite,
          child: pending.isEmpty
              ? const Text(
                  'ПРИЛОЖЕНИЕ НЕ СМОГЛО ПОСТАВИТЬ БУДИЛЬНИКИ.\n\nПроблема в разрешениях Android или в ошибке кода.',
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: pending.length,
                  itemBuilder: (c, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'ID: ${pending[i].id}\nЗаголовок: ${pending[i].title}\nТекст: ${pending[i].body ?? "—"}',
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ОК'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Напоминания', style: TextStyle(color: Colors.white)),
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
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.white),
            tooltip: 'Проверить будильники в системе',
            onPressed: _checkPendingNotifications,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddScreen(),
        backgroundColor: const Color(0xFFE07A5F),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // --- ПРЕДУПРЕЖДАЮЩАЯ ПЛАШКА ---
                if (!_isBatteryOptimizationIgnored)
                  GestureDetector(
                    onTap: _requestBatteryOptimization,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.red,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Экономия батареи может блокировать напоминания. Нажмите сюда, чтобы разрешить работу в фоне.',
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // --- СПИСОК НАПОМИНАНИЙ ---
                Expanded(
                  child: _reminders.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '⏰',
                                style: TextStyle(
                                  fontSize: 64,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'У вас пока нет напоминаний',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Нажмите «+», чтобы добавить',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          itemCount: _reminders.length,
                          itemBuilder: (context, index) {
                            final r = _reminders[index];
                            return Card(
                              color: AppColors.cardBg(context),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                onTap: () => _openAddScreen(existing: r),
                                title: Text(
                                  r.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: r.isEnabled
                                        ? AppColors.textPrimary(context)
                                        : AppColors.textSecondary(context),
                                    decoration: r.isEnabled
                                        ? null
                                        : TextDecoration.lineThrough,
                                  ),
                                ),
                                subtitle: Text(
                                  '${r.timeString} ${r.daysOfWeek.isEmpty ? "· Каждый день" : "· По дням"}',
                                  style: TextStyle(
                                    color: AppColors.textSecondary(context),
                                    decoration: r.isEnabled
                                        ? null
                                        : TextDecoration.lineThrough,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          _deleteReminder(r.id, r.title),
                                    ),
                                    Switch(
                                      value: r.isEnabled,
                                      onChanged: (val) =>
                                          _toggleReminder(r, val),
                                      activeThumbColor: const Color(0xFF3F8F6B),
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
