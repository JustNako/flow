import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import './local_database.dart';
import './sync_service.dart';

/// OfflineManager
/// 
/// НАЗНАЧЕНИЕ:
/// - Отслеживает наличие соединения с интернетом
/// - Автоматически включает/отключает локальный режим работы
/// - При появлении интернета - автоматически синхронизирует данные
/// - Предоставляет UI информацию о статусе соединения
///
/// АРХИТЕКТУРА:
/// 1. Слушает events от Connectivity plugin
/// 2. Когда сеть появляется → запускает синхронизацию
/// 3. Когда сети нет → переключается на локальное хранилище
/// 4. Уведомляет UI через Stream/ValueNotifier

enum ConnectionStatus {
  connected,
  disconnected,
  syncing,
}

class OfflineManager {
  static final OfflineManager _instance = OfflineManager._internal();

  factory OfflineManager() {
    return _instance;
  }

  OfflineManager._internal();

  static OfflineManager get instance => _instance;

  final _connectivity = Connectivity();
  final _db = LocalDatabase.instance;
  final _syncService = SyncService.instance;

  StreamSubscription? _connectivitySubscription;
  
  /// Stream для UI (показать статус соединения)
  final _connectionStatusController = StreamController<ConnectionStatus>.broadcast();
  Stream<ConnectionStatus> get connectionStatus => _connectionStatusController.stream;

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  /// Инициализировать менеджер
  /// Вызвать это в main.dart при старте приложения
  Future<void> init() async {
    try {
      // Проверить начальный статус сети
      await _checkConnectivity();

      // Если при старте интернет есть — сразу запускаем фоновую синхронизацию в обе стороны
      if (_isOnline) {
        _synchronizeWhenOnline();
      }

      // Слушать изменения сети
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
        _handleConnectivityChange(result);
      });

      print('✅ OfflineManager инициализирован');
    } catch (e) {
      print('❌ Ошибка инициализации OfflineManager: $e');
    }
  }

  /// Проверить текущий статус сети
  Future<void> _checkConnectivity() async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      _isOnline = connectivityResult != ConnectivityResult.none;

      print(_isOnline ? '🟢 Интернет подключен' : '🔴 Интернет отключен');
      _connectionStatusController.add(
        _isOnline ? ConnectionStatus.connected : ConnectionStatus.disconnected
      );
    } catch (e) {
      print('❌ Ошибка проверки сети: $e');
    }
  }

  /// Обработать изменение соединения
  void _handleConnectivityChange(ConnectivityResult result) async {
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;

    print(_isOnline ? '🟢 Интернет восстановлен' : '🔴 Интернет потерян');

    // Если интернет появился - синхронизировать
    if (!wasOnline && _isOnline) {
      _connectionStatusController.add(ConnectionStatus.syncing);
      await _synchronizeWhenOnline();
      _connectionStatusController.add(ConnectionStatus.connected);
    } else if (wasOnline && !_isOnline) {
      _connectionStatusController.add(ConnectionStatus.disconnected);
    }
  }

  /// Синхронизировать данные при появлении интернета
  Future<void> _synchronizeWhenOnline() async {
    // Ждём 2 секунды, чтобы соединение с интернетом успело стабилизироваться (получение IP, DNS резолв)
    await Future.delayed(const Duration(seconds: 2));
    if (!_isOnline) return;

    int retries = 3;
    while (retries > 0) {
      try {
        print('⏳ Синхронизирую данные (осталось попыток: $retries)...');
        final success = await _syncService.sync();
        if (success) {
          print('✅ Синхронизация завершена успешно');
          break;
        } else {
          print('⚠️ Синхронизация завершилась с ошибкой');
        }
      } catch (e) {
        print('❌ Ошибка при попытке синхронизации: $e');
      }
      retries--;
      if (retries > 0) {
        // Ждем 5 секунд перед следующей попыткой
        await Future.delayed(const Duration(seconds: 5));
      }
    }
  }

  /// Экспортировать состояние (для UI)
  Future<Map<String, dynamic>> getStatus() async {
    final stats = await _db.getStats();
    
    return {
      'isOnline': _isOnline,
      'unsyncedHabits': stats['habits'] ?? 0,
      'unsyncedLogs': stats['logs'] ?? 0,
      'queuedOperations': stats['queue'] ?? 0,
    };
  }

  /// Принудительная синхронизация (на случай если автоматическая не сработала)
  Future<bool> manualSync() async {
    await _checkConnectivity();
    if (!_isOnline) {
      print('⚠️ Интернет не подключен, синхронизация невозможна');
      return false;
    }

    _connectionStatusController.add(ConnectionStatus.syncing);
    
    try {
      final success = await _syncService.sync();
      _connectionStatusController.add(ConnectionStatus.connected);
      return success;
    } catch (e) {
      _connectionStatusController.add(ConnectionStatus.connected);
      return false;
    }
  }

  /// Очистить ресурсы (на выход из приложения)
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    await _connectionStatusController.close();
  }
}
