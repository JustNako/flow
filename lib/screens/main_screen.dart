import 'dart:async';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'dashboard/dashboard_screen.dart';
import 'habits/habits_screen.dart';
import 'profile/profile_screen.dart';
import 'stats/stats_screen.dart';
import 'friends/friends_screen.dart';
import '../api/habit_api_service.dart';
import '../services/update_service.dart';
import '../services/widget_service.dart';
import '../theme/app_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey();
  final GlobalKey<StatsScreenState> _statsKey = GlobalKey();
  final GlobalKey<ProfileScreenState> _profileKey = GlobalKey();
  StreamSubscription<Uri?>? _widgetClickSubscription;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [
      DashboardScreen(key: _dashboardKey),
      StatsScreen(key: _statsKey),
      const FriendsScreen(),
      ProfileScreen(key: _profileKey),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdates(context);
      _handleInitialWidgetClick();
    });

    // Listen for widget tap events while app is open
    _widgetClickSubscription = HomeWidget.widgetClicked.listen(_handleWidgetUri);
  }

  @override
  void dispose() {
    _widgetClickSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      UpdateService.checkForUpdates(context);
    }
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) _dashboardKey.currentState?.loadData(showLoading: false);
    if (index == 1) _statsKey.currentState?.loadStats(showLoading: false);
    if (index == 3) _profileKey.currentState?.loadData(showLoading: false);
  }

  /// Called once on startup — handles the URI if app was launched from widget tap
  Future<void> _handleInitialWidgetClick() async {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    _handleWidgetUri(uri);
  }

  /// Toggles a habit when its row is tapped on the home screen widget
  Future<void> _handleWidgetUri(Uri? uri) async {
    if (uri == null) return;
    if (uri.host != 'completehabit') return;
    final habitId = uri.queryParameters['id'];
    if (habitId == null || habitId.isEmpty) return;

    try {
      await HabitApiService.instance.toggleHabit(habitId);
      // Switch to dashboard and refresh
      setState(() => _currentIndex = 0);
      // Small delay to let screen build before loading
      await Future.delayed(const Duration(milliseconds: 200));
      _dashboardKey.currentState?.loadData(showLoading: false);
    } catch (e) {
      debugPrint('[MainScreen] Widget toggle failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButton: Container(
        height: 64,
        width: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFFF7A55), Color(0xFFFF4848)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF524A).withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.of(context).pushNamed('/templates');
            if (result == true) {
              _dashboardKey.currentState?.loadData(showLoading: false);
            }
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          highlightElevation: 0,
          child: const Icon(Icons.add, color: Colors.white, size: 32),
        ),
      ),
      bottomNavigationBar: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          backgroundColor: context.colors.background,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          selectedItemColor: context.colors.textPrimary,
          unselectedItemColor: context.colors.textSecondary,
          selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.8),
          unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.8),
          onTap: _onTabTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_filled, size: 28),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded, size: 28),
              label: 'Stats',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline_rounded, size: 28),
              label: 'Friends',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded, size: 28),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
