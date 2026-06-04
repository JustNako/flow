import 'dart:async';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'dashboard/dashboard_screen.dart';
import 'habits/ai_generator_screen.dart';
import 'stats/stats_screen.dart';
import 'habits/templates_screen.dart';
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
  int _previousIndex = 0;
  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey();
  StreamSubscription<Uri?>? _widgetClickSubscription;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [
      DashboardScreen(key: _dashboardKey),
      const AiGeneratorScreen(),
      const StatsScreen(),
      const TemplatesScreen(),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdates(context);
      _handleInitialWidgetClick();
    });

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
    if (_currentIndex == index) return;
    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex = index;
    });
    if (index == 0) _dashboardKey.currentState?.loadData(showLoading: false);
  }

  Future<void> _handleInitialWidgetClick() async {
    final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
    _handleWidgetUri(uri);
  }

  Future<void> _handleWidgetUri(Uri? uri) async {
    if (uri == null) return;
    if (uri.host != 'completehabit') return;
    final habitId = uri.queryParameters['id'];
    if (habitId == null || habitId.isEmpty) return;

    try {
      await HabitApiService.instance.toggleHabit(habitId);
      setState(() {
        _previousIndex = _currentIndex;
        _currentIndex = 0;
      });
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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (Widget child, Animation<double> animation) {
          final isEntering = child.key == ValueKey(_currentIndex);
          final slideDirection = _currentIndex > _previousIndex ? 1.0 : -1.0;
          
          final inOffset = Tween<Offset>(begin: Offset(slideDirection, 0.0), end: Offset.zero)
              .animate(animation);
          final outOffset = Tween<Offset>(begin: Offset(-slideDirection, 0.0), end: Offset.zero)
              .animate(animation);

          return SlideTransition(
            position: isEntering ? inOffset : outOffset,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: _CustomBottomNav(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

class _CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _CustomBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  Color _getColor(int index, BuildContext context) {
    if (index == 0) return context.colors.sage;
    if (index == 1) return context.colors.lavender;
    if (index == 2) return context.colors.gold;
    return context.colors.terracotta;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        border: Border(top: BorderSide(color: context.colors.border, width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Stack(
            children: [
              Row(
                children: [
                  _NavItem(
                    icon: Icons.spa_rounded,
                    label: 'Home',
                    isSelected: currentIndex == 0,
                    activeColor: context.colors.sage,
                    onTap: () => onTap(0),
                  ),
                  _NavItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Flow AI',
                    isSelected: currentIndex == 1,
                    activeColor: context.colors.lavender,
                    onTap: () => onTap(1),
                  ),
                  _NavItem(
                    icon: Icons.bar_chart_rounded,
                    label: 'Insights',
                    isSelected: currentIndex == 2,
                    activeColor: context.colors.gold,
                    onTap: () => onTap(2),
                  ),
                  _NavItem(
                    icon: Icons.grid_view_rounded,
                    label: 'Library',
                    isSelected: currentIndex == 3,
                    activeColor: context.colors.terracotta,
                    onTap: () => onTap(3),
                  ),
                ],
              ),
              // Sliding top indicator
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                top: 0,
                left: (MediaQuery.of(context).size.width / 4) * currentIndex,
                width: MediaQuery.of(context).size.width / 4,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 32,
                    height: 3,
                    decoration: BoxDecoration(
                      color: _getColor(currentIndex, context),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
                      boxShadow: [
                        BoxShadow(
                          color: _getColor(currentIndex, context).withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? activeColor : context.colors.textSecondary.withOpacity(0.5);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
