import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api/api_service.dart';
import '../services/auth_service.dart';
import '../utils/globals.dart';

// Top-level обработчик фоновых сообщений — обязателен вне класса
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📬 Background: ${message.notification?.title}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();
  static NotificationService get instance => _instance;

  final _plugin = FlutterLocalNotificationsPlugin();
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  static const _channelId   = 'flow_channel';
  static const _channelName = 'Flow Notifications';

  Future<void> initialize() async {
    await Firebase.initializeApp();

    // 1. Фоновый обработчик
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. Разрешения
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 3. Создать Android-канал
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Habit reminders from Flow',
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 4. Инициализация плагина
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(initSettings);

    // 5. Слушатели
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageTap);

    // 6. FCM-токен
    await _sendToken();
    _fcm.onTokenRefresh.listen(_uploadToken);
  }

  void _onForegroundMessage(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    debugPrint('📩 Foreground: ${n.title}');
    _show(n.hashCode, n.title ?? '', n.body ?? '');
  }

  void _onMessageTap(RemoteMessage message) {
    debugPrint('👉 Tapped: ${message.notification?.title}');
  }

  void _show(int id, String title, String body) {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
        color: Color(0xFFDA22FF),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    _plugin.show(id, title, body, details);
  }

  Future<void> _sendToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) await _uploadToken(token);
    } catch (e) {
      debugPrint('FCM token error: $e');
    }
  }

  /// Публичный метод — вызывается из login_screen после входа
  Future<void> sendTokenToServer() => _sendToken();

  Future<void> _uploadToken(String token) async {
    try {
      final authToken = await AuthService.instance.getToken();
      if (authToken == null) {
        debugPrint('⚠️ FCM upload skipped — not logged in yet');
        return;
      }

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/auth/fcm-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'token': token}),
      );

      if (response.statusCode == 200) {
        debugPrint('✅ FCM token uploaded to server');
      } else {
        debugPrint('⚠️ FCM token upload failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ FCM token upload error: $e');
    }
  }
}
