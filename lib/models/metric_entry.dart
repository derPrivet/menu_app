class MetricEntry {
  final DateTime date;
  final String type; // 'weight' или 'sugar'
  final double value;

  MetricEntry({required this.date, required this.type, required this.value});

  Map<String, dynamic> toJson() {
    return {
      'date':
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'type': type,
      'value': value,
    };
  }

  factory MetricEntry.fromJson(Map<String, dynamic> json) {
    final dateParts = (json['date'] as String).split('-');
    return MetricEntry(
      date: DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
      ),
      type:
          json['type'] as String? ??
          'weight', // По умолчанию вес, для старых записей
      value: (json['value'] as num).toDouble(),
    );
  }
}
