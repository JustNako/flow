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

    // Миграция старых локальных записей, у которых ID был null
    await _migrateLegacyNullIds(_db!);
  }

  Future<void> _migrateLegacyNullIds(Database db) async {
    try {
      // 1. У привычек с null ID заменяем его на localId
      await db.rawUpdate('''
        UPDATE habits 
        SET id = localId 
        WHERE id IS NULL OR id = 'null' OR id = ''
      ''');

      // 2. У логов с null ID заменяем его на localId
      await db.rawUpdate('''
        UPDATE habit_logs 
        SET id = localId 
        WHERE id IS NULL OR id = 'null' OR id = ''
      ''');

      // 3. Удалить дублирующиеся логи за один день у одной привычки
      await db.rawUpdate('''
        UPDATE habit_logs
        SET isDeleted = 1
        WHERE rowid NOT IN (
          SELECT MIN(rowid) FROM habit_logs
          GROUP BY habitId, substr(logDate, 1, 10)
        )
        AND isDeleted = 0
      ''');

      // 4. Для привычек где localId = NULL, но уже есть строка с localId = id —
      //    физически удалить строку с NULL (это дубликат от PULL без localId)
      await db.rawDelete('''
        DELETE FROM habits
        WHERE localId IS NULL
          AND id IN (SELECT id FROM habits WHERE localId IS NOT NULL)
      ''');

      // 5. Если localId ещё NULL — заполнить его id, чтобы не было дублей в будущем
      await db.rawUpdate('''
        UPDATE habits SET localId = id WHERE localId IS NULL OR localId = ''
      ''');
      await db.rawUpdate('''
        UPDATE habit_logs SET localId = id WHERE localId IS NULL OR localId = ''
      ''');

      print('✅ SQLite: Миграция завершена (null IDs, дубликаты очищены)');
    } catch (e) {
      print('⚠️ SQLite: Ошибка миграции: $e');
    }
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

  /// Сохранить список привычек, полученных с сервера (с LWW-разрешением конфликтов)
  Future<void> savePulledHabits(List<Habit> habits) async {
    final batch = _db?.batch();
    if (batch == null) return;

    for (var pulled in habits) {
      final localList = await _db?.query(
        'habits',
        where: 'id = ? OR localId = ?',
        whereArgs: [pulled.id, pulled.localId],
      ) ?? [];

      if (localList.isNotEmpty) {
        final local = Habit.fromMap(localList.first);
        if (!local.isSynced) {
          if (local.updatedAt.isAfter(pulled.updatedAt) || local.updatedAt.isAtSameMomentAs(pulled.updatedAt)) {
            print('⚠️ Sync PULL: local habit "${pulled.title}" is newer or same as server copy. Keeping local.');
            continue;
          }
        }
      }

      batch.insert(
        'habits',
        pulled.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Пометить привычки как синхронизированные (только если updatedAt не изменился во время push-запроса)
  Future<void> markHabitsAsSynced(List<Habit> habits) async {
    final batch = _db?.batch();
    if (batch == null) return;
    for (var habit in habits) {
      batch.rawUpdate(
        'UPDATE habits SET isSynced = 1 WHERE localId = ? AND updatedAt = ?',
        [habit.localId, habit.updatedAt.toIso8601String()],
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

  /// Получить одну привычку по ID (ищет по id и по localId)
  Future<Habit?> getHabit(String id) async {
    final result = await _db?.query(
      'habits',
      where: 'id = ? OR localId = ?',
      whereArgs: [id, id],
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

  /// Полное физическое удаление привычки (для операций синхронизации)
  Future<void> hardDeleteHabit(String localId) async {
    await _db?.delete(
      'habits',
      where: 'localId = ?',
      whereArgs: [localId],
    );
  }

  /// Получить привычки с обогащением статуса выполнения из habit_logs
  /// isCompletedToday вычисляется из логов, а не хранится в таблице habits
  Future<List<Habit>> getHabitsWithCompletionStatus(String userId) async {
    final habits = await getHabits(userId);
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    final enriched = <Habit>[];
    for (final habit in habits) {
      final id = habit.id ?? '';
      final localId = habit.localId ?? '';
      if (id.isEmpty && localId.isEmpty) {
        enriched.add(habit);
        continue;
      }

      // Fetch all completed, non-deleted logs for this habit
      final logsList = await _db?.query(
        'habit_logs',
        where: '(habitId = ? OR habitId = ?) AND isCompleted = 1 AND isDeleted = 0',
        whereArgs: [id, localId],
      ) ?? [];

      final completedLogs = logsList.map((e) => HabitLog.fromMap(e)).toList();

      // Convert all logs dates to local timezone and get unique local days
      final localLogDays = completedLogs
          .map((l) => l.date.toLocal())
          .map((d) => DateTime(d.year, d.month, d.day))
          .toSet()
          .toList()
        ..sort((a, b) => b.compareTo(a));

      final isCompletedToday = localLogDays.contains(todayDay);
      final completedDays = localLogDays.length;

      int currentStreak = 0;
      if (localLogDays.isNotEmpty) {
        DateTime checkDate = todayDay;
        // If today not completed, start streak check from yesterday
        if (!isCompletedToday) {
          checkDate = todayDay.subtract(const Duration(days: 1));
        }
        for (final logDay in localLogDays) {
          if (logDay == checkDate) {
            currentStreak++;
            checkDate = checkDate.subtract(const Duration(days: 1));
          } else if (logDay.isBefore(checkDate)) {
            break;
          }
        }
      }

      enriched.add(habit.copyWith(
        isCompletedToday: isCompletedToday,
        completedDays: completedDays,
        currentStreak: currentStreak,
      ));
    }
    return enriched;
  }

  /// Обогатить список привычек только флагом isCompletedToday из локальных логов.
  /// Не перезаписывает currentStreak / completedDays — используется когда
  /// сервер уже вернул актуальные значения и перетирать их не нужно.
  Future<List<Habit>> enrichIsCompletedToday(List<Habit> habits) async {
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final enriched = <Habit>[];
    for (final habit in habits) {
      final id = habit.id ?? '';
      final localId = habit.localId ?? '';
      if (id.isEmpty && localId.isEmpty) {
        enriched.add(habit);
        continue;
      }

      final todayLog = await _db?.query(
        'habit_logs',
        where: '(habitId = ? OR habitId = ?) AND logDate LIKE ? AND isCompleted = 1 AND isDeleted = 0',
        whereArgs: [id, localId, '$todayStr%'],
      );
      final isCompletedToday = (todayLog?.isNotEmpty ?? false);

      enriched.add(habit.copyWith(isCompletedToday: isCompletedToday));
    }
    return enriched;
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

  /// Сохранить список логов привычек, полученных с сервера (с LWW-разрешением конфликтов)
  Future<void> savePulledHabitLogs(List<HabitLog> logs) async {
    final batch = _db?.batch();
    if (batch == null) return;

    for (var pulled in logs) {
      final localList = await _db?.query(
        'habit_logs',
        where: 'id = ? OR localId = ?',
        whereArgs: [pulled.id, pulled.localId],
      ) ?? [];

      if (localList.isNotEmpty) {
        final local = HabitLog.fromMap(localList.first);
        if (!local.isSynced) {
          if (local.updatedAt.isAfter(pulled.updatedAt) || local.updatedAt.isAtSameMomentAs(pulled.updatedAt)) {
            print('⚠️ Sync PULL: local habit log is newer or same as server copy. Keeping local.');
            continue;
          }
        }
      }

      batch.insert(
        'habit_logs',
        pulled.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Пометить логи как синхронизированные (только если updatedAt не изменился во время push-запроса)
  Future<void> markHabitLogsAsSynced(List<HabitLog> logs) async {
    final batch = _db?.batch();
    if (batch == null) return;
    for (var log in logs) {
      batch.rawUpdate(
        'UPDATE habit_logs SET isSynced = 1 WHERE localId = ? AND updatedAt = ?',
        [log.localId, log.updatedAt.toIso8601String()],
      );
    }
    await batch.commit(noResult: true);
  }

  /// Обновить habitId во всех логах (нужно при синхронизации новой привычки)
  Future<void> updateHabitIdForLogs(String oldHabitId, String newHabitId) async {
    await _db?.rawUpdate(
      'UPDATE habit_logs SET habitId = ? WHERE habitId = ?',
      [newHabitId, oldHabitId],
    );
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

  /// Получить все логи для привычки по обоим идентификаторам (server ID и local ID).
  /// Используется для офлайн-статистики, чтобы не пропустить логи с любым из ключей.
  Future<List<HabitLog>> getHabitLogsByHabitIds(String habitId, String? habitLocalId) async {
    if (habitLocalId == null || habitLocalId == habitId) {
      return getHabitLogs(habitId);
    }
    final result = await _db?.query(
      'habit_logs',
      where: 'habitId = ? OR habitId = ?',
      whereArgs: [habitId, habitLocalId],
      orderBy: 'logDate DESC, updatedAt DESC',
    ) ?? [];

    return result.map((e) => HabitLog.fromMap(e)).toList();
  }

  /// Получить все выполненные, неудаленные логи пользователя, соединяя с активными привычками.
  Future<List<Map<String, dynamic>>> getCompletedLogsForUser(String userId) async {
    final result = await _db?.rawQuery('''
      SELECT 
        CASE 
          WHEN h.id IS NOT NULL AND h.id != '' AND h.id != 'null' THEN h.id 
          ELSE h.localId 
        END as habitKey,
        l.logDate
      FROM habit_logs l
      INNER JOIN habits h ON (l.habitId = h.id OR l.habitId = h.localId)
      WHERE h.userId = ? 
        AND l.isCompleted = 1 
        AND l.isDeleted = 0 
        AND h.isDeleted = 0
    ''', [userId]) ?? [];
    return result;
  }

  /// Получить лог за конкретную дату (ищет и по id и по localId привычки)
  Future<HabitLog?> getHabitLogForDate(String habitId, DateTime date, {String? habitLocalId}) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final altId = habitLocalId ?? habitId;

    final result = await _db?.query(
      'habit_logs',
      where: '(habitId = ? OR habitId = ?) AND logDate LIKE ? AND isDeleted = 0',
      whereArgs: [habitId, altId, '$dateStr%'],
      orderBy: 'updatedAt DESC',
    ) ?? [];

    if (result.isEmpty) return null;
    return HabitLog.fromMap(result.first);
  }

  /// Обновить статус ВСЕХ дублирующихся логов за эту дату (исправляет дубликаты)
  Future<void> updateAllLogsForHabitAndDate(String habitId, String? habitLocalId, DateTime date, bool isCompleted) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final altId = habitLocalId ?? habitId;
    final now = DateTime.now().toIso8601String();

    await _db?.rawUpdate(
      '''UPDATE habit_logs 
         SET isCompleted = ?, updatedAt = ?, isSynced = 0 
         WHERE (habitId = ? OR habitId = ?) AND logDate LIKE ? AND isDeleted = 0''',
      [isCompleted ? 1 : 0, now, habitId, altId, '$dateStr%'],
    );
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

  /// Полная очистка локальной базы данных (при выходе из аккаунта)
  Future<void> wipe() async {
    await _db?.delete('habits');
    await _db?.delete('habit_logs');
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
