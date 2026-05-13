/// Модель для отслеживания операций, которые нужно синхронизировать
/// 
/// Объяснение:
/// Когда пользователь работает БЕЗ интернета, его операции сохраняются в эту таблицу.
/// После восстановления сети, все операции из очереди отправляются на сервер.
/// 
/// Типы операций:
/// - CREATE: создана новая привычка/лог
/// - UPDATE: изменена существующая привычка/лог  
/// - DELETE: удалена привычка/лог (мягкое удаление)
library;

enum SyncOperation { create, update, delete }

class SyncQueueItem {
  final String? id;
  final String entityType; // 'habit' или 'habitLog'
  final String entityId;
  final SyncOperation operation;
  final Map<String, dynamic> data; // JSON данные для отправки
  final DateTime createdAt;
  final bool isSynced;

  SyncQueueItem({
    this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.data,
    required this.createdAt,
    this.isSynced = false,
  });

  /// Для сохранения в БД
  Map<String, dynamic> toMap() => {
    'id': id,
    'entityType': entityType,
    'entityId': entityId,
    'operation': operation.toString().split('.').last, // 'create', 'update', 'delete'
    'data': data, // SQLite может хранить JSON как TEXT
    'createdAt': createdAt.toIso8601String(),
    'isSynced': isSynced ? 1 : 0,
  };

  /// Для загрузки из БД
  factory SyncQueueItem.fromMap(Map<String, dynamic> map) {
    final operationStr = map['operation'] as String? ?? 'create';
    final operation = SyncOperation.values.firstWhere(
      (e) => e.toString().split('.').last == operationStr,
      orElse: () => SyncOperation.create,
    );

    return SyncQueueItem(
      id: map['id'] as String?,
      entityType: map['entityType'] as String? ?? '',
      entityId: map['entityId'] as String? ?? '',
      operation: operation,
      data: map['data'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(map['createdAt'] as String? ?? DateTime.now().toIso8601String()),
      isSynced: (map['isSynced'] as int?) == 1,
    );
  }
}
