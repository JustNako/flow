import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../utils/globals.dart';

/// ApiService — базовый HTTP-клиент.
/// Бэк возвращает { "token": "..." } при логине напрямую.
class ApiService {
  // Android эмулятор → 10.0.2.2 мапится на localhost хоста
  // Для реального устройства или iOS симулятора меняй на IP машины

  //local
  //static const String baseUrl = "http://192.168.137.1:5264/api/v1";

  //MonsterASP
  static const String baseUrl = "https://habittracker.runasp.net/api/v1";

  //Custom domain (requires paid MonsterASP plan)
  //static const String baseUrl = "https://api.flowtracks.app/api/v1";

  //AzureЫ
  //static const String baseUrl = "https://flow-api-backend-h4fne4dnarf8eqay.westeurope-01.azurewebsites.net/api/v1";

  static String get serverRoot => baseUrl.replaceAll('/api/v1', '');

  Future<Map<String, String>> _getHeaders() async {
    final token = await AuthService.instance.getToken();
    return {
      "Content-Type": "application/json",
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  void _processResponse(http.Response response) {
    if (response.statusCode == 401) {
      debugPrint("⛔ [401] Unauthorized — redirecting to login.");
      // ВАЖНО: не вызываем logout() здесь.
      // logout() удаляет токен — это делается ТОЛЬКО при явном нажатии кнопки выхода.
      // При 401 просто перенаправляем на экран входа, токен остаётся нетронутым.
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        navigator.pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  // Хелпер для обработки сетевых ошибок
  static String _parseError(dynamic e) {
    final errStr = e.toString().toLowerCase();
    if (errStr.contains('socketexception') || errStr.contains('host lookup') || errStr.contains('failed host lookup')) {
      return 'Network error. Please check your internet connection.';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  Future<String> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "password": password,
          "timeZoneOffset": DateTime.now().timeZoneOffset.inMinutes,
        }),
      );

      _processResponse(response);
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        final msg = body['message'] ?? 'Login failed';
        if (msg == 'email_not_confirmed') {
          final email = body['email'] ?? '';
          throw Exception('email_not_confirmed:$email');
        }
        throw Exception(msg);
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data["token"] as String;
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  Future<void> register(String username, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "userName": username,
          "email": email,
          "password": password,
        }),
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        String msg = body['message'] ?? 'Registration failed';
        if (body['errors'] != null) {
          final errors = body['errors'] as List;
          if (errors.isNotEmpty) {
            final descriptions = errors.map((e) => e['description'].toString()).toList();
            msg = descriptions.join('\n');
          }
        }
        throw Exception(msg);
      }
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  Future<void> deleteAccount(String username, String password) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/auth/delete"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "username": username,
          "password": password,
        }),
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Account deletion failed');
      }
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  Future<Map<String, dynamic>> getUserProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/auth/me"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to load profile');
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  Future<void> upgradeToPro(String token, String plan) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/upgrade-to-pro"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"plan": plan}),
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to upgrade to Pro');
      }
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  Future<void> cancelProPlan(String token) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/cancel-pro"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to cancel Pro plan');
      }
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  Future<Map<String, dynamic>> getNotificationSettings(String token) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/auth/notification-settings"),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
      );
      if (response.statusCode != 200) return {'enabled': false, 'frequency': 1};
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      // Для настроек можно вернуть дефолт вместо ошибки
      return {'enabled': false, 'frequency': 1};
    }
  }

  Future<void> updateNotificationSettings(String token, {required bool enabled, required int frequency}) async {
    try {
      await http.put(
        Uri.parse("$baseUrl/auth/notification-settings"),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: jsonEncode({'enabled': enabled, 'frequency': frequency}),
      );
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  Future<Map<String, dynamic>> editProfile(String token, {String? username, String? email, String? currentPassword, String? newPassword}) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/edit"),
        headers: {"Content-Type": "application/json", "Authorization": "Bearer $token"},
        body: jsonEncode({
          if (username != null) "userName": username,
          if (email != null) "email": email,
          if (currentPassword != null) "currentPassword": currentPassword,
          if (newPassword != null) "newPassword": newPassword,
        }),
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to update profile');
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  Future<void> resendConfirmationEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/resend-confirmation"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to resend email');
      }
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  Future<void> forgotPassword(String email) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/forgot-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to send reset link');
      }
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  Future<void> sendTestNotification(String token) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/auth/test-notification"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['message'] ?? 'Failed to send test notification');
      }
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  Future<Map<String, dynamic>> checkAppVersion() async {
    try {
      final response = await http.get(Uri.parse("$baseUrl/app/version"));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      debugPrint("Failed to check app version: $e");
      return {};
    }
  }

  Future<void> updateAppUsage(String date, int secondsSpent) async {
    try {
      final token = await AuthService.instance.getToken();
      if (token == null) return;

      final response = await http.post(
        Uri.parse("$baseUrl/auth/usage"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "date": date,
          "secondsSpent": secondsSpent,
        }),
      );

      if (response.statusCode != 200) {
        debugPrint("Failed to sync app usage: ${response.body}");
      }
    } catch (e) {
      debugPrint("Error syncing app usage: $e");
    }
  }
}

