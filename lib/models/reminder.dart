class Reminder {
  final String id;
  final String title;
  final int hour;
  final int minute;
  final List<int> daysOfWeek; // 1 - Пн, 7 - Вс. Пустой список = каждый день
  final bool isEnabled;

  Reminder({
    required this.id,
    required this.title,
    required this.hour,
    required this.minute,
    required this.daysOfWeek,
    this.isEnabled = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'hour': hour,
    'minute': minute,
    'daysOfWeek': daysOfWeek,
    'isEnabled': isEnabled,
  };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
    id: json['id'] as String,
    title: json['title'] as String,
    hour: json['hour'] as int,
    minute: json['minute'] as int,
    daysOfWeek:
        (json['daysOfWeek'] as List?)?.map((e) => e as int).toList() ?? [],
    isEnabled: json['isEnabled'] as bool? ?? true,
  );

  // Удобный геттер для красивого отображения времени (например, "08:30")
  String get timeString =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
