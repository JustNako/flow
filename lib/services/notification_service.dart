import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api/api_service.dart';
import '../services/auth_service.dart';
import 'widget_service.dart';
import '../services/local_database.dart';

// Helper function to check if habit is completed today in local DB
Future<bool> _isHabitCompletedTodayLocally(String habitId, DateTime date) async {
  try {
    final db = LocalDatabase.instance;
    await db.init();
    final log = await db.getHabitLogForDate(habitId, date, habitLocalId: habitId);
    return log != null && log.isCompleted && !log.isDeleted;
  } catch (e) {
    debugPrint('Error checking habit completion locally: $e');
    return false;
  }
}

// Top-level обработчик фоновых действий с кнопок (Interactive Notifications)
@pragma('vm:entry-point')
void onNotificationAction(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (response.actionId != null && response.actionId!.startsWith('complete_')) {
    final habitId = response.actionId!.replaceAll('complete_', '');
    
    final token = await AuthService.instance.getToken();
    
    if (token != null) {
      try {
        final url = Uri.parse('${ApiService.baseUrl}/habits/$habitId/toggle');
        final httpResp = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'note': 'Completed via Notification'}),
        );
        debugPrint('Background toggle response: ${httpResp.statusCode}');
        
        if (httpResp.statusCode == 200) {
          // Sync home screen widget immediately with the new background state
          await WidgetService.updateWidget();
        }
        
        // Hide notification after action
        if (response.id != null) {
          final plugin = FlutterLocalNotificationsPlugin();
          await plugin.cancel(response.id!);
        }
      } catch (e) {
        debugPrint('Failed to toggle habit from background: $e');
      }
    }
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📬 Background Data: ${message.data}');
  
  final type = message.data['type'];
  if (type == 'reminder' || type == 'test') {
    final title = message.data['title'] ?? '⚡ Keep your streak alive!';
    final body = message.data['body'] ?? 'You still have habits to complete today.';
    
    List<AndroidNotificationAction>? actions;
    if (type == 'reminder') {
      final idsStr = message.data['habitIds'] as String?;
      final titlesStr = message.data['habitTitles'] as String?;
      
      if (idsStr != null && titlesStr != null && idsStr.isNotEmpty) {
        final ids = idsStr.split(',');
        final titles = titlesStr.split(',');
        
        final List<String> uncompletedIds = [];
        final List<String> uncompletedTitles = [];
        final now = DateTime.now();
        
        for (int i = 0; i < ids.length; i++) {
          final habitId = ids[i];
          final isCompleted = await _isHabitCompletedTodayLocally(habitId, now);
          if (!isCompleted) {
            uncompletedIds.add(habitId);
            uncompletedTitles.add(titles[i]);
          }
        }
        
        // If all habits are completed locally, don't show the reminder notification
        if (uncompletedIds.isEmpty) {
          debugPrint('🤫 Skipping reminder notification: all habits are already completed locally.');
          return;
        }
        
        actions = [];
        for (int i = 0; i < uncompletedIds.length && i < 3; i++) {
          actions.add(AndroidNotificationAction('complete_${uncompletedIds[i]}', uncompletedTitles[i]));
        }
      }
    }
    
    final plugin = FlutterLocalNotificationsPlugin();
    
    // Инициализация плагина обязательна в фоновом изоляте
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      iOS: DarwinInitializationSettings(),
    );
    await plugin.initialize(initSettings);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'flow_channel',
        'Flow Notifications',
        importance: Importance.high,
        priority: Priority.high,
        color: const Color(0xFFE8845C),
        actions: actions,
      ),
      iOS: const DarwinNotificationDetails(
        categoryIdentifier: 'HABIT_ACTION',
      ),
    );
    
    await plugin.show(message.hashCode, title, body, details);
  }
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

    // 1. Фоновый обработчик FCM
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
    final iosActions = <DarwinNotificationAction>[
      DarwinNotificationAction.plain('complete_action', 'Mark as Done'),
    ];
    final iosCategories = <DarwinNotificationCategory>[
      DarwinNotificationCategory('HABIT_ACTION', actions: iosActions),
    ];

    final initSettings = InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/launcher_icon'),
      iOS: DarwinInitializationSettings(
        notificationCategories: iosCategories,
      ),
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: onNotificationAction,
      onDidReceiveBackgroundNotificationResponse: onNotificationAction,
    );

    // 5. Слушатели
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageTap);

    // 6. FCM-токен
    await _sendToken();
    _fcm.onTokenRefresh.listen(_uploadToken);
  }

  void _onForegroundMessage(RemoteMessage message) async {
    debugPrint('📩 Foreground: ${message.data}');
    
    final type = message.data['type'];
    if (type == 'reminder' || type == 'test') {
      final title = message.data['title'] ?? '⚡ Keep your streak alive!';
      final body = message.data['body'] ?? 'You still have habits to complete today.';
      
      List<AndroidNotificationAction>? actions;
      if (type == 'reminder') {
        final idsStr = message.data['habitIds'] as String?;
        final titlesStr = message.data['habitTitles'] as String?;
        
        if (idsStr != null && titlesStr != null && idsStr.isNotEmpty) {
          final ids = idsStr.split(',');
          final titles = titlesStr.split(',');
          
          final List<String> uncompletedIds = [];
          final List<String> uncompletedTitles = [];
          final now = DateTime.now();
          
          for (int i = 0; i < ids.length; i++) {
            final habitId = ids[i];
            final isCompleted = await _isHabitCompletedTodayLocally(habitId, now);
            if (!isCompleted) {
              uncompletedIds.add(habitId);
              uncompletedTitles.add(titles[i]);
            }
          }
          
          if (uncompletedIds.isEmpty) {
            debugPrint('🤫 Skipping reminder notification (foreground): all habits completed.');
            return;
          }
          
          actions = [];
          for (int i = 0; i < uncompletedIds.length && i < 3; i++) {
            actions.add(AndroidNotificationAction('complete_${uncompletedIds[i]}', uncompletedTitles[i]));
          }
        }
      }
      
      _show(message.hashCode, title, body, actions: actions);
    } else if (message.notification != null) {
      final n = message.notification!;
      _show(n.hashCode, n.title ?? '', n.body ?? '');
    }
  }

  void _onMessageTap(RemoteMessage message) {
    debugPrint('👉 Tapped: ${message.notification?.title}');
  }

  void _show(int id, String title, String body, {List<AndroidNotificationAction>? actions}) {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
        color: const Color(0xFFE8845C),
        actions: actions,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'HABIT_ACTION',
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

  Future<void> sendTokenToServer() => _sendToken();

  Future<void> _uploadToken(String token) async {
    try {
      final authToken = await AuthService.instance.getToken();
      if (authToken == null) return;

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
