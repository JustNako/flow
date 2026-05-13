class AiHabitDto {
  final String title;
  final String description;
  final String icon;
  final int repeatType;
  final int targetDays;
  final List<int>? repeatDaysOfWeek;
  final int? repeatTimesPerPeriod;

  AiHabitDto({
    required this.title,
    required this.description,
    required this.icon,
    required this.repeatType,
    required this.targetDays,
    this.repeatDaysOfWeek,
    this.repeatTimesPerPeriod,
  });

  factory AiHabitDto.fromJson(Map<String, dynamic> json) {
    return AiHabitDto(
      title: json['title'] ?? 'New Habit',
      description: json['description'] ?? '',
      icon: json['icon'] ?? 'task_alt',
      repeatType: _toInt(json['repeatType']),
      targetDays: _toInt(json['targetDays']),
      repeatDaysOfWeek: (json['repeatDaysOfWeek'] as List<dynamic>?)
          ?.map((e) => _toInt(e))
          .toList(),
      repeatTimesPerPeriod: _toInt(json['repeatTimesPerPeriod']),
    );
  }

  static int _toInt(dynamic val) {
    if (val == null) return 0;
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is String) return int.tryParse(val) ?? 0;
    return 0;
  }
}
