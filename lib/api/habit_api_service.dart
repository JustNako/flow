import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/ai_habit_dto.dart';
import '../models/ai_insights_response.dart';
import '../models/behavioral_analysis.dart';
import 'api_service.dart';
import '../services/auth_service.dart';
import '../services/local_database.dart';

/// HabitApiService — офлайн-first сервис для работы с привычками.
///
/// АРХИТЕКТУРА:
/// 1. Все мутации (create, toggle, delete, update) сначала записываются в SQLite
/// 2. Затем в фоне отправляются на сервер (best-effort)
/// 3. getHabits() пытается получить данные с сервера, при ошибке — из SQLite
/// 4. Статистика вычисляется из локальных данных при отсутствии связи
class HabitApiService {
  static final HabitApiService _instance = HabitApiService._internal();
  factory HabitApiService() => _instance;
  HabitApiService._internal();
  static HabitApiService get instance => _instance;

  final _auth = AuthService.instance;
  final _db = LocalDatabase.instance;
  final _baseUrl = ApiService.baseUrl;
  final _uuid = const Uuid();

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Хелпер для обработки сетевых ошибок
  String _parseError(dynamic e) {
    final errStr = e.toString();

    final lower = errStr.toLowerCase();
    if (lower.contains('socketexception') || lower.contains('host lookup') || lower.contains('failed host lookup')) {
      return 'Network error. Please check your internet connection.';
    }
    if (lower.contains('timeoutexception') || lower.contains('timed out')) {
      return 'Request timed out. Please try again.';
    }

    try {
      final cleanStr = errStr.replaceFirst('Exception: ', '');
      if (cleanStr.contains('{') && cleanStr.contains('}')) {
        final jsonStart = cleanStr.indexOf('{');
        final jsonPart = cleanStr.substring(jsonStart);
        final data = jsonDecode(jsonPart);

        if (data is Map) {
          final error = data['error'];
          if (error is Map) {
            final code = error['code'];
            final message = error['message'];
            if (code == 'ProRequired') return 'ProRequired: $message';
            return message ?? 'An unexpected error occurred.';
          }
          return data['message'] ?? cleanStr;
        }
      }
    } catch (_) {}

    return errStr.replaceFirst('Exception: ', '');
  }

  bool _isNetworkError(dynamic e) {
    final lower = e.toString().toLowerCase();
    return lower.contains('socketexception') ||
        lower.contains('host lookup') ||
        lower.contains('failed host lookup') ||
        lower.contains('timeoutexception') ||
        lower.contains('timed out') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable');
  }

  // ─── GET /habits ───────────────────────────────────────────────────────────

  /// Получить привычки: пробует сервер (5s timeout), при ошибке берёт из SQLite.
  /// В обоих случаях обогащает isCompletedToday / streak из локальных логов.
  Future<List<Habit>> getHabits() async {
    final userId = await _auth.getUserId();

    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/habits'),
            headers: await _headers(),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        final habits = list.map((j) => Habit.fromJson(j as Map<String, dynamic>)).toList();

        // Сохранить в SQLite как кэш (с userId если известен)
        final toSave = habits.map((h) {
          return h.copyWith(
            userId: h.userId ?? userId,
            isSynced: true,
            localId: h.localId ?? h.id,
          );
        }).toList();
        await _db.savePulledHabits(toSave);

        // Обогатить ТОЛЬКО isCompletedToday из локальных логов.
        // currentStreak / completedDays берём с сервера — там актуальные значения.
        return await _db.enrichIsCompletedToday(toSave);
      }
      throw Exception('Failed to load habits: ${response.statusCode}');
    } catch (e) {
      debugPrint('getHabits from server failed: $e, falling back to local DB');
      // Офлайн фоллбэк — вычислить всё локально
      if (userId != null) {
        return await _db.getHabitsWithCompletionStatus(userId);
      }
      return [];
    }
  }

  // ─── POST /habits ──────────────────────────────────────────────────────────

  /// Создать привычку: сначала в SQLite, затем в фоне на сервер.
  Future<void> createHabit({
    required String title,
    String? description,
    String? notes,
    required int targetDays,
    String? unit,
    required HabitRepeatType repeatType,
    List<int>? repeatDaysOfWeek,
    List<int>? repeatDaysOfMonth,
    int? repeatTimesPerPeriod,
    int? repeatPeriod,
    bool isPublic = true,
    String? timeOfDay,
  }) async {
    final userId = await _auth.getUserId();
    final now = DateTime.now();
    final localId = _uuid.v4();

    // 1. Сохранить локально
    final localHabit = Habit(
      id: localId,
      userId: userId,
      title: title,
      description: description,
      notes: notes,
      targetDays: targetDays,
      unit: unit,
      completedDays: 0,
      repeatType: repeatType,
      repeatDaysOfWeek: repeatDaysOfWeek,
      repeatDaysOfMonth: repeatDaysOfMonth,
      repeatTimesPerPeriod: repeatTimesPerPeriod,
      repeatPeriod: repeatPeriod != null
          ? (repeatPeriod == 1 ? HabitRepeatPeriod.week : HabitRepeatPeriod.month)
          : null,
      isPublic: isPublic,
      timeOfDay: timeOfDay,
      createdAt: now,
      updatedAt: now,
      localId: localId,
      isSynced: false,
    );
    await _db.saveHabit(localHabit);

    // 2. Попробовать отправить на сервер в фоне
    _syncCreateHabit(
      title: title,
      description: description,
      notes: notes,
      targetDays: targetDays,
      unit: unit,
      repeatType: repeatType,
      repeatDaysOfWeek: repeatDaysOfWeek,
      repeatDaysOfMonth: repeatDaysOfMonth,
      repeatTimesPerPeriod: repeatTimesPerPeriod,
      repeatPeriod: repeatPeriod,
      isPublic: isPublic,
      timeOfDay: timeOfDay,
      localId: localId,
    );
  }

  Future<void> _syncCreateHabit({
    required String title,
    String? description,
    String? notes,
    required int targetDays,
    String? unit,
    required HabitRepeatType repeatType,
    List<int>? repeatDaysOfWeek,
    List<int>? repeatDaysOfMonth,
    int? repeatTimesPerPeriod,
    int? repeatPeriod,
    bool isPublic = true,
    String? timeOfDay,
    required String localId,
  }) async {
    try {
      final token = await _auth.getToken();
      final body = {
        'title': title,
        'description': description,
        'notes': notes,
        'targetDays': targetDays,
        'unit': unit,
        'repeatType': _repeatTypeToInt(repeatType),
        'repeatDaysOfWeek': repeatDaysOfWeek,
        'repeatDaysOfMonth': repeatDaysOfMonth,
        'repeatTimesPerPeriod': repeatTimesPerPeriod,
        'repeatPeriod': repeatPeriod,
        'isPublic': isPublic,
        'timeOfDay': timeOfDay,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/habits'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final serverHabit = Habit.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
        // Обновить habitId во всех локальных логах, которые ссылаются на старый localId
        await _db.updateHabitIdForLogs(localId, serverHabit.id!);
        // Заменить локальную запись серверной (с реальным ID)
        await _db.hardDeleteHabit(localId);
        await _db.saveHabit(serverHabit.copyWith(isSynced: true, localId: serverHabit.id));
        debugPrint('✅ Habit synced to server: ${serverHabit.id}');
      } else if (response.statusCode == 403) {
        // Pro limit — удалить локальную запись, выбросить ошибку
        await _db.hardDeleteHabit(localId);
        throw Exception('ProRequired: ${jsonDecode(response.body)['error']?['message'] ?? 'Upgrade to Pro'}');
      } else {
        debugPrint('⚠️ Server create failed: ${response.statusCode}. Will retry on next sync.');
      }
    } on Exception catch (e) {
      if (e.toString().contains('ProRequired')) rethrow;
      debugPrint('⚠️ _syncCreateHabit error: $e. Will retry on next sync.');
    }
  }

  // ─── POST /habits/{id}/toggle ──────────────────────────────────────────────

  /// Toggle привычки: сначала в SQLite, затем в фоне на сервер.
  Future<void> toggleHabit(String habitId, {String? note, String? habitLocalId}) async {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 1. Найти существующий лог за сегодня (по id и localId привычки)
    final existingLog = await _db.getHabitLogForDate(habitId, now, habitLocalId: habitLocalId);

    if (existingLog != null) {
      // Обновить ВСЕ дублирующиеся логи за сегодня единым UPDATE
      final newStatus = !existingLog.isCompleted;
      await _db.updateAllLogsForHabitAndDate(habitId, habitLocalId, now, newStatus);
    } else {
      // Создать новый лог (выполнено)
      final newLog = HabitLog(
        id: _uuid.v4(),
        habitId: habitId,
        date: now,
        isCompleted: true,
        note: note,
        isDeleted: false,
        updatedAt: now,
        isSynced: false,
        localId: _uuid.v4(),
      );
      await _db.saveHabitLog(newLog);
    }

    // 2. Синхронизировать с сервером
    await _syncToggleHabit(habitId, todayStr, note);
  }

  Future<void> _syncToggleHabit(String habitId, String todayStr, String? note) async {
    try {
      // Если привычка ещё не синхронизирована с сервером — не вызывать /toggle напрямую.
      // Лог уже помечен isSynced=false, следующий sync() его отправит через /sync/push.
      final habit = await _db.getHabit(habitId);
      if (habit == null || !habit.isSynced) {
        debugPrint('⚠️ Habit $habitId not yet on server — log will sync via push later.');
        return;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/habits/$habitId/toggle'),
        headers: await _headers(),
        body: jsonEncode({'note': note}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Пометить лог как синхронизированный
        final log = await _db.getHabitLogForDate(habitId, DateTime.now());
        if (log != null) {
          await _db.markHabitLogsAsSynced([log]);
        }
        debugPrint('✅ Toggle synced for habit $habitId');
      } else {
        debugPrint('⚠️ Toggle sync failed: ${response.statusCode}. Will retry on next sync.');
      }
    } catch (e) {
      debugPrint('⚠️ _syncToggleHabit error: $e. Will retry on next sync.');
    }
  }

  // ─── POST /habits/{id}/toggle-visibility ───────────────────────────────────

  Future<void> toggleVisibility(String habitId) async {
    // Оптимистично обновить локально
    final habit = await _db.getHabit(habitId);
    Habit? updatedHabit;
    if (habit != null) {
      updatedHabit = habit.copyWith(
        isPublic: !habit.isPublic,
        updatedAt: DateTime.now(),
        isSynced: false,
      );
      await _db.saveHabit(updatedHabit);
    }

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/habits/$habitId/toggle-visibility'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('Failed to toggle visibility: ${response.statusCode}');
      }
      if (updatedHabit != null) {
        await _db.markHabitsAsSynced([updatedHabit]);
      }
    } catch (e) {
      if (!_isNetworkError(e)) throw Exception(_parseError(e));
      debugPrint('⚠️ toggleVisibility offline: $e. Will retry on next sync.');
    }
  }

  // ─── DELETE /habits/{id} ───────────────────────────────────────────────────

  /// Удалить привычку: soft-delete в SQLite, затем в фоне на сервер.
  Future<void> deleteHabit(String habitId) async {
    await _db.deleteHabit(habitId);

    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/habits/$habitId'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('⚠️ Server delete failed: ${response.statusCode}. Will retry on next sync.');
      }
    } catch (e) {
      debugPrint('⚠️ deleteHabit offline: $e. Will retry on next sync.');
    }
  }

  // ─── PATCH /habits/{id}/notes ──────────────────────────────────────────────

  Future<void> updateNotes(String habitId, String notes) async {
    final habit = await _db.getHabit(habitId);
    Habit? updatedHabit;
    if (habit != null) {
      updatedHabit = habit.copyWith(notes: notes, updatedAt: DateTime.now(), isSynced: false);
      await _db.saveHabit(updatedHabit);
    }

    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/habits/$habitId/notes'),
        headers: await _headers(),
        body: jsonEncode({'notes': notes}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (updatedHabit != null) await _db.markHabitsAsSynced([updatedHabit]);
      } else {
        debugPrint('⚠️ updateNotes sync failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ updateNotes offline: $e. Will retry on next sync.');
    }
  }

  // ─── GET /habits/{id}/stats ────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStats(String habitId, {String? localId}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/habits/$habitId/stats'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Failed to get stats: ${response.statusCode}');
    } catch (e) {
      // Офлайн фоллбэк: вычислить из локальных логов
      return await _computeLocalStats(habitId, localId: localId);
    }
  }

  Future<Map<String, dynamic>> _computeLocalStats(String habitId, {String? localId}) async {
    final logs = await _db.getHabitLogsByHabitIds(habitId, localId);
    final completedLogs = logs.where((l) => l.isCompleted && !l.isDeleted).toList();
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    // Convert completed logs dates to local timezone and get unique local days
    final localLogDays = completedLogs
        .map((l) => l.date.toLocal())
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    final isCompletedToday = localLogDays.contains(todayDay);
    final uniqueCompletedDays = localLogDays.length;

    int streak = 0;
    if (localLogDays.isNotEmpty) {
      DateTime checkDate = todayDay;
      if (!isCompletedToday) {
        checkDate = todayDay.subtract(const Duration(days: 1));
      }
      for (final logDay in localLogDays) {
        if (logDay == checkDate) {
          streak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else if (logDay.isBefore(checkDate)) {
          break;
        }
      }
    }

    int longestStreak = 0;
    if (localLogDays.isNotEmpty) {
      final sortedAsc = List<DateTime>.from(localLogDays)..sort();
      int currentStreak = 0;
      DateTime? prevDay;
      for (final day in sortedAsc) {
        if (prevDay == null) {
          currentStreak = 1;
        } else if (day.difference(prevDay).inDays == 1) {
          currentStreak++;
        } else if (day.difference(prevDay).inDays > 1) {
          currentStreak = 1;
        }
        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
        }
        prevDay = day;
      }
    }

    final totalDaysTracked = logs.where((l) => !l.isDeleted).map((l) => l.date.toLocal()).map((d) => DateTime(d.year, d.month, d.day)).toSet().length;
    final double completionRate = totalDaysTracked == 0
        ? 0.0
        : (uniqueCompletedDays / totalDaysTracked * 100);

    return {
      'completedDays': uniqueCompletedDays,
      'currentStreak': streak,
      'longestStreak': longestStreak,
      'completionRate': completionRate.clamp(0.0, 100.0),
      'isCompletedToday': isCompletedToday,
      'source': 'local',
    };
  }

  // ─── GET /habits/{id}/streak ────────────────────────────────────────────────

  Future<int> getStreak(String habitId, {String? localId}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/habits/$habitId/streak'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['streak'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      final stats = await _computeLocalStats(habitId, localId: localId);
      return stats['currentStreak'] as int? ?? 0;
    }
  }

  // ─── GET /habits/ai-insights ──────────────────────────────────────────────

  Future<AiInsightsResponse> getAiInsights() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/habits/ai-insights'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return AiInsightsResponse.fromJson(jsonDecode(response.body));
      }

      if (response.statusCode == 403) {
        throw Exception('ProRequired');
      }

      throw Exception('Failed to load AI insights: ${response.statusCode}');
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  // ─── GET /habits/global-streak ──────────────────────────────────────────────

  Future<int> getGlobalStreak() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/habits/global-streak'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['streak'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      // Офлайн: рассчитать из локальных данных
      return await _computeLocalGlobalStreak();
    }
  }

  Future<int> _computeLocalGlobalStreak() async {
    final userId = await _auth.getUserId();
    if (userId == null) return 0;

    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    // Collect unique (habitKey, date) pairs — same dedup logic as _computeLocalGlobalStats
    final Set<String> seenHabitDays = {};
    final Set<DateTime> completedDays = {};
    
    final completedLogs = await _db.getCompletedLogsForUser(userId);
    for (final row in completedLogs) {
      final habitKey = row['habitKey'] as String;
      final logDateStr = row['logDate'] as String;
      
      final date = DateTime.parse(logDateStr);
      final localDate = date.toLocal();
      final dayOnly = DateTime(localDate.year, localDate.month, localDate.day);
      final dayKey = '${dayOnly.year}-${dayOnly.month.toString().padLeft(2, '0')}-${dayOnly.day.toString().padLeft(2, '0')}';
      if (seenHabitDays.add('$habitKey|$dayKey')) {
        completedDays.add(dayOnly);
      }
    }

    final localLogDays = completedDays.toList()..sort((a, b) => b.compareTo(a));

    int streak = 0;
    if (localLogDays.isNotEmpty) {
      DateTime checkDate = todayDay;
      final isCompletedToday = localLogDays.contains(todayDay);
      if (!isCompletedToday) {
        checkDate = todayDay.subtract(const Duration(days: 1));
      }
      for (final logDay in localLogDays) {
        if (logDay == checkDate) {
          streak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else if (logDay.isBefore(checkDate)) {
          break;
        }
      }
    }
    return streak;
  }

  // ─── GET /habits/global-stats ───────────────────────────────────────────────

  Future<Map<String, dynamic>> getGlobalStats() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/habits/global-stats'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Failed to load global stats: ${response.statusCode}');
    } catch (e) {
      return await _computeLocalGlobalStats();
    }
  }

  Future<Map<String, dynamic>> _computeLocalGlobalStats() async {
    final userId = await _auth.getUserId();
    if (userId == null) {
      return {
        'totalHabits': 0,
        'globalStreak': 0,
        'bestStreak': 0,
        'completionRate': 0.0,
        'isPro': false,
        'currentWeekCompletions': List.filled(7, 0),
        'last30DaysCompletions': List.filled(24, 0),
        'source': 'local',
      };
    }

    final habits = await _db.getHabits(userId);
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);

    // Collect all completed log dates across all habits.
    // Use a Set<String> of 'habitId|YYYY-MM-DD' to deduplicate —
    // a habit can have multiple log rows for the same day (local + pulled from server).
    // The server counts at most 1 completion per habit per day.
    final Map<String, int> completionsByDay = {}; // 'YYYY-MM-DD' → count
    final Set<String> seenHabitDays = {}; // 'habitKey|YYYY-MM-DD' dedupe

    final completedLogs = await _db.getCompletedLogsForUser(userId);
    for (final row in completedLogs) {
      final habitKey = row['habitKey'] as String;
      final logDateStr = row['logDate'] as String;
      
      final date = DateTime.parse(logDateStr);
      final localDate = date.toLocal();
      final dayKey = '${localDate.year}-${localDate.month.toString().padLeft(2, '0')}-${localDate.day.toString().padLeft(2, '0')}';
      final dedupeKey = '$habitKey|$dayKey';
      
      if (seenHabitDays.add(dedupeKey)) {
        completionsByDay[dayKey] = (completionsByDay[dayKey] ?? 0) + 1;
      }
    }

    // currentWeekCompletions — 7 days (Mon..Sun of current week)
    // Days 0=Mon, 1=Tue, ... 6=Sun
    final weekday = today.weekday; // 1=Mon..7=Sun
    final weekStart = todayDay.subtract(Duration(days: weekday - 1));
    final currentWeekCompletions = List.generate(7, (i) {
      final day = weekStart.add(Duration(days: i));
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      return completionsByDay[key] ?? 0;
    });

    // last30DaysCompletions — 24 individual days (one day per bar, matching the server)
    final last30DaysCompletions = List.generate(24, (i) {
      final day = todayDay.subtract(Duration(days: 23 - i));
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      return completionsByDay[key] ?? 0;
    });

    final last30Completions = List.generate(30, (i) {
      final day = todayDay.subtract(Duration(days: 29 - i));
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      return completionsByDay[key] ?? 0;
    });

    // Global streak — consecutive days with ≥1 completion
    int globalStreak = 0;
    final todayKey = '${todayDay.year}-${todayDay.month.toString().padLeft(2, '0')}-${todayDay.day.toString().padLeft(2, '0')}';
    final hasCompletedToday = (completionsByDay[todayKey] ?? 0) > 0;
    
    DateTime checkDate = hasCompletedToday ? todayDay : todayDay.subtract(const Duration(days: 1));
    for (int i = 0; i < 365; i++) {
      final key = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if ((completionsByDay[key] ?? 0) > 0) {
        globalStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    // Best streak — longest ever consecutive run
    int bestStreak = 0;
    int runningStreak = 0;
    final allDaysSorted = completionsByDay.keys.toList()..sort();
    DateTime? prevDay;
    for (final dayKey in allDaysSorted) {
      if ((completionsByDay[dayKey] ?? 0) > 0) {
        final day = DateTime.parse(dayKey);
        if (prevDay != null && day.difference(prevDay).inDays == 1) {
          runningStreak++;
        } else {
          runningStreak = 1;
        }
        if (runningStreak > bestStreak) bestStreak = runningStreak;
        prevDay = day;
      }
    }

    // Completion rate over last 30 days
    final totalScheduledSlots = habits.length * 30;
    final totalCompletionsLast30 = last30Completions.fold<int>(0, (p, c) => p + c);
    final completionRate = totalScheduledSlots > 0
        ? (totalCompletionsLast30 / totalScheduledSlots * 100).clamp(0.0, 100.0)
        : 0.0;

    return {
      'totalHabits': habits.length,
      'globalStreak': globalStreak,
      'bestStreak': bestStreak,
      'completionRate': completionRate,
      'isPro': false,
      'currentWeekCompletions': currentWeekCompletions,
      'last30DaysCompletions': last30DaysCompletions,
      'source': 'local',
    };
  }


  // ─── GET /habits/{id}/heatmap ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getHeatmap(String habitId, {String? localId}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/habits/$habitId/heatmap'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return await _computeLocalHeatmap(habitId, localId: localId);
    }
  }

  Future<List<Map<String, dynamic>>> _computeLocalHeatmap(String habitId, {String? localId}) async {
    final logs = await _db.getHabitLogsByHabitIds(habitId, localId);
    final completedLogs = logs.where((l) => l.isCompleted && !l.isDeleted).toList();

    // Convert completed logs dates to local timezone and get unique local days
    final completedDates = completedLogs
        .map((l) => l.date.toLocal())
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();

    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    // Use 35 days to cover the gridDates length of 35
    final startDate = todayDay.subtract(const Duration(days: 35));

    final List<Map<String, dynamic>> result = [];
    for (int i = 0; i <= 35; i++) {
      final day = startDate.add(Duration(days: i));
      final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      result.add({
        'date': dateStr,
        'value': completedDates.contains(day) ? 1 : 0,
      });
    }
    return result;
  }

  // ─── утилита ───────────────────────────────────────────────────────────────

  int _repeatTypeToInt(HabitRepeatType t) {
    switch (t) {
      case HabitRepeatType.everyDay: return 1;
      case HabitRepeatType.specificDaysOfWeek: return 2;
      case HabitRepeatType.specificDaysOfMonth: return 3;
      case HabitRepeatType.xTimesPerPeriod: return 4;
    }
  }

  // ─── AI Routine Generator ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> generateAiRoutine(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/generate-routine'),
        headers: await _headers(),
        body: jsonEncode({'prompt': prompt}),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (body is List) {
          return {
            'habits': body.map((e) => AiHabitDto.fromJson(e)).toList(),
            'aiGenerationsRemaining': 1,
            'isPro': false,
            'aiTotalLimit': 2,
          };
        }
        final List<dynamic> habitsData = body['habits'] ?? [];
        return {
          'habits': habitsData.map((e) => AiHabitDto.fromJson(e)).toList(),
          'aiGenerationsRemaining': body['aiGenerationsRemaining'] ?? body['remaining'] ?? 0,
          'isPro': body['isPro'] ?? false,
          'aiTotalLimit': body['aiTotalLimit'] ?? body['totalLimit'] ?? 0,
        };
      }
      throw Exception(body['message'] ?? 'Failed to generate routine');
    } catch (e) {
      debugPrint('generateAiRoutine error: $e');
      rethrow;
    }
  }

  // ─── GET /stats/monthly ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getMonthlyRecap(int year, int month) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/stats/monthly?year=$year&month=$month'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to load monthly recap: ${response.statusCode}');
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  // ─── POST /stats/share-recap ───────────────────────────────────────────────

  Future<String> shareMonthlyRecap({
    required int year,
    required int month,
    required int totalRate,
    required int bestStreak,
    required String bestHabit,
    required String archetypeTitle,
    required String archetypeDesc,
  }) async {
    try {
      final body = {
        'year': year,
        'month': month,
        'totalRate': totalRate,
        'bestStreak': bestStreak,
        'bestHabit': bestHabit,
        'archetypeTitle': archetypeTitle,
        'archetypeDesc': archetypeDesc,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/stats/share-recap'),
        headers: await _headers(),
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['link'] as String;
      }

      throw Exception('Failed to share recap: ${response.statusCode}');
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  // ─── GET /habits/behavioral-analysis ───────────────────────────────────────
  Future<BehavioralAnalysis> getBehavioralAnalysis() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/habits/behavioral-analysis'),
        headers: await _headers(),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return BehavioralAnalysis.fromJson(data);
      }

      if (response.statusCode == 403) {
        throw Exception('ProRequired');
      }

      throw Exception('Failed to load behavioral analysis: ${response.statusCode}');
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  // ─── PATCH /habits/{id} ───────────────────────────────────────────────────
  Future<void> updateHabitSettings(
    String habitId, {
    int? targetDays,
    String? timeOfDay,
    String? title,
    String? description,
  }) async {
    // Обновить локально
    final habit = await _db.getHabit(habitId);
    Habit? updatedHabit;
    if (habit != null) {
      updatedHabit = habit.copyWith(
        targetDays: targetDays ?? habit.targetDays,
        timeOfDay: timeOfDay ?? habit.timeOfDay,
        title: title ?? habit.title,
        description: description ?? habit.description,
        updatedAt: DateTime.now(),
        isSynced: false,
      );
      await _db.saveHabit(updatedHabit);
    }

    try {
      final body = {
        if (targetDays != null) 'targetDays': targetDays,
        if (timeOfDay != null) 'timeOfDay': timeOfDay,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
      };

      final response = await http.patch(
        Uri.parse('$_baseUrl/habits/$habitId'),
        headers: await _headers(),
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (updatedHabit != null) await _db.markHabitsAsSynced([updatedHabit]);
      } else {
        var detail = response.body;
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data['error'] is Map) {
            detail = data['error']['message']?.toString() ?? detail;
          }
        } catch (_) {}
        throw Exception('Failed to update habit settings: ${response.statusCode} - $detail');
      }
    } catch (e) {
      if (!_isNetworkError(e)) throw Exception(_parseError(e));
      debugPrint('⚠️ updateHabitSettings offline: $e. Will retry on next sync.');
    }
  }
}
