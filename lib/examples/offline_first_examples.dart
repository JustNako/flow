/// ПРИМЕРЫ ИСПОЛЬЗОВАНИЯ OFFLINE-FIRST АРХИТЕКТУРЫ
/// 
/// Этот файл содержит примеры, как использовать LocalDatabase, SyncService
/// и OfflineManager в вашем коде.

import 'package:habittracker_app/models/models.dart';
import 'package:habittracker_app/services/services.dart';

// =============================================================================
// ПРИМЕР 1: СОЗДАНИЕ НОВОЙ ПРИВЫЧКИ (Offline-ready)
// =============================================================================

Future<void> createHabitExample() async {
  final db = LocalDatabase.instance;
  final offlineManager = OfflineManager.instance;

  try {
    // 1. Создаем новую привычку (как пользователь ввел)
    final newHabit = Habit(
      userId: 'user_123',
      title: 'Спорт',
      description: '30 минут упражнений каждый день',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      localId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      isSynced: false,
    );

    // 2. Сохраняем в локальную БД (ВСЕГДА делаем это, даже без интернета!)
    await db.saveHabit(newHabit);
    print('✅ Привычка сохранена локально');

    // 3. Если интернет есть - отправить на сервер сразу
    if (offlineManager.isOnline) {
      final synced = await offlineManager.manualSync();
      if (synced) {
        print('✅ Привычка отправлена на сервер');
      } else {
        print('⚠️ Ошибка отправки, будет повторена');
      }
    } else {
      // Если интернета нет - синхронизируется автоматически позже
      print('📵 Интернета нет, синхронизируется при восстановлении сети');
    }
  } catch (e) {
    print('❌ Ошибка создания привычки: $e');
  }
}

// =============================================================================
// ПРИМЕР 2: ЗАГРУЗКА ВСЕХ ПРИВЫЧЕК ПОЛЬЗОВАТЕЛЯ
// =============================================================================

Future<List<Habit>> loadHabitsExample(String userId) async {
  final db = LocalDatabase.instance;

  try {
    // 1. Загружаем из локальной БД (всегда быстро!)
    final habits = await db.getHabits(userId);
    print('✅ Загружено ${habits.length} привычек из локальной БД');

    // 2. Если интернет есть - синхронизировать в фоне
    if (OfflineManager.instance.isOnline) {
      // Синхронизация произойдет асинхронно (без await)
      // Сначала покажем локальные данные пользователю
      SyncService.instance.sync().then((_) {
        print('🔄 Данные обновлены с сервера');
        // После синхронизации UI обновится через StreamBuilder
      });
    }

    return habits;
  } catch (e) {
    print('❌ Ошибка загрузки привычек: $e');
    return [];
  }
}

// =============================================================================
// ПРИМЕР 3: ПЕРЕКЛЮЧЕНИЕ ПРИВЫЧКИ (отметить как выполненную)
// =============================================================================

Future<void> toggleHabitExample(String habitId, DateTime date) async {
  final db = LocalDatabase.instance;
  final offlineManager = OfflineManager.instance;

  try {
    // 1. Получить или создать лог за эту дату
    var log = await db.getHabitLogForDate(habitId, date);

    if (log == null) {
      // Создать новый лог
      log = HabitLog(
        habitId: habitId,
        date: date,
        isCompleted: true,
        updatedAt: DateTime.now(),
        localId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        isSynced: false,
      );
    } else {
      // Обновить существующий
      log = log.copyWith(
        isCompleted: !log.isCompleted,
        updatedAt: DateTime.now(),
        isSynced: false, // Пометить как несинхронизированный
      );
    }

    // 2. Сохраняем в локальную БД
    await db.saveHabitLog(log);
    print('✅ Лог сохранен локально');

    // 3. Если интернет есть - синхронизировать
    if (offlineManager.isOnline) {
      await SyncService.instance.sync();
    }
  } catch (e) {
    print('❌ Ошибка переключения привычки: $e');
  }
}

// =============================================================================
// ПРИМЕР 4: УДАЛЕНИЕ ПРИВЫЧКИ (Soft delete)
// =============================================================================

Future<void> deleteHabitExample(String habitId) async {
  final db = LocalDatabase.instance;

  try {
    // 1. Мягкое удаление (пометить флаг, не удалять из БД)
    // Это важно для синхронизации - сервер должен знать что была удалена
    await db.deleteHabit(habitId);
    print('✅ Привычка помечена как удаленная');

    // 2. Если интернет есть - отправить на сервер
    if (OfflineManager.instance.isOnline) {
      await SyncService.instance.sync();
    } else {
      print('📵 Будет синхронизировано при восстановлении сети');
    }
  } catch (e) {
    print('❌ Ошибка удаления привычки: $e');
  }
}

// =============================================================================
// ПРИМЕР 5: ПОКАЗАТЬ СТАТУС СОЕДИНЕНИЯ В UI
// =============================================================================

/*
class HabitScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Мои привычки'),
        // Статус соединения в правом углу
        actions: [
          StreamBuilder<ConnectionStatus>(
            stream: OfflineManager.instance.connectionStatus,
            initialData: OfflineManager.instance.isOnline 
              ? ConnectionStatus.connected 
              : ConnectionStatus.disconnected,
            builder: (context, snapshot) {
              final status = snapshot.data ?? ConnectionStatus.connected;
              
              if (status == ConnectionStatus.syncing) {
                return Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Colors.orange),
                    ),
                  ),
                );
              } else if (status == ConnectionStatus.disconnected) {
                return Padding(
                  padding: EdgeInsets.all(16),
                  child: Tooltip(
                    message: 'Офлайн режим - данные будут синхронизированы позже',
                    child: Icon(Icons.cloud_off_outlined, color: Colors.red),
                  ),
                );
              } else {
                return Padding(
                  padding: EdgeInsets.all(16),
                  child: Icon(Icons.cloud_done_outlined, color: Colors.green),
                );
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Habit>>(
        future: loadHabitsExample('user_123'),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          
          final habits = snapshot.data ?? [];
          
          if (habits.isEmpty) {
            return Center(child: Text('Нет привычек'));
          }
          
          return ListView.builder(
            itemCount: habits.length,
            itemBuilder: (context, index) {
              final habit = habits[index];
              return ListTile(
                title: Text(habit.name),
                subtitle: Text(habit.description ?? ''),
                trailing: habit.isSynced 
                  ? Icon(Icons.cloud_done, color: Colors.green)
                  : Icon(Icons.cloud_upload_outlined, color: Colors.orange),
              );
            },
          );
        },
      ),
    );
  }
}
*/

// =============================================================================
// ПРИМЕР 6: ОБРАБОТКА ОШИБОК СИНХРОНИЗАЦИИ
// =============================================================================

Future<void> handleSyncErrorsExample() async {
  final offlineManager = OfflineManager.instance;

  // Слушать изменения статуса соединения
  offlineManager.connectionStatus.listen((status) {
    switch (status) {
      case ConnectionStatus.connected:
        print('🟢 Интернет подключен');
        break;
        
      case ConnectionStatus.disconnected:
        print('🔴 Интернет потерян - переходим на локальный режим');
        break;
        
      case ConnectionStatus.syncing:
        print('⏳ Синхронизирую данные...');
        break;
    }
  });

  // Принудительная синхронизация с обработкой ошибок
  final success = await offlineManager.manualSync();
  
  if (success) {
    print('✅ Синхронизация успешна');
  } else {
    print('❌ Синхронизация не удалась');
    // Показать пользователю сообщение об ошибке
    // Синхронизация будет повторена автоматически при восстановлении сети
  }
}

// =============================================================================
// ПРИМЕР 7: ПОЛУЧИТЬ СТАТИСТИКУ БД (для отладки)
// =============================================================================

Future<void> getStatsExample() async {
  final db = LocalDatabase.instance;
  final offlineManager = OfflineManager.instance;

  // Статистика БД
  final stats = await db.getStats();
  print('📊 Статистика БД:');
  print('  Привычек: ${stats['habits']}');
  print('  Логов: ${stats['logs']}');
  print('  В очереди синх: ${stats['queue']}');

  // Статус соединения
  final status = await offlineManager.getStatus();
  print('📡 Статус соединения:');
  print('  Онлайн: ${status['isOnline']}');
  print('  Несинхронизированных привычек: ${status['unsyncedHabits']}');
  print('  Несинхронизированных логов: ${status['unsyncedLogs']}');
  print('  Операций в очереди: ${status['queuedOperations']}');
}

// =============================================================================
// ПРИМЕР 8: ИНИЦИАЛИЗАЦИЯ ПРИ СТАРТЕ ПРИЛОЖЕНИЯ
// =============================================================================

/*
// В main.dart (уже сделано в вашем коде):

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Инициализируем локальную БД
  await LocalDatabase.instance.init();
  print('✅ LocalDatabase инициализирована');
  
  // 2. Инициализируем OfflineManager (для отслеживания сети)
  await OfflineManager.instance.init();
  print('✅ OfflineManager инициализирован');
  
  // Теперь приложение готово работать как в online, так и в offline режиме!
  runApp(const MyApp());
}
*/

// =============================================================================
// ПРИМЕР 9: ОЧИСТКА РЕСУРСОВ (при выходе из приложения)
// =============================================================================

Future<void> cleanupExample() async {
  final db = LocalDatabase.instance;
  final offlineManager = OfflineManager.instance;

  try {
    // Закрыть БД
    await db.close();
    
    // Очистить OfflineManager
    await offlineManager.dispose();
    
    print('✅ Ресурсы очищены');
  } catch (e) {
    print('❌ Ошибка очистки: $e');
  }
}

// =============================================================================
// ПРИМЕР 10: СЛОЖНЫЙ СЦЕНАРИЙ - Пользователь работает без интернета
// =============================================================================

Future<void> complexOfflineScenarioExample() async {
  final db = LocalDatabase.instance;
  final syncService = SyncService.instance;
  final offlineManager = OfflineManager.instance;

  print('📱 СЦЕНАРИЙ: Пользователь работает без интернета');
  
  // 1. Интернета нет
  print('Step 1: Интернета нет');
  
  // 2. Пользователь создает несколько привычек
  print('Step 2: Создаем привычки...');
  
  for (int i = 1; i <= 3; i++) {
    final habit = Habit(
      userId: 'user_123',
      title: 'Привычка $i',
      description: 'Описание привычки $i',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      localId: 'temp_$i',
      isSynced: false,
    );
    await db.saveHabit(habit);
  }
  print('✅ 3 привычки созданы локально');
  
  // 3. Пользователь переключает несколько логов
  print('Step 3: Переключаем логи...');
  // ... создание логов ...
  
  // 4. Интернет восстановился!
  print('Step 4: Интернет восстановлен!');
  
  // 5. OfflineManager автоматически стартует синхронизацию
  // Но мы можем также сделать это вручную:
  final syncSuccess = await syncService.sync();
  
  if (syncSuccess) {
    print('✅ ВСЕ данные синхронизированы с сервером!');
    print('✅ Пользователь может продолжать работу');
  }
}
