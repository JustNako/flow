import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/habit.dart';
import '../models/ai_habit_dto.dart';
import 'api_service.dart';
import '../services/auth_service.dart';

/// HabitApiService — взаимодействие с /api/v1/habits
class HabitApiService {
  static final HabitApiService _instance = HabitApiService._internal();
  factory HabitApiService() => _instance;
  HabitApiService._internal();
  static HabitApiService get instance => _instance;

  final _auth = AuthService.instance;
  final _baseUrl = ApiService.baseUrl;

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
    
    // 1. Handle network exceptions
    final lower = errStr.toLowerCase();
    if (lower.contains('socketexception') || lower.contains('host lookup') || lower.contains('failed host lookup')) {
      return 'Network error. Please check your internet connection.';
    }

    // 2. Try to parse JSON from the error message (often wrapped in Exception: ...)
    try {
      final cleanStr = errStr.replaceFirst('Exception: ', '');
      // The message might look like "Failed to create habit: { ... }"
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
    } catch (_) {
      // Fallback to raw string if JSON parsing fails
    }

    return errStr.replaceFirst('Exception: ', '');
  }

  // ─── GET /habits ───────────────────────────────────────────────────────────

  Future<List<Habit>> getHabits() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/habits'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list.map((j) => Habit.fromJson(j as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to load habits: ${response.statusCode}');
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  // ─── POST /habits ──────────────────────────────────────────────────────────

  Future<void> createHabit({
    required String title,
    String? description,
    String? notes,
    required int targetDays,
    required HabitRepeatType repeatType,

    List<int>? repeatDaysOfWeek,
    List<int>? repeatDaysOfMonth,
    int? repeatTimesPerPeriod,
    int? repeatPeriod,
    bool isPublic = true,
  }) async {
    try {
      final token = await _auth.getToken();

      final body = {
        "title": title,
        "description": description,
        "notes": notes,
        "targetDays": targetDays,
        "repeatType": _repeatTypeToInt(repeatType),

        "repeatDaysOfWeek": repeatDaysOfWeek,
        "repeatDaysOfMonth": repeatDaysOfMonth,
        "repeatTimesPerPeriod": repeatTimesPerPeriod,
        "repeatPeriod": repeatPeriod,
        "isPublic": isPublic,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/habits'),
        headers: {
          "Content-Type": "application/json",
          if (token != null) "Authorization": "Bearer $token",
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to create habit: ${response.body}");
      }
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  // ─── POST /habits/{id}/toggle ──────────────────────────────────────────────

  Future<void> toggleHabit(String habitId, {String? note}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/habits/$habitId/toggle'),
        headers: await _headers(),
        body: jsonEncode({'note': note}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to toggle habit: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  // ─── POST /habits/{id}/toggle-visibility ───────────────────────────────────

  Future<void> toggleVisibility(String habitId) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/habits/$habitId/toggle-visibility'),
        headers: await _headers(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to toggle visibility: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  // ─── DELETE /habits/{id} ───────────────────────────────────────────────────

  Future<void> deleteHabit(String habitId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/habits/$habitId'),
        headers: await _headers(),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to delete habit: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  // ─── PATCH /habits/{id}/notes ──────────────────────────────────────────────

  Future<void> updateNotes(String habitId, String notes) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/habits/$habitId/notes'),
        headers: await _headers(),
        body: jsonEncode({'notes': notes}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update notes: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  // ─── GET /habits/{id}/stats ────────────────────────────────────────────────

  Future<Map<String, dynamic>> getStats(String habitId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/habits/$habitId/stats'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Failed to get stats: ${response.statusCode}');
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  // ─── GET /habits/{id}/streak ────────────────────────────────────────────────

  Future<int> getStreak(String habitId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/habits/$habitId/streak'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['streak'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // ─── GET /habits/ai-insights ──────────────────────────────────────────────

  Future<List<String>> getAiInsights() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/habits/ai-insights'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data.map((e) => e.toString()).toList();
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
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['streak'] as int? ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // ─── GET /habits/global-stats ───────────────────────────────────────────────

  Future<Map<String, dynamic>> getGlobalStats() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/habits/global-stats'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Failed to load global stats: ${response.statusCode}');
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  // ─── GET /habits/{id}/heatmap ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getHeatmap(String habitId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/habits/$habitId/heatmap'),
        headers: await _headers(),
      );

      if (response.statusCode == 200) {
        final list = jsonDecode(response.body) as List<dynamic>;
        return list.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      return [];
    }
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
          // Old format: raw list
          return {
            'habits': body.map((e) => AiHabitDto.fromJson(e)).toList() as List<AiHabitDto>,
            'aiGenerationsRemaining': 1, // Fallback
            'isPro': false,
            'aiTotalLimit': 2,
          };
        }
        // New format: Map with habits and limits
        final List<dynamic> habitsData = body['habits'] ?? [];
        return {
          'habits': habitsData.map((e) => AiHabitDto.fromJson(e)).toList() as List<AiHabitDto>,
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
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to load monthly recap: ${response.statusCode}');
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }
}
