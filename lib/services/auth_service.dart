import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../api/api_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  static AuthService get instance => _instance;

  final ApiService _api = ApiService();

  Future<String> login(String username, String password) async {
    final token = await _api.login(username, password);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('auth_username', username);

    // Fetch user profile to get the real userId for RevenueCat
    try {
      final profile = await _api.getUserProfile(token);
      final userId = profile['id']?.toString() ?? username;
      await prefs.setString('auth_user_id', userId);
      // Link RevenueCat anonymous session to our real user ID
      await Purchases.logIn(userId);
    } catch (_) {
      // If profile fetch fails, use username as fallback
      await Purchases.logIn(username);
    }
    
    return token;
  }

  Future<void> register(String username, String email, String password) async {
    await _api.register(username, email, password);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_username');
    await prefs.remove('auth_user_id');
    // Unlink RevenueCat user on logout
    try { await Purchases.logOut(); } catch (_) {}
  }

  Future<void> deleteAccount(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('auth_username');
    if (username == null) throw Exception('Username not found. Please re-login.');
    await _api.deleteAccount(username, password);
    await prefs.remove('auth_token');
    await prefs.remove('auth_username');
  }

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}