import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/main_screen.dart';
import 'screens/habits/habits_screen.dart';
import 'screens/habits/templates_screen.dart';
import 'screens/habits/habit_details_screen.dart';
import 'screens/habits/add_habit_screen.dart';
import 'screens/splash/splash_screen.dart';
import 'services/widget_service.dart';
import 'utils/globals.dart';

void main() async {
  // Инициализируем Flutter биндинги
  WidgetsFlutterBinding.ensureInitialized();
  
  // Регистрация коллбэка для виджетов (работает в фоне)
  HomeWidget.registerInteractivityCallback(WidgetService.backgroundCallback);
  
  // Запускаем приложение немедленно. 
  // Вся инициализация тяжелых сервисов теперь происходит 
  // динамически внутри красивого сплэш-экрана.
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
      home: const SplashScreen(),
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