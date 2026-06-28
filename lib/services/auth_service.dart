import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../api/api_service.dart';
import 'widget_service.dart';
import 'local_database.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  static AuthService get instance => _instance;

  final ApiService _api = ApiService();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
  );

  Future<String?> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      // Obtain authentication details
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception("Failed to get Google ID token.");
      }

      // Send token to our backend
      final token = await _api.loginWithGoogle(idToken);

      // Save secure data (token) in Keychain/Keystore
      const secureStorage = FlutterSecureStorage();
      await secureStorage.write(key: 'auth_token', value: token);

      // Save non-secure data and fallback token in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token_fallback', token);
      String realUsername = googleUser.email.split('@')[0];

      // Fetch user profile to get the real userId and userName
      try {
        final profile = await _api.getUserProfile(token);
        final userId = profile['id']?.toString() ?? googleUser.email;
        await prefs.setString('auth_user_id', userId);
        
        final apiUsername = profile['userName'] ?? profile['username'];
        if (apiUsername != null) {
          realUsername = apiUsername.toString();
        }
        
        // Link RevenueCat anonymous session to our real user ID
        await Purchases.logIn(userId);
      } catch (_) {
        // If profile fetch fails, use email as fallback
        await Purchases.logIn(googleUser.email);
      }

      await prefs.setString('auth_username', realUsername);

      // Update widgets
      WidgetService.updateWidget();

      return token;
    } catch (e) {
      // Ensure we clean up sign-in state on error
      try { await _googleSignIn.signOut(); } catch (_) {}
      rethrow;
    }
  }

  Future<String> login(String username, String password) async {
    final token = await _api.login(username, password);
    
    // Save secure data (token) in Keychain/Keystore
    const secureStorage = FlutterSecureStorage();
    await secureStorage.write(key: 'auth_token', value: token);

    // Save non-secure data and fallback token in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token_fallback', token);
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
    try {
      const secureStorage = FlutterSecureStorage();
      final token = await secureStorage.read(key: 'auth_token');
      if (token != null) return token;
    } catch (e) {
      debugPrint('[AuthService] Failed to read from secure storage: $e');
    }

    // Fallback to SharedPreferences for background isolates / widget service
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('auth_token_fallback');
    } catch (e) {
      debugPrint('[AuthService] Failed to read fallback token: $e');
      return null;
    }
  }

  Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_username');
  }

  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_user_id');
  }

  Future<void> logout() async {
    // Attempt to remove FCM token from the server to prevent cross-account push notifications
    await _api.removeFcmToken();

    const secureStorage = FlutterSecureStorage();
    await secureStorage.delete(key: 'auth_token');

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token_fallback');
    await prefs.remove('auth_username');
    await prefs.remove('auth_user_id');
    await prefs.remove('last_sync_time');
    await prefs.remove('has_done_deep_pull_365');

    // Wipe local database
    await LocalDatabase.instance.wipe();

    // Unlink RevenueCat user on logout
    try { await Purchases.logOut(); } catch (_) {}
    
    // Sign out from Google
    try { await _googleSignIn.signOut(); } catch (_) {}

    // Update Home Widgets to show the logout/unauthenticated UI
    WidgetService.updateWidget();
  }

  Future<void> deleteAccount({String? password}) async {
    final prefs = await SharedPreferences.getInstance();
    final username = prefs.getString('auth_username');
    if (username == null) throw Exception('Username not found. Please re-login.');
    
    String? googleIdToken;
    if (password == null || password.isEmpty) {
      try {
        // Sign out first to force account selection dialog (re-authentication)
        try { await _googleSignIn.signOut(); } catch (_) {}
        
        final googleUser = await _googleSignIn.signIn();
        if (googleUser != null) {
          final googleAuth = await googleUser.authentication;
          googleIdToken = googleAuth.idToken;
        }
      } catch (e) {
        throw Exception("Google re-authentication failed: $e");
      }
      
      if (googleIdToken == null) {
        throw Exception("Re-authentication with Google cancelled.");
      }
    }

    await _api.deleteAccount(username, password: password, googleIdToken: googleIdToken);
    
    // Attempt to remove FCM token
    await _api.removeFcmToken();
    
    const secureStorage = FlutterSecureStorage();
    await secureStorage.delete(key: 'auth_token');
    await prefs.remove('auth_token_fallback');

    await prefs.remove('auth_username');
    await prefs.remove('auth_user_id');
    
    // Sign out from Google
    try { await _googleSignIn.signOut(); } catch (_) {}
    
    // Update Home Widgets to show the logout/unauthenticated UI
    WidgetService.updateWidget();
  }

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}