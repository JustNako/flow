/// Модель логирования привычки (когда пользователь выполнил привычку)
///
/// Объяснение:
/// - habitId: к какой привычке относится этот лог
/// - date: когда была выполнена привычка (дата)
/// - isCompleted: выполнена ли привычка в эту дату
/// - note: заметка пользователя
/// - isDeleted: мягкое удаление
/// - updatedAt: когда последний раз изменялось (для разрешения конфликтов)
library;

class HabitLog {
  final String? id;
  final String habitId;
  final DateTime date;         // поле "date" в ответе бэка
  final bool isCompleted;
  final String? note;
  final bool isDeleted;
  final DateTime updatedAt;
  final bool isSynced;
  final String? localId;

  HabitLog({
    this.id,
    required this.habitId,
    required this.date,
    required this.isCompleted,
    this.note,
    this.isDeleted = false,
    required this.updatedAt,
    this.isSynced = false,
    this.localId,
  });

  /// Из JSON (с бэка — поле называется "date")
  factory HabitLog.fromJson(Map<String, dynamic> json) {
    return HabitLog(
      id: json['id']?.toString(),
      habitId: json['habitId']?.toString() ?? '',
      date: _parseDate(json['date']),
      isCompleted: json['isCompleted'] as bool? ?? false,
      note: json['note'] as String?,
      isDeleted: json['isDeleted'] as bool? ?? false,
      updatedAt: _parseDate(json['updatedAt']),
      isSynced: true,
    );
  }

  /// В JSON (для отправки на сервер)
  Map<String, dynamic> toJson() => {
    'id': id,
    'habitId': habitId,
    'date': date.toIso8601String(),
    'isCompleted': isCompleted,
    'note': note,
    'isDeleted': isDeleted,
    'updatedAt': updatedAt.toIso8601String(),
  };

  /// Для локальной БД
  Map<String, dynamic> toMap() => {
    'id': id,
    'habitId': habitId,
    'logDate': date.toIso8601String(), // таблица хранит как logDate
    'isCompleted': isCompleted ? 1 : 0,
    'note': note,
    'isDeleted': isDeleted ? 1 : 0,
    'updatedAt': updatedAt.toIso8601String(),
    'isSynced': isSynced ? 1 : 0,
    'localId': localId,
  };

  /// Из локальной БД
  factory HabitLog.fromMap(Map<String, dynamic> map) {
    return HabitLog(
      id: map['id'] as String?,
      habitId: map['habitId'] as String? ?? '',
      date: _parseDate(map['logDate']),
      isCompleted: (map['isCompleted'] as int?) == 1,
      note: map['note'] as String?,
      isDeleted: (map['isDeleted'] as int?) == 1,
      updatedAt: _parseDate(map['updatedAt']),
      isSynced: (map['isSynced'] as int?) == 1,
      localId: map['localId'] as String?,
    );
  }

  HabitLog copyWith({
    String? id,
    String? habitId,
    DateTime? date,
    bool? isCompleted,
    String? note,
    bool? isDeleted,
    DateTime? updatedAt,
    bool? isSynced,
    String? localId,
  }) {
    return HabitLog(
      id: id ?? this.id,
      habitId: habitId ?? this.habitId,
      date: date ?? this.date,
      isCompleted: isCompleted ?? this.isCompleted,
      note: note ?? this.note,
      isDeleted: isDeleted ?? this.isDeleted,
      updatedAt: updatedAt ?? this.updatedAt,
      isSynced: isSynced ?? this.isSynced,
      localId: localId ?? this.localId,
    );
  }

  static DateTime _parseDate(dynamic v) {
    if (v is String && v.isNotEmpty) return DateTime.parse(v);
    return DateTime.now();
  }
}
