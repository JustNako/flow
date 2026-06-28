/// Модель привычки — соответствует HabitDto.cs на бэке.
///
/// Поля:
/// - id: серверный Guid
/// - title/description: текстовая информация
/// - targetDays: цель (сколько дней)
/// - completedDays: сколько уже выполнено
/// - repeatType: тип повторения (1=EveryDay, 2=SpecificDaysOfWeek, 3=SpecificDaysOfMonth, 4=XTimesPerPeriod)
/// - isDeleted: мягкое удаление (важно для синхронизации!)
/// - updatedAt: timestamp для разрешения конфликтов (Last-Write-Wins)
/// - isSynced: была ли отправлена на сервер
/// - localId: временный ID для новых привычек до синхронизации
library;

import 'dart:convert';

/// Соответствует enum HabitRepeatType на бэке
enum HabitRepeatType {
  everyDay,         // 1
  specificDaysOfWeek,  // 2
  specificDaysOfMonth, // 3
  xTimesPerPeriod,    // 4
}

/// Соответствует enum HabitRepeatPeriod на бэке
enum HabitRepeatPeriod {
  week,   // 1
  month,  // 2
}

HabitRepeatType _repeatTypeFromInt(int? v) {
  switch (v) {
    case 2: return HabitRepeatType.specificDaysOfWeek;
    case 3: return HabitRepeatType.specificDaysOfMonth;
    case 4: return HabitRepeatType.xTimesPerPeriod;
    default: return HabitRepeatType.everyDay;
  }
}

int _repeatTypeToInt(HabitRepeatType t) {
  switch (t) {
    case HabitRepeatType.everyDay: return 1;
    case HabitRepeatType.specificDaysOfWeek: return 2;
    case HabitRepeatType.specificDaysOfMonth: return 3;
    case HabitRepeatType.xTimesPerPeriod: return 4;
  }
}

HabitRepeatPeriod? _repeatPeriodFromInt(int? v) {
  switch (v) {
    case 1: return HabitRepeatPeriod.week;
    case 2: return HabitRepeatPeriod.month;
    default: return null;
  }
}

int? _repeatPeriodToInt(HabitRepeatPeriod? p) {
  switch (p) {
    case HabitRepeatPeriod.week: return 1;
    case HabitRepeatPeriod.month: return 2;
    default: return null;
  }
}

class Habit {
  final String? id;
  final String? userId;
  final String title;
  final String? description;
  final int targetDays;
  final String? unit;
  final int completedDays;
  final HabitRepeatType repeatType;
  final List<int>? repeatDaysOfWeek;   // DayOfWeek int values (0=Sun...6=Sat)
  final List<int>? repeatDaysOfMonth;  // 1-31
  final int? repeatTimesPerPeriod;
  final HabitRepeatPeriod? repeatPeriod;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final String? localId;
  final bool isSynced;
  final bool isCompletedToday;
  final bool isPublic;
  final String? notes;
  final String? timeOfDay;
  final int currentStreak;
  final int completionRate30Day;
  final int iconIndex; // Index into the icon picker list (0 = water drop, 1 = workout, etc.)

  const Habit({
    this.id,
    this.userId,
    required this.title,
    this.description,
    this.targetDays = 0,
    this.unit,
    this.completedDays = 0,
    this.currentStreak = 0,
    this.completionRate30Day = 0,
    this.repeatType = HabitRepeatType.everyDay,
    this.repeatDaysOfWeek,
    this.repeatDaysOfMonth,
    this.repeatTimesPerPeriod,
    this.repeatPeriod,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.localId,
    this.isSynced = false,
    this.isCompletedToday = false,
    this.isPublic = true,
    this.notes,
    this.timeOfDay,
    this.iconIndex = 0,
  });

  // ─── Из JSON (ответ бэка: GET /habits или PULL) ─────────────────────────────

  factory Habit.fromJson(Map<String, dynamic> json) {
    return Habit(
      id: json['id']?.toString(),
      // userId нет в HabitDto, но есть в SyncHabitDto
      userId: json['userId']?.toString(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      targetDays: json['targetDays'] as int? ?? 0,
      unit: json['unit'] as String?,
      completedDays: json['completedDays'] as int? ?? 0,
      repeatType: _repeatTypeFromInt(json['repeatType'] as int?),
      repeatDaysOfWeek: _parseJsonList(json['repeatDaysOfWeek']),
      repeatDaysOfMonth: _parseJsonList(json['repeatDaysOfMonth']),
      repeatTimesPerPeriod: (json['repeatTimesPerPeriod'] as num?)?.toInt(),
      repeatPeriod: _repeatPeriodFromInt((json['repeatPeriod'] as num?)?.toInt()),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
      isDeleted: json['isDeleted'] as bool? ?? false,
      isSynced: true,
      isCompletedToday: json['isCompletedToday'] as bool? ?? false,
      isPublic: json['isPublic'] as bool? ?? true,
      notes: json['notes'] as String?,
      timeOfDay: json['timeOfDay'] as String?,
      currentStreak: json['currentStreak'] as int? ?? 0,
      completionRate30Day: json['completionRate30Day'] as int? ?? 0,
      iconIndex: json['iconIndex'] as int? ?? 0,
    );
  }

  // ─── В JSON (для PUSH на сервер) ────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'title': title,
    'description': description,
    'targetDays': targetDays,
    'unit': unit,
    'repeatType': _repeatTypeToInt(repeatType),
    'repeatDaysOfWeek': repeatDaysOfWeek,
    'repeatDaysOfMonth': repeatDaysOfMonth,
    'repeatTimesPerPeriod': repeatTimesPerPeriod,
    'repeatPeriod': _repeatPeriodToInt(repeatPeriod),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isDeleted': isDeleted,
    'isPublic': isPublic,
    'notes': notes,
    'timeOfDay': timeOfDay,
    'iconIndex': iconIndex,
  };

  // ─── Для локальной SQLite ───────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'title': title,
    'description': description,
    'targetDays': targetDays,
    'unit': unit,
    'completedDays': completedDays,
    'repeatType': _repeatTypeToInt(repeatType),
    'repeatDaysOfWeek': repeatDaysOfWeek?.join(','),
    'repeatDaysOfMonth': repeatDaysOfMonth?.join(','),
    'repeatTimesPerPeriod': repeatTimesPerPeriod,
    'repeatPeriod': _repeatPeriodToInt(repeatPeriod),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isDeleted': isDeleted ? 1 : 0,
    'localId': localId,
    'isSynced': isSynced ? 1 : 0,
    // NOTE: isCompletedToday & completionRate30Day are NOT in the DB schema;
    // they are computed at read-time from habit_logs.
    'isPublic': isPublic ? 1 : 0,
    'notes': notes,
    'timeOfDay': timeOfDay,
    'iconIndex': iconIndex,
  };

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'] as String?,
      userId: map['userId'] as String?,
      title: map['title'] as String? ?? '',
      description: map['description'] as String?,
      targetDays: map['targetDays'] as int? ?? 0,
      unit: map['unit'] as String?,
      completedDays: map['completedDays'] as int? ?? 0,
      repeatType: _repeatTypeFromInt(map['repeatType'] as int?),
      repeatDaysOfWeek: _parseCsvInts(map['repeatDaysOfWeek'] as String?),
      repeatDaysOfMonth: _parseCsvInts(map['repeatDaysOfMonth'] as String?),
      repeatTimesPerPeriod: map['repeatTimesPerPeriod'] as int?,
      repeatPeriod: _repeatPeriodFromInt(map['repeatPeriod'] as int?),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
      isDeleted: (map['isDeleted'] as int?) == 1,
      localId: map['localId'] as String?,
      isSynced: (map['isSynced'] as int?) == 1,
      isCompletedToday: (map['isCompletedToday'] as int?) == 1,
      isPublic: (map['isPublic'] as int?) != 0,
      notes: map['notes'] as String?,
      timeOfDay: map['timeOfDay'] as String?,
      currentStreak: map['currentStreak'] as int? ?? 0,
      completionRate30Day: map['completionRate30Day'] as int? ?? 0,
      iconIndex: map['iconIndex'] as int? ?? 0,
    );
  }

  Habit copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    int? targetDays,
    String? unit,
    int? completedDays,
    HabitRepeatType? repeatType,
    List<int>? repeatDaysOfWeek,
    List<int>? repeatDaysOfMonth,
    int? repeatTimesPerPeriod,
    HabitRepeatPeriod? repeatPeriod,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    String? localId,
    bool? isSynced,
    bool? isCompletedToday,
    bool? isPublic,
    String? notes,
    String? timeOfDay,
    int? currentStreak,
    int? completionRate30Day,
    int? iconIndex,
  }) {
    return Habit(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      targetDays: targetDays ?? this.targetDays,
      unit: unit ?? this.unit,
      completedDays: completedDays ?? this.completedDays,
      repeatType: repeatType ?? this.repeatType,
      repeatDaysOfWeek: repeatDaysOfWeek ?? this.repeatDaysOfWeek,
      repeatDaysOfMonth: repeatDaysOfMonth ?? this.repeatDaysOfMonth,
      repeatTimesPerPeriod: repeatTimesPerPeriod ?? this.repeatTimesPerPeriod,
      repeatPeriod: repeatPeriod ?? this.repeatPeriod,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      localId: localId ?? this.localId,
      isSynced: isSynced ?? this.isSynced,
      isCompletedToday: isCompletedToday ?? this.isCompletedToday,
      isPublic: isPublic ?? this.isPublic,
      notes: notes ?? this.notes,
      timeOfDay: timeOfDay ?? this.timeOfDay,
      currentStreak: currentStreak ?? this.currentStreak,
      completionRate30Day: completionRate30Day ?? this.completionRate30Day,
      iconIndex: iconIndex ?? this.iconIndex,
    );
  }

  // ─── Утилиты ────────────────────────────────────────────────────────────────

  static DateTime _parseDate(dynamic v) {
    if (v is String && v.isNotEmpty) return DateTime.parse(v);
    return DateTime.now();
  }

  static List<int>? _parseCsvInts(String? csv) {
    if (csv == null || csv.isEmpty) return null;
    return csv.split(',').map(int.parse).toList();
  }

  /// Handles both native JSON arrays AND string-encoded JSON arrays
  /// (e.g. the /sync/pull endpoint may return "[1,2,3]" instead of [1,2,3])
  static List<int>? _parseJsonList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((e) => (e as num).toInt()).toList();
    }
    if (value is String && value.isNotEmpty) {
      // Try JSON decode first
      try {
        final parsed = jsonDecode(value);
        if (parsed is List) return parsed.map((e) => (e as num).toInt()).toList();
      } catch (_) {}
      // Fall back to CSV (e.g. local DB stores "1,2,3")
      return _parseCsvInts(value);
    }
    return null;
  }

  /// Прогресс выполнения 0.0 … 1.0
  double get progress =>
      targetDays == 0 ? 0.0 : (completedDays / targetDays).clamp(0.0, 1.0);

  /// Текстовое описание расписания
  String get repeatLabel {
    switch (repeatType) {
      case HabitRepeatType.everyDay:
        return 'Every day';
      case HabitRepeatType.specificDaysOfWeek:
        const days = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
        final selected = repeatDaysOfWeek?.map((d) => days[d % 7]).join(', ') ?? '';
        return selected.isEmpty ? 'Specific days' : selected;
      case HabitRepeatType.specificDaysOfMonth:
        final daysStr = repeatDaysOfMonth?.map((d) => '$d').join(', ') ?? '';
        return daysStr.isEmpty ? 'Specific dates' : 'Each: $daysStr';
      case HabitRepeatType.xTimesPerPeriod:
        final period = repeatPeriod == HabitRepeatPeriod.week ? 'week' : 'month';
        return '${repeatTimesPerPeriod ?? '?'}x per $period';
    }
  }

  /// Проверяет, запланирована ли привычка на конкретную дату
  bool isScheduledFor(DateTime date) {
    switch (repeatType) {
      case HabitRepeatType.everyDay:
        return true;
      case HabitRepeatType.specificDaysOfWeek:
        final dow = date.weekday % 7; // Sun=0, Mon=1...
        return repeatDaysOfWeek?.contains(dow) ?? false;
      case HabitRepeatType.specificDaysOfMonth:
        return repeatDaysOfMonth?.contains(date.day) ?? false;
      case HabitRepeatType.xTimesPerPeriod:
        // Для x раз в период обычно показываем каждый день
        return true;
    }
  }
}
