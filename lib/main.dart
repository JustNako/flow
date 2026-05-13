import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/main_screen.dart';
import 'screens/habits/habits_screen.dart';
import 'screens/habits/templates_screen.dart';
import 'screens/habits/habit_details_screen.dart';
import 'screens/habits/add_habit_screen.dart';
import 'services/auth_service.dart';
import 'services/local_database.dart';
import 'services/offline_manager.dart';
import 'services/notification_service.dart';
import 'services/time_tracking_service.dart';
import 'utils/globals.dart';

void main() async {
  // Инициализируем все сервисы ДО запуска приложения
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Инициализируем локальную БД
  await LocalDatabase.instance.init();
  print('✅ LocalDatabase инициализирована');
  
  // 2. Инициализируем OfflineManager (для отслеживания сети)
  await OfflineManager.instance.init();
  print('✅ OfflineManager инициализирован');
  
  // 3. Инициализируем Firebase + уведомления
  try {
    await NotificationService.instance.initialize();
    print('✅ NotificationService инициализирован');
  } catch (e) {
    print('❌ Ошибка инициализации Firebase/Уведомлений: $e');
  }

  // 4. Инициализируем RevenueCat
  const revenueCatApiKey = 'test_RgpQjnYcUTRDpYDZOyAeswWHtQP';
  await Purchases.setLogLevel(LogLevel.debug);
  await Purchases.configure(PurchasesConfiguration(revenueCatApiKey));
  print('✅ RevenueCat инициализирован');

  // 5. Инициализируем Time Tracker
  await TimeTrackingService.instance.initialize();
  print('✅ TimeTrackingService инициализирован');

  // Теперь запускаем приложение
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Flow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthCheckScreen(),
      routes: {
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/main': (context) => const MainScreen(),
        '/templates': (context) => const TemplatesScreen(),
        '/habits': (context) => const HabitsScreen(),
        '/habit_details': (context) => const HabitDetailsScreen(),
        '/add_habit': (context) => const AddHabitScreen(),
      },
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});

  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  bool _isLoading = true;
  Widget? _destination;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool('onboarded') ?? false;
    final token = await AuthService.instance.getToken();

    Widget destination;

    if (token != null) {
      // Токен есть — пользователь залогинен, идём сразу в приложение
      destination = const MainScreen();
    } else if (!onboarded) {
      // Нет токена и впервые — показываем онбординг
      destination = const OnboardingScreen();
    } else {
      // Нет токена, но уже видели онбординг — экран входа
      destination = const LoginScreen();
    }

    if (mounted) {
      setState(() {
        _destination = destination;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C1017),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFDA22FF))),
      );
    }
    return _destination!;
  }
}