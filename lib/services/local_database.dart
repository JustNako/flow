import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/sync_queue_item.dart';

/// LocalDatabase Service
/// 
/// НАЗНАЧЕНИЕ:
/// - Управляет всеми CRUD операциями с локальной SQLite БД
/// - Изолирует работу с БД в одном месте (легче тестировать и менять)
/// - Предоставляет методы для чтения/записи Привычек, Логов и Очереди синхронизации
///
/// АРХИТЕКТУРА:
/// Когда приложение запускается:
/// 1. LocalDatabase.init() - создает/открывает БД
/// 2. Создаются таблицы (если их еще нет)
/// 3. Все операции идут через методы этого класса
/// 4. При синхронизации читаем неотправленные данные и отправляем на сервер

class LocalDatabase {
  static final LocalDatabase _instance = LocalDatabase._internal();
  static Database? _db;

  factory LocalDatabase() {
    return _instance;
  }

  LocalDatabase._internal();

  static LocalDatabase get instance => _instance;

  /// Инициализирует БД (вызвать в main.dart при старте приложения)
  Future<void> init() async {
    if (_db != null) return;

    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'habittracker.db');

    _db = await openDatabase(
      path,
      version: 6,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  /// Закрывает БД (на случай очистки ресурсов)
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Создание таблиц при первом запуске
  Future<void> _createTables(Database db, int version) async {
    // Таблица привычек
    await db.execute('''
      CREATE TABLE habits (
        id TEXT,
        userId TEXT,
        title TEXT NOT NULL,
        description TEXT,
        targetDays INTEGER DEFAULT 0,
        unit TEXT,
        completedDays INTEGER DEFAULT 0,
        repeatType INTEGER DEFAULT 1,
        repeatDaysOfWeek TEXT,
        repeatDaysOfMonth TEXT,
        repeatTimesPerPeriod INTEGER,
        repeatPeriod INTEGER,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isDeleted INTEGER DEFAULT 0,
        localId TEXT UNIQUE,
        isSynced INTEGER DEFAULT 0,
        isPublic INTEGER DEFAULT 1,
        notes TEXT,
        timeOfDay TEXT,
        PRIMARY KEY (id, localId)
      )
    ''');

    // Таблица логов привычек
    await db.execute('''
      CREATE TABLE habit_logs (
        id TEXT,
        habitId TEXT NOT NULL,
        logDate TEXT NOT NULL,
        isCompleted INTEGER NOT NULL,
        note TEXT,
        isDeleted INTEGER DEFAULT 0,
        updatedAt TEXT NOT NULL,
        isSynced INTEGER DEFAULT 0,
        localId TEXT UNIQUE,
        FOREIGN KEY (habitId) REFERENCES habits(id),
        PRIMARY KEY (id, localId)
      )
    ''');

    // Таблица очереди синхронизации (для офлайн операций)
    await db.execute('''
      CREATE TABLE sync_queue (
        id TEXT PRIMARY KEY,
        entityType TEXT NOT NULL,
        entityId TEXT NOT NULL,
        operation TEXT NOT NULL,
        data TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        isSynced INTEGER DEFAULT 0
      )
    ''');
  }

  /// Миграция БД при обновлении версии
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS habits');
      await db.execute('DROP TABLE IF EXISTS habit_logs');
      await _createTables(db, newVersion);
    } 
    
    if (oldVersion == 2) {
      await db.execute('ALTER TABLE habits ADD COLUMN isPublic INTEGER DEFAULT 1');
      oldVersion = 3;
    }

    if (oldVersion == 3) {
      await db.execute('ALTER TABLE habits ADD COLUMN notes TEXT');
      oldVersion = 4;
    }

    if (oldVersion == 4) {
      await db.execute('ALTER TABLE habits ADD COLUMN unit TEXT');
      oldVersion = 5;
    }

    if (oldVersion == 5) {
      await db.execute('ALTER TABLE habits ADD COLUMN timeOfDay TEXT');
    }
  }

  // ========== ОПЕРАЦИИ С ПРИВЫЧКАМИ ==========

  /// Сохранить привычку (create или update)
  Future<void> saveHabit(Habit habit) async {
    await _db?.insert(
      'habits',
      habit.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Сохранить список привычек (батч-запрос для оптимизации)
  Future<void> saveHabits(List<Habit> habits) async {
    final batch = _db?.batch();
    if (batch == null) return;
    for (var habit in habits) {
      batch.insert(
        'habits',
        habit.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Получить все привычки пользователя
  Future<List<Habit>> getHabits(String userId) async {
    final result = await _db?.query(
      'habits',
      where: 'userId = ? AND isDeleted = 0',
      whereArgs: [userId],
      orderBy: 'createdAt DESC',
    ) ?? [];

    return result.map((e) => Habit.fromMap(e)).toList();
  }

  /// Получить одну привычку по ID
  Future<Habit?> getHabit(String id) async {
    final result = await _db?.query(
      'habits',
      where: 'id = ?',
      whereArgs: [id],
    ) ?? [];

    if (result.isEmpty) return null;
    return Habit.fromMap(result.first);
  }

  /// Получить все несинхронизированные привычки
  Future<List<Habit>> getUnsyncedHabits() async {
    final result = await _db?.query(
      'habits',
      where: 'isSynced = 0',
    ) ?? [];

    return result.map((e) => Habit.fromMap(e)).toList();
  }

  /// Удалить привычку (мягкое удаление - только пометить как удаленную)
  Future<void> deleteHabit(String id) async {
    await _db?.update(
      'habits',
      {'isDeleted': 1, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== ОПЕРАЦИИ С ЛОГАМИ ПРИВЫЧЕК ==========

  /// Сохранить лог привычки
  Future<void> saveHabitLog(HabitLog log) async {
    await _db?.insert(
      'habit_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Сохранить список логов (батч-запрос для оптимизации)
  Future<void> saveHabitLogs(List<HabitLog> logs) async {
    final batch = _db?.batch();
    if (batch == null) return;
    for (var log in logs) {
      batch.insert(
        'habit_logs',
        log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Получить все логи для привычки
  Future<List<HabitLog>> getHabitLogs(String habitId) async {
    final result = await _db?.query(
      'habit_logs',
      where: 'habitId = ?',
      whereArgs: [habitId],
      orderBy: 'logDate DESC',
    ) ?? [];

    return result.map((e) => HabitLog.fromMap(e)).toList();
  }

  /// Получить лог за конкретную дату
  Future<HabitLog?> getHabitLogForDate(String habitId, DateTime date) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final result = await _db?.query(
      'habit_logs',
      where: 'habitId = ? AND logDate LIKE ?',
      whereArgs: [habitId, '$dateStr%'],
    ) ?? [];

    if (result.isEmpty) return null;
    return HabitLog.fromMap(result.first);
  }

  /// Получить все несинхронизированные логи
  Future<List<HabitLog>> getUnsyncedHabitLogs() async {
    final result = await _db?.query(
      'habit_logs',
      where: 'isSynced = 0',
    ) ?? [];

    return result.map((e) => HabitLog.fromMap(e)).toList();
  }

  // ========== ОПЕРАЦИИ С ОЧЕРЕДЬЮ СИНХРОНИЗАЦИИ ==========

  /// Добавить операцию в очередь (когда работаем без интернета)
  Future<void> addToSyncQueue(SyncQueueItem item) async {
    await _db?.insert(
      'sync_queue',
      {
        ...item.toMap(),
        'data': item.data, // Convert to JSON string if needed
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Получить все несинхронизированные операции
  Future<List<SyncQueueItem>> getUnsyncedQueue() async {
    final result = await _db?.query(
      'sync_queue',
      where: 'isSynced = 0',
      orderBy: 'createdAt ASC',
    ) ?? [];

    return result.map((e) => SyncQueueItem.fromMap(e)).toList();
  }

  /// Пометить операцию как синхронизированную
  Future<void> markSyncQueueItemAsSynced(String id) async {
    await _db?.update(
      'sync_queue',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Удалить из очереди (когда уже синхронизировано)
  Future<void> removeSyncQueueItem(String id) async {
    await _db?.delete(
      'sync_queue',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Очистить всю очередь (для тестирования)
  Future<void> clearSyncQueue() async {
    await _db?.delete('sync_queue');
  }

  // ========== УТИЛИТЫ ==========

  /// Получить статистику БД (только несинхронизированные данные)
  Future<Map<String, int>> getStats() async {
    final habitsCount = Sqflite.firstIntValue(await _db?.rawQuery('SELECT COUNT(*) FROM habits WHERE isSynced = 0') ?? []) ?? 0;
    final logsCount = Sqflite.firstIntValue(await _db?.rawQuery('SELECT COUNT(*) FROM habit_logs WHERE isSynced = 0') ?? []) ?? 0;
    final queueCount = Sqflite.firstIntValue(await _db?.rawQuery('SELECT COUNT(*) FROM sync_queue WHERE isSynced = 0') ?? []) ?? 0;

    return {
      'habits': habitsCount,
      'logs': logsCount,
      'queue': queueCount,
    };
  }
}
