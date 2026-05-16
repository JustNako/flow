import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/habit_api_service.dart';
import '../../models/habit.dart';
import '../../widgets/notification_settings_sheet.dart';
import '../../services/time_tracking_service.dart';

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
  final Set<String> _togglingIds = {};

  // ─── Gradients palette ─────────────────────────────────────────────────────
  static const List<List<Color>> _gradients = [
    [Color(0xFF00B4DB), Color(0xFF0083B0)],
    [Color(0xFFFF512F), Color(0xFFDD2476)],
    [Color(0xFFDA22FF), Color(0xFF9733EE)],
    [Color(0xFF4776E6), Color(0xFF8E54E9)],
    [Color(0xFF11998E), Color(0xFF38EF7D)],
    [Color(0xFFFFB75E), Color(0xFFED8F03)],
  ];

  LinearGradient _gradientFor(String title) {
    final colors = _gradients[title.length % _gradients.length];
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
    try {
      final results = await Future.wait([
        _api.getHabits(),
        _api.getGlobalStreak(),
      ]);
      
      final habits = results[0] as List<Habit>;
      final globalStreak = results[1] as int;
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

      // Sort today habits: incomplete first
      todayHabits.sort((a, b) {
        if (a.isCompletedToday == b.isCompletedToday) return 0;
        return a.isCompletedToday ? 1 : -1;
      });

      if (mounted) {
        setState(() {
          _todayHabits = todayHabits;
          _otherHabits = otherHabits;
          _globalStreak = globalStreak;
        });
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
      backgroundColor: const Color(0xFF0C1017),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF512F)));
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
                  color: const Color(0xFF3A1F26),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.wifi_off_rounded, color: Color(0xFFFF5252), size: 48),
              ),
              const SizedBox(height: 20),
              const Text('Connection Error',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 14)),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: loadData,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFF7A55), Color(0xFFFF4848)]),
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
      color: const Color(0xFFFF512F),
      backgroundColor: const Color(0xFF161A22),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildProgressSummary()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Row(
                children: [
                  const Text("Today's Habits",
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (_totalCount > 0)
                    Text('$_completedCount / $_totalCount',
                      style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 14)),
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
                    const Text("Other Habits",
                      style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${_otherHabits.length}',
                        style: const TextStyle(color: Color(0xFF6B6B78), fontSize: 12, fontWeight: FontWeight.bold)),
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
    final dateStr = DateFormat('EEEE, MMMM d').format(now);
    final hour = now.hour;
    final greeting = hour < 12 ? 'Good Morning' : hour < 17 ? 'Good Afternoon' : 'Good Evening';
    final emoji = hour < 12 ? '☀️' : hour < 17 ? '👋' : '🌙';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$greeting $emoji',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(dateStr,
                  style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 14)),
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
                  color: const Color(0xFF161A22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: Color(0xFFDA22FF), size: 16),
                    const SizedBox(width: 4),
                    Text('$minutes m',
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            },
          ),
          // Notification bell
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (ctx) => const NotificationSettingsBottomSheet(),
              );
            },
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF161A22),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
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
          borderRadius: BorderRadius.circular(24),
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.8),
            radius: 1.8,
            colors: [const Color(0xFFFF512F).withOpacity(0.2), const Color(0xFF161A22)],
          ),
          border: Border.all(color: const Color(0xFFFF512F).withOpacity(0.08)),
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
                      backgroundColor: Colors.white.withOpacity(0.07),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFFF7A55)),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${(_overallProgress * 100).toInt()}%',
                        style: const TextStyle(color: Colors.white, fontSize: 18,
                            fontWeight: FontWeight.bold, height: 1)),
                      const Text('done', style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 11)),
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
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$_completedCount of $_totalCount habits completed today',
                    style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  // Streak badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF7A55), Color(0xFFFF4848)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFFFF524A).withOpacity(0.3),
                                blurRadius: 10, offset: const Offset(0, 3))
                          ],
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
          color: const Color(0xFF161A22),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.03)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFDA22FF).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_task, color: Color(0xFFDA22FF), size: 40),
            ),
            const SizedBox(height: 20),
            const Text('No habits today',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Tap the + button below to create\nyour first habit!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 14, height: 1.5)),
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
                ? const Color(0xFF0F1218)
                : (isComplete ? const Color(0xFF131A15) : const Color(0xFF141720)),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isOther 
                  ? Colors.white.withOpacity(0.02)
                  : (isComplete
                      ? const Color(0xFF00E676).withOpacity(0.15)
                      : Colors.white.withOpacity(0.04)),
            ),
          boxShadow: [
            BoxShadow(
              color: isComplete
                  ? const Color(0xFF00E676).withOpacity(0.05)
                  : Colors.black.withOpacity(0.15),
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
                          ? const Color(0xFF1C1F26)
                          : (isComplete ? const Color(0xFF1F3A2E) : null),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: (isComplete || isOther) ? [] : [
                        BoxShadow(color: gradient.colors.first.withOpacity(0.3),
                            blurRadius: 10, offset: const Offset(0, 3))
                      ],
                    ),
                    child: isToggling
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(isComplete ? Icons.check_circle_outline : icon,
                            color: isOther 
                                ? const Color(0xFF4A4E5A)
                                : (isComplete ? const Color(0xFF00E676) : Colors.white),
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
                            color: isComplete ? const Color(0xFF8A8F9E) : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            decoration: isComplete ? TextDecoration.lineThrough : null,
                            decorationColor: const Color(0xFF8A8F9E),
                          )),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.repeat, color: const Color(0xFF8A8F9E), size: 13),
                            const SizedBox(width: 4),
                            Text(repeatInfo,
                              style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 12)),
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
                          color: isComplete ? const Color(0xFF1F3A2E) : Colors.transparent,
                          border: Border.all(
                            color: isComplete
                                ? const Color(0xFF00E676)
                                : Colors.white.withOpacity(0.25),
                            width: 1.5,
                          ),
                        ),
                        child: isToggling
                            ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(color: Color(0xFF00E676), strokeWidth: 2))
                            : Icon(
                                isComplete ? Icons.check : null,
                                size: 18,
                                color: const Color(0xFF00E676)),
                      ),
                    )
                  else
                    const Icon(Icons.lock_outline, color: Color(0xFF3A3E4A), size: 18),
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
                          backgroundColor: Colors.white.withOpacity(0.06),
                          valueColor: AlwaysStoppedAnimation(
                            isComplete ? const Color(0xFF00E676) : gradient.colors.first,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${habit.targetDays} ${habit.unit ?? ''}'.trim(),
                      style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 11),
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
