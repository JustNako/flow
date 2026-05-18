class AiHabitDto {
  final String title;
  final String description;
  final String icon;
  final int repeatType;
  final int targetDays;
  final String? unit;
  final List<int>? repeatDaysOfWeek;
  final int? repeatTimesPerPeriod;
  final String? timeOfDay;

  AiHabitDto({
    required this.title,
    required this.description,
    required this.icon,
    required this.repeatType,
    required this.targetDays,
    this.unit,
    this.repeatDaysOfWeek,
    this.repeatTimesPerPeriod,
    this.timeOfDay,
  });

  factory AiHabitDto.fromJson(Map<String, dynamic> json) {
    return AiHabitDto(
      title: json['title'] ?? 'New Habit',
      description: json['description'] ?? '',
      icon: json['icon'] ?? 'task_alt',
      repeatType: _toInt(json['repeatType']),
      targetDays: _toInt(json['targetDays']),
      unit: json['unit'] as String?,
      repeatDaysOfWeek: (json['repeatDaysOfWeek'] as List<dynamic>?)
          ?.map((e) => _toInt(e))
          .toList(),
      repeatTimesPerPeriod: _toInt(json['repeatTimesPerPeriod']),
      timeOfDay: json['timeOfDay'] as String?,
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
