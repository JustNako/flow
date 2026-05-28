import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../api/api_service.dart';
import 'widget_service.dart';

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
    
    // Save secure data (token) in Keychain/Keystore
    const secureStorage = FlutterSecureStorage();
    await secureStorage.write(key: 'auth_token', value: token);

    // Save non-secure data in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
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
    const secureStorage = FlutterSecureStorage();
    return await secureStorage.read(key: 'auth_token');
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_username');
  }

  Future<void> logout() async {
    // Attempt to remove FCM token from the server to prevent cross-account push notifications
    await _api.removeFcmToken();

    const secureStorage = FlutterSecureStorage();
    await secureStorage.delete(key: 'auth_token');

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_username');
    await prefs.remove('auth_user_id');
    // Unlink RevenueCat user on logout
    try { await Purchases.logOut(); } catch (_) {}

    // Update Home Widgets to show the logout/unauthenticated UI
    WidgetService.updateWidget();
  }

  Future<void> deleteAccount(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('auth_username');
    if (username == null) throw Exception('Username not found. Please re-login.');
    await _api.deleteAccount(username, password);
    
    // Attempt to remove FCM token
    await _api.removeFcmToken();
    
    const secureStorage = FlutterSecureStorage();
    await secureStorage.delete(key: 'auth_token');

    await prefs.remove('auth_username');
    
    // Update Home Widgets to show the logout/unauthenticated UI
    WidgetService.updateWidget();
  }

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}