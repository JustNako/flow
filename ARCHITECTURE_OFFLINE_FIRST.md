# Архитектура Offline-First для Habit Tracker

## 📋 Обзор

Это система для синхронизации данных привычек между Flutter приложением и C# бэком с поддержкой полного offline режима.

## 🏗️ Компоненты архитектуры

### 1. **MODELS** (`lib/models/`)
Структуры данных, которые соответствуют вашему бэку:

- **`habit.dart`** - Привычка
  ```dart
  - id: Серверный ID
  - userId: Кому принадлежит
  - name: Название привычки
  - description: Описание
  - isDeleted: Для мягкого удаления
  - updatedAt: Для разрешения конфликтов
  - isSynced: Была ли отправлена на сервер
  - localId: Временный ID для новых данных
  ```

- **`habit_log.dart`** - Логирование выполнения
  ```dart
  - habitId: К какой привычке относится
  - logDate: Когда выполнена
  - isCompleted: Выполнена ли
  - updatedAt: Для конфликтов
  ```

- **`sync_queue_item.dart`** - Очередь синхронизации
  - Для буферизации операций при отсутствии интернета

---

### 2. **LOCAL DATABASE** (`lib/services/local_database.dart`)

**Назначение**: Управляет локальным хранилищем (SQLite)

**Таблицы**:
1. `habits` - Кэш привычек
2. `habit_logs` - Кэш логов
3. `sync_queue` - Очередь операций для синхронизации

**Основные методы**:
```dart
// Привычки
await LocalDatabase.instance.saveHabit(habit);
await LocalDatabase.instance.getHabits(userId);
await LocalDatabase.instance.deleteHabit(habitId);

// Логи
await LocalDatabase.instance.saveHabitLog(log);
await LocalDatabase.instance.getHabitLogs(habitId);

// Синхронизация
await LocalDatabase.instance.addToSyncQueue(item);
await LocalDatabase.instance.getUnsyncedQueue();
```

---

### 3. **SYNC SERVICE** (`lib/services/sync_service.dart`)

**Назначение**: Синхронизирует данные с C# бэком

**Поток работы**:
```
1. PULL (Pull): 
   ├─ Отправить lastSyncTime на сервер
   ├─ Получить все изменения с этого времени
   └─ Применить в локальную БД

2. PUSH (Push):
   ├─ Собрать все несинхронизированные данные
   ├─ Отправить на сервер
   ├─ Сервер разрешает конфликты (Last-Write-Wins)
   └─ Пометить как синхронизированные
```

**Методы**:
```dart
// Главный метод синхронизации
await SyncService.instance.sync();

// Получить статус
final status = await SyncService.instance.getSyncStatus();
```

---

### 4. **OFFLINE MANAGER** (`lib/services/offline_manager.dart`)

**Назначение**: Управляет режимом online/offline

**Функции**:
- ✅ Отслеживает наличие интернета
- ✅ Буферизирует операции когда интернета нет
- ✅ Автоматически синхронизирует при восстановлении сети
- ✅ Предоставляет Stream для UI (показать статус сети)

**Использование**:
```dart
// Проверить соединение
if (OfflineManager.instance.isOnline) {
  // Сеть есть
}

// Слушать изменения соединения
OfflineManager.instance.connectionStatus.listen((status) {
  if (status == ConnectionStatus.connected) {
    print('Интернет восстановлен!');
  } else if (status == ConnectionStatus.syncing) {
    print('Синхронизирую данные...');
  }
});

// Принудительная синхронизация
await OfflineManager.instance.manualSync();
```

---

## 🔄 Поток данных

### Когда интернет ЕСТЬ:
```
User Action (создать/изменить привычку)
  ↓
LocalDatabase (сохранить локально)
  ↓
API call (отправить на сервер сразу)
  ↓
✅ Все синхронизировано
```

### Когда интернета НЕТ:
```
User Action
  ↓
LocalDatabase (сохранить локально)
  ↓
SyncQueue (добавить в очередь)
  ↓
📵 Ожидание соединения...
```

### Когда интернет ВОССТАНОВИЛСЯ:
```
OfflineManager (обнаруживает сеть)
  ↓
SyncService.sync()
  ├─ PULL (получить изменения с сервера)
  └─ PUSH (отправить локальные изменения)
  ↓
✅ Все синхронизировано
```

---

## 📱 Использование в UI

### Пример: Создание новой привычки

```dart
// 1. Сохранить в локальную БД
final newHabit = Habit(
  userId: currentUserId,
  name: 'Спорт',
  description: '30 минут упражнений',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  localId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
  isSynced: false,
);

await LocalDatabase.instance.saveHabit(newHabit);

// 2. Если интернет есть - отправить на сервер
if (OfflineManager.instance.isOnline) {
  await SyncService.instance.sync();
} else {
  // Если интернета нет - это автоматически синхронизируется позже
  print('Привычка сохранена локально, синхронизируется при наличии интернета');
}

// 3. UI обновится из LocalDatabase
```

### Пример: Показать статус соединения

```dart
StreamBuilder<ConnectionStatus>(
  stream: OfflineManager.instance.connectionStatus,
  builder: (context, snapshot) {
    final status = snapshot.data ?? ConnectionStatus.connected;
    
    if (status == ConnectionStatus.syncing) {
      return CircularProgressIndicator();
    } else if (status == ConnectionStatus.disconnected) {
      return Text('🔴 Офлайн режим');
    } else {
      return Text('🟢 Онлайн');
    }
  },
)
```

---

## ⚙️ Инициализация

В `main.dart` автоматически:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Инициализируем локальную БД
  await LocalDatabase.instance.init();
  
  // 2. Инициализируем OfflineManager
  await OfflineManager.instance.init();
  
  // Приложение готово к работе!
  runApp(const MyApp());
}
```

---

## 🔐 Разрешение конфликтов

Когда одни и те же данные изменены на сервере и клиенте:

**Стратегия**: **Last-Write-Wins**

```
Сервер: Привычка обновлена в 15:00
Клиент: Привычка обновлена в 15:05 (локально без сети)

Результат: Применяется клиентская версия (позже по времени)
```

Сравнение происходит через `updatedAt` timestamp.

---

## 🚀 Следующие шаги

1. **Интегрировать с UI** - обновить HabitsScreen для использования LocalDatabase
2. **Обработка ошибок** - добавить try/catch в критических местах
3. **Retry logic** - повторить синхронизацию если она не удалась
4. **Soft deletes** - убедиться, что удаление работает корректно
5. **UI feedback** - показывать пользователю статус операций

---

## 📊 Структура БД

```
SQLite файл: habittracker.db

┌─────────────────────────────┐
│       Таблица habits        │
├─────────────────────────────┤
│ id TEXT                     │
│ userId TEXT                 │
│ name TEXT                   │
│ description TEXT            │
│ createdAt TEXT              │
│ updatedAt TEXT              │
│ isDeleted INTEGER (0/1)     │
│ localId TEXT (для новых)    │
│ isSynced INTEGER (0/1)      │
└─────────────────────────────┘

┌─────────────────────────────┐
│     Таблица habit_logs      │
├─────────────────────────────┤
│ id TEXT                     │
│ habitId TEXT (FK)           │
│ logDate TEXT                │
│ isCompleted INTEGER (0/1)   │
│ updatedAt TEXT              │
│ isSynced INTEGER (0/1)      │
│ localId TEXT (для новых)    │
└─────────────────────────────┘

┌─────────────────────────────┐
│      Таблица sync_queue     │
├─────────────────────────────┤
│ id TEXT (PRIMARY KEY)       │
│ entityType TEXT ('habit'...)│
│ entityId TEXT               │
│ operation TEXT (CRUD)       │
│ data TEXT (JSON)            │
│ createdAt TEXT              │
│ isSynced INTEGER (0/1)      │
└─────────────────────────────┘
```

---

## 🐛 Отладка

```dart
// Получить статистику БД
final stats = await LocalDatabase.instance.getStats();
print('Привычек: ${stats['habits']}');
print('Логов: ${stats['logs']}');
print('В очереди: ${stats['queue']}');

// Получить статус OfflineManager
final status = await OfflineManager.instance.getStatus();
print('Онлайн: ${status['isOnline']}');
print('Несинхронизированных: ${status['unsyncedHabits']}');

// Принудительно синхронизировать
await OfflineManager.instance.manualSync();
```

---

## 📝 Примечания

- ✅ Все операции асинхронные - используйте `await`
- ✅ LocalDatabase - singleton, инициализируется один раз
- ✅ OfflineManager автоматически синхронизирует при восстановлении сети
- ✅ Конфликты решаются на сервере через Last-Write-Wins
- ⚠️ Не забывайте вызвать `init()` для обоих сервисов в `main()`
