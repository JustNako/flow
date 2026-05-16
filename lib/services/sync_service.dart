import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/habit.dart';
import '../models/habit_log.dart';
import './local_database.dart';
import './auth_service.dart';
import '../api/api_service.dart';

/// SyncService
/// 
/// НАЗНАЧЕНИЕ:
/// - Синхронизирует данные с C# бэком
/// - Использует /sync/pull для получения изменений
/// - Использует /sync/push для отправки локальных изменений
/// - Разрешает конфликты по "Last-Write-Wins" (как на бэке)
///
/// ПОТОК СИНХРОНИЗАЦИИ:
/// 1. PULL: запросить все изменения с сервера (с LastSyncTime)
/// 2. MERGE: объединить с локальными данными
/// 3. PUSH: отправить все локальные несинхронизированные данные
/// 4. CLEAN UP: удалить обработанные операции из очереди

class SyncService {
  static final SyncService _instance = SyncService._internal();
  
  factory SyncService() {
    return _instance;
  }

  SyncService._internal();

  static SyncService get instance => _instance;

  final _baseUrl = ApiService.baseUrl;
  final _db = LocalDatabase.instance;
  final _auth = AuthService.instance;
  bool _isSyncing = false;

  /// Главный метод синхронизации
  /// Вызывать это, когда восстановилось соединение с интернетом
  Future<bool> sync() async {
    if (_isSyncing) {
      print('⏳ Синхронизация уже запущена, пропуск...');
      return false;
    }

    try {
      _isSyncing = true;
      print('🔄 Начало синхронизации...');

      // 1. PULL - получить изменения с сервера
      await _pull();
      print('✅ PULL завершен');

      // 2. PUSH - отправить локальные изменения
      await _push();
      print('✅ PUSH завершен');

      print('🎉 Синхронизация успешна!');
      return true;
    } catch (e) {
      print('❌ Ошибка синхронизации: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  // ========== PULL: Получение данных с сервера ==========

  /// PULL операция: получить все изменения с сервера
  /// 
  /// Логика:
  /// 1. Отправляем lastSyncTime серверу
  /// 2. Сервер возвращает только привычки/логи, которые изменились после этого времени
  /// 3. Применяем эти изменения к локальной БД
  /// 4. Обновляем lastSyncTime
  Future<void> _pull() async {
    try {
      final token = await _auth.getToken();
      if (token == null) throw Exception('Нет токена авторизации');

      // Получить время последней синхронизации
      final lastSyncTime = await _getLastSyncTime();

      final response = await http.get(
        Uri.parse('$_baseUrl/sync/pull?lastSyncTime=$lastSyncTime'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('PULL ошибка: ${response.statusCode}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      
      // Применить загруженные привычки
      if (data['habits'] is List) {
        final habits = (data['habits'] as List)
            .map((h) => Habit.fromJson(h).copyWith(isSynced: true))
            .toList();
        await _db.saveHabits(habits);
      }

      // Применить загруженные логи
      if (data['habitLogs'] is List) {
        final logs = (data['habitLogs'] as List)
            .map((l) => HabitLog.fromJson(l).copyWith(isSynced: true))
            .toList();
        await _db.saveHabitLogs(logs);
      }

      // Обновить время последней синхронизации серверным временем
      if (data['serverSyncTime'] != null) {
        await _setLastSyncTime(data['serverSyncTime'] as String);
      }
    } catch (e) {
      print('❌ PULL ошибка: $e');
      rethrow;
    }
  }

  // ========== PUSH: Отправка локальных данных на сервер ==========

  /// PUSH операция: отправить все локальные изменения на сервер
  /// 
  /// Логика:
  /// 1. Собрать все несинхронизированные привычки и логи
  /// 2. Отправить их на /sync/push
  /// 3. Сервер применяет изменения (с разрешением конфликтов)
  /// 4. Пометить отправленные данные как синхронизированные
  Future<void> _push() async {
    try {
      final token = await _auth.getToken();
      if (token == null) throw Exception('Нет токена авторизации');

      // Собрать все несинхронизированные изменения
      final unsyncedHabits = await _db.getUnsyncedHabits();
      final unsyncedLogs = await _db.getUnsyncedHabitLogs();

      if (unsyncedHabits.isEmpty && unsyncedLogs.isEmpty) {
        print('ℹ️ Нечего отправлять, все синхронизировано');
        return;
      }

      // Подготовить JSON для отправки
      final pushData = {
        'habits': unsyncedHabits.map((h) => h.toJson()).toList(),
        'habitLogs': unsyncedLogs.map((l) => l.toJson()).toList(),
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/sync/push'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(pushData),
      );

      if (response.statusCode != 200) {
        throw Exception('PUSH ошибка: ${response.statusCode}');
      }

      // Пометить как синхронизированные
      await _db.saveHabits(unsyncedHabits.map((h) => h.copyWith(isSynced: true)).toList());
      await _db.saveHabitLogs(unsyncedLogs.map((l) => l.copyWith(isSynced: true)).toList());

      print('✅ Отправлено ${unsyncedHabits.length} привычек и ${unsyncedLogs.length} логов');
    } catch (e) {
      print('❌ PUSH ошибка: $e');
      rethrow;
    }
  }

  // ========== УТИЛИТЫ ==========

  static const _lastSyncKey = 'last_sync_time';

  /// Получить время последней синхронизации
  Future<String> _getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_lastSyncKey);
    if (saved != null) return saved;
    // Первая синхронизация — берём данные за последние 30 дней
    return DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
  }

  /// Обновить время синхронизации
  Future<void> _setLastSyncTime(String serverTime) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, serverTime);
    print('💾 lastSyncTime сохранён (ServerTime): $serverTime');
  }

  /// Получить текущее состояние синхронизации (для UI)
  Future<Map<String, int>> getSyncStatus() async {
    final stats = await _db.getStats();
    return {
      'unsyncedHabits': stats['habits'] ?? 0,
      'unsyncedLogs': stats['logs'] ?? 0,
      'queuedOperations': stats['queue'] ?? 0,
    };
  }
}
