import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/habit_api_service.dart';
import '../../models/habit.dart';
import '../../widgets/notification_settings_sheet.dart';
import '../../services/time_tracking_service.dart';
import '../../services/update_service.dart';
import '../../services/widget_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final _api = HabitApiService.instance;

  List<Habit> _todayHabits = [];
  List<Habit> _otherHabits = [];
  bool _isLoading = true;
  int _globalStreak = 0;
  String? _error;
  String? _username;
  final Set<String> _togglingIds = {};

  LinearGradient _gradientFor(String title) {
    final gradients = context.colors.habitGradients;
    final colors = gradients[title.length % gradients.length];
    return LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight);
  }

  IconData _iconFor(String title) {
    final l = title.toLowerCase();
    if (l.contains('water')) return Icons.water_drop_outlined;
    if (l.contains('workout') || l.contains('gym') || l.contains('exercise')) return Icons.fitness_center;
    if (l.contains('read') || l.contains('book')) return Icons.book_outlined;
    if (l.contains('sleep') || l.contains('rest')) return Icons.nights_stay_outlined;
    if (l.contains('code') || l.contains('program')) return Icons.code;
    if (l.contains('meditat') || l.contains('mind')) return Icons.self_improvement;
    if (l.contains('run') || l.contains('walk')) return Icons.directions_run;
    return Icons.task_alt;
  }

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData({bool showLoading = true}) async {
    if (showLoading) setState(() { _isLoading = true; _error = null; });
    
    // Background update check on manual pull-to-refresh or tab navigation
    if (!showLoading && mounted) {
      UpdateService.checkForUpdates(context);
    }
    
    try {
      final results = await Future.wait([
        _api.getHabits(),
        _api.getGlobalStreak(),
        AuthService.instance.getUsername(),
      ]);
      
      final habits = results[0] as List<Habit>;
      final globalStreak = results[1] as int;
      final username = results[2] as String?;
      final today = DateTime.now();

      final todayHabits = <Habit>[];
      final otherHabits = <Habit>[];

      for (var h in habits) {
        if (h.isScheduledFor(today)) {
          todayHabits.add(h);
        } else {
          otherHabits.add(h);
        }
      }

      // Sort today habits: incomplete first, then by timeOfDay
      todayHabits.sort((a, b) {
        if (a.isCompletedToday != b.isCompletedToday) {
          return a.isCompletedToday ? 1 : -1;
        }
        
        if (a.timeOfDay != null && b.timeOfDay != null) {
          return a.timeOfDay!.compareTo(b.timeOfDay!);
        } else if (a.timeOfDay != null) {
          return -1;
        } else if (b.timeOfDay != null) {
          return 1;
        }
        
        return 0;
      });

      if (mounted) {
        setState(() {
          _todayHabits = todayHabits;
          _otherHabits = otherHabits;
          _globalStreak = globalStreak;
          _username = username;
        });

        // Fast & reliable local widget update using already fetched habits
        WidgetService.updateWidget(habits: habits);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (showLoading && mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleHabit(Habit habit) async {
    final id = habit.id;
    if (id == null) return;

    final index = _todayHabits.indexWhere((h) => h.id == id);
    if (index != -1) {
      setState(() {
        _togglingIds.add(id);
        _todayHabits[index] = _todayHabits[index].copyWith(
          isCompletedToday: !_todayHabits[index].isCompletedToday,
        );
      });
    }

    try {
      await _api.toggleHabit(id);
      await loadData(showLoading: false);
    } catch (e) {
      // Revert
      if (index != -1 && mounted) {
        setState(() {
          _todayHabits[index] = _todayHabits[index].copyWith(
            isCompletedToday: !_todayHabits[index].isCompletedToday,
          );
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _togglingIds.remove(id));
    }
  }

  // ─── Computed ──────────────────────────────────────────────────────────────
  int get _completedCount => _todayHabits.where((h) => h.isCompletedToday).length;
  int get _totalCount => _todayHabits.length;
  double get _overallProgress => _totalCount == 0 ? 0 : _completedCount / _totalCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: context.colors.primary ?? const Color(0xFFFF512F)));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.colors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.wifi_off_rounded, color: context.colors.danger, size: 48),
              ),
              const SizedBox(height: 20),
              Text('Connection Error',
                style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary, fontSize: 14)),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: loadData,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    color: context.colors.danger,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text('Try Again',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: loadData,
      color: context.colors.primary,
      backgroundColor: context.colors.card,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildProgressSummary()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Row(
                children: [
                  Text("Today's Habits",
                    style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (_totalCount > 0)
                    Text('$_completedCount / $_totalCount',
                      style: TextStyle(color: context.colors.textSecondary, fontSize: 14)),
                ],
              ),
            ),
          ),
          if (_todayHabits.isEmpty)
            SliverToBoxAdapter(child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _buildHabitCard(_todayHabits[i]),
                  childCount: _todayHabits.length,
                ),
              ),
            ),

          // ── Other Habits Section ──────────────────────────────────────────
          if (_otherHabits.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 12),
                child: Row(
                  children: [
                    Text("Other Habits",
                      style: TextStyle(color: context.colors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.colors.textSecondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${_otherHabits.length}',
                        style: TextStyle(color: context.colors.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) => _buildHabitCard(_otherHabits[i], isOther: true),
                  childCount: _otherHabits.length,
                ),
              ),
            ),
          ] else ...[
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMM d').format(now);
    final hour = now.hour;
    final isMorning = hour >= 5 && hour < 12;
    final isAfternoon = hour >= 12 && hour < 17;
    
    final timeGreeting = isMorning ? 'GOOD MORNING' : isAfternoon ? 'GOOD AFTERNOON' : 'GOOD EVENING';
    final emoji = isMorning ? '☀️' : isAfternoon ? '👋' : '🌙';
    
    final nameStr = _username != null && _username!.isNotEmpty ? ', ${_username!.toUpperCase()}' : '';
    final greeting = '$timeGreeting$nameStr $emoji';

    final leftHabits = _totalCount - _completedCount;
    final progressText = _totalCount == 0 
        ? "No habits today" 
        : leftHabits == 0 
            ? "All done! 🎉"
            : "$leftHabits habits left";

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting,
                  style: const TextStyle(
                    color: Color(0xFFFF7A55), // Sleek coral accent
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  )),
                const SizedBox(height: 4),
                Text(progressText,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  )),
                const SizedBox(height: 2),
                Text(dateStr,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  )),
              ],
            ),
          ),
          // Time Tracker Pill
          ValueListenableBuilder<int>(
            valueListenable: TimeTrackingService.instance.totalSecondsToday,
            builder: (context, seconds, child) {
              if (seconds == 0) return const SizedBox.shrink();
              final minutes = (seconds / 60).floor();
              
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: Color(0xFFE8845C), size: 16),
                    const SizedBox(width: 4),
                    Text('$minutes m',
                      style: TextStyle(color: context.colors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            },
          ),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: context.colors.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.colors.border),
              ),
              child: Icon(Icons.settings_outlined, color: context.colors.textPrimary, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Progress Summary ──────────────────────────────────────────────────────
  Widget _buildProgressSummary() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            // Circular progress
            SizedBox(
              width: 88, height: 88,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 88, height: 88,
                    child: CircularProgressIndicator(
                      value: _overallProgress,
                      strokeWidth: 7,
                      backgroundColor: context.colors.textSecondary.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation(context.colors.primary ?? const Color(0xFFFF7A55)),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${(_overallProgress * 100).toInt()}%',
                        style: TextStyle(color: context.colors.textPrimary, fontSize: 18,
                            fontWeight: FontWeight.bold, height: 1)),
                      Text('done', style: TextStyle(color: context.colors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _completedCount == _totalCount && _totalCount > 0
                        ? 'All done! 🎉'
                        : _completedCount == 0
                            ? "Let's get started!"
                            : 'Keep going!',
                    style: TextStyle(color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_completedCount of $_totalCount habits completed today',
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  // Streak badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: context.colors.danger,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.local_fire_department, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text('$_globalStreak day streak',
                              style: const TextStyle(color: Colors.white, fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colors.primary?.withOpacity(0.1) ?? const Color(0xFFE8845C).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_task, color: context.colors.primary ?? const Color(0xFFE8845C), size: 40),
            ),
            const SizedBox(height: 20),
            Text('No habits today',
              style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Tap the + button below to create\nyour first habit!',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary, fontSize: 14, height: 1.5)),
          ],
        ),
      ),
    );
  }

  // ─── Habit Card ────────────────────────────────────────────────────────────
  Widget _buildHabitCard(Habit habit, {bool isOther = false}) {
    final isComplete = habit.isCompletedToday;
    final isToggling = _togglingIds.contains(habit.id);
    final gradient = _gradientFor(habit.title);
    final icon = _iconFor(habit.title);
    final progress = habit.progress;
    final repeatInfo = habit.repeatLabel;

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).pushNamed('/habit_details', arguments: habit);
        // Silently refresh when user comes back — covers toggle, delete, etc.
        if (mounted) loadData(showLoading: false);
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isOther ? 0.6 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: isOther 
                ? context.colors.cardSecondary
                : (isComplete ? context.colors.success.withOpacity(0.05) : context.colors.card),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isOther 
                  ? context.colors.border.withOpacity(0.5)
                  : (isComplete
                      ? context.colors.success.withOpacity(0.3)
                      : context.colors.border),
            ),
          boxShadow: [
            BoxShadow(
              color: isComplete
                  ? context.colors.success.withOpacity(0.05)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                children: [
                  // ── Icon ────────────────────────────────────────────────
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      gradient: (isComplete || isOther) ? null : gradient,
                      color: isOther 
                          ? context.colors.iconBg
                          : (isComplete ? context.colors.success.withOpacity(0.1) : null),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: (isComplete || isOther) ? [] : [
                        BoxShadow(color: gradient.colors.first.withOpacity(0.3),
                            blurRadius: 10, offset: const Offset(0, 3))
                      ],
                    ),
                    child: isToggling
                        ? Padding(
                            padding: const EdgeInsets.all(14),
                            child: CircularProgressIndicator(color: context.colors.textPrimary, strokeWidth: 2))
                        : Icon(isComplete ? Icons.check_circle_outline : icon,
                            color: isOther 
                                ? context.colors.textSecondary
                                : (isComplete ? context.colors.success : Colors.white),
                            size: 26),
                  ),
                  const SizedBox(width: 14),

                  // ── Title + Subtitle ─────────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(habit.title,
                          style: TextStyle(
                            color: isComplete ? context.colors.textSecondary : context.colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            decoration: isComplete ? TextDecoration.lineThrough : null,
                            decorationColor: context.colors.textSecondary,
                          )),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (habit.timeOfDay != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isComplete ? context.colors.textSecondary : gradient.colors.first).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.access_time, 
                                      color: isComplete ? context.colors.textSecondary : gradient.colors.first, size: 12),
                                    const SizedBox(width: 4),
                                    Text(habit.timeOfDay!, 
                                      style: TextStyle(
                                        color: isComplete ? context.colors.textSecondary : gradient.colors.first, 
                                        fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Icon(Icons.repeat, color: context.colors.textSecondary, size: 13),
                            const SizedBox(width: 4),
                            Text(repeatInfo,
                              style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // ── Toggle Button ────────────────────────────────────────
                  if (!isOther)
                    GestureDetector(
                      onTap: isToggling ? null : () => _toggleHabit(habit),
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isComplete ? context.colors.success.withOpacity(0.1) : Colors.transparent,
                          border: Border.all(
                            color: isComplete
                                ? context.colors.success
                                : context.colors.border,
                            width: 1.5,
                          ),
                        ),
                        child: isToggling
                            ? Padding(
                                padding: const EdgeInsets.all(8),
                                child: CircularProgressIndicator(color: context.colors.success, strokeWidth: 2))
                            : Icon(
                                isComplete ? Icons.check : null,
                                size: 18,
                                color: context.colors.success),
                      ),
                    )
                  else
                    Icon(Icons.lock_outline, color: context.colors.textSecondary, size: 18),
                ],
              ),

              // ── Progress Bar ─────────────────────────────────────────────
              if (habit.targetDays > 0 && habit.unit != null && habit.unit!.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: isComplete ? 1.0 : 0.0,
                          minHeight: 5,
                          backgroundColor: context.colors.textSecondary.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation(
                            isComplete ? context.colors.success : gradient.colors.first,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${habit.targetDays} ${habit.unit ?? ''}'.trim(),
                      style: TextStyle(color: context.colors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
}
