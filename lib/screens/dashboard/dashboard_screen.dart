import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../api/habit_api_service.dart';
import '../../api/friends_api_service.dart';
import '../../models/habit.dart';
import '../../services/auth_service.dart';
import '../../services/offline_manager.dart';
import '../../services/update_service.dart';
import '../../services/widget_service.dart';
import '../../services/local_database.dart';
import '../../theme/app_theme.dart';

const _kGold = Color(0xFFFFD700);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  final _api = HabitApiService.instance;
  final _authService = AuthService.instance;
  final _offlineManager = OfflineManager.instance;

  List<Habit> _todayHabits = [];
  List<Habit> _otherHabits = [];
  bool _isLoading = false;
  bool _isLoadingData = false; // guard against concurrent loadData() calls
  String? _error;
  String? _username;
  int _pendingRequestsCount = 0;
  final Set<String> _togglingIds = {};

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _progressAnimation = Tween<double>(begin: 0, end: 0).animate(CurvedAnimation(parent: _progressController, curve: Curves.easeOutBack));
    loadData();
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  void _updateProgressAnimation(double progress) {
    _progressAnimation = Tween<double>(begin: _progressAnimation.value, end: progress)
        .animate(CurvedAnimation(parent: _progressController, curve: Curves.easeOutBack));
    _progressController.forward(from: 0);
  }

  /// Мгновенно обновляет UI из локальной базы данных без ожидания сети.
  /// Вызывается при resume приложения чтобы сразу показать актуальное состояние из виджета.
  Future<void> loadFromLocal() async {
    try {
      final userId = await AuthService.instance.getUserId();
      if (userId == null) return;
      final habits = await LocalDatabase.instance.getHabitsWithCompletionStatus(userId);
      if (!mounted) return;
      final today = DateTime.now();
      final todayHabits = habits.where((h) => h.isScheduledFor(today)).toList();
      final otherHabits = habits.where((h) => !h.isScheduledFor(today)).toList();

      todayHabits.sort((a, b) {
        if (a.isCompletedToday != b.isCompletedToday) return a.isCompletedToday ? 1 : -1;
        if (a.timeOfDay != null && b.timeOfDay != null) return a.timeOfDay!.compareTo(b.timeOfDay!);
        if (a.timeOfDay != null) return -1;
        if (b.timeOfDay != null) return 1;
        return a.title.compareTo(b.title);
      });

      setState(() {
        _todayHabits = todayHabits;
        _otherHabits = otherHabits;
      });

      final total = todayHabits.length;
      final completed = todayHabits.where((h) => h.isCompletedToday).length;
      _updateProgressAnimation(total == 0 ? 0 : completed / total);
    } catch (e) {
      debugPrint('[Dashboard] loadFromLocal error: $e');
    }
  }

  Future<void> loadData({bool showLoading = true}) async {
    if (_isLoadingData) return; // prevent concurrent rebuilds
    _isLoadingData = true;
    if (showLoading) setState(() { _isLoading = true; _error = null; });

    if (!showLoading && mounted) {
      UpdateService.checkForUpdates(context);
    }
    
    try {
      final results = await Future.wait([
        _api.getHabits(),
        _authService.getUsername(),
        FriendsApiService().getPendingRequests().catchError((_) => <FriendRequestDto>[]),
      ]);
      
      final habits = results[0] as List<Habit>;
      final username = results[1] as String?;
      final pendingCount = (results[2] as List<FriendRequestDto>).length;
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

      todayHabits.sort((a, b) {
        // 1. Primary sort: completed habits go to the very bottom
        if (a.isCompletedToday != b.isCompletedToday) {
          return a.isCompletedToday ? 1 : -1;
        }
        // 2. Secondary sort: chronological by timeOfDay
        if (a.timeOfDay != null && b.timeOfDay != null) {
          return a.timeOfDay!.compareTo(b.timeOfDay!);
        } else if (a.timeOfDay != null) {
          return -1;
        } else if (b.timeOfDay != null) {
          return 1;
        }
        // 3. Tertiary sort: alphabetical by title if neither has a time
        return a.title.compareTo(b.title);
      });

      otherHabits.sort((a, b) {
        // 1. Primary sort: completed habits go to the very bottom
        if (a.isCompletedToday != b.isCompletedToday) {
          return a.isCompletedToday ? 1 : -1;
        }
        // 2. Secondary sort: chronological by timeOfDay
        if (a.timeOfDay != null && b.timeOfDay != null) {
          return a.timeOfDay!.compareTo(b.timeOfDay!);
        } else if (a.timeOfDay != null) {
          return -1;
        } else if (b.timeOfDay != null) {
          return 1;
        }
        // 3. Tertiary sort: alphabetical by title if neither has a time
        return a.title.compareTo(b.title);
      });

      setState(() {
        _todayHabits = todayHabits;
        _otherHabits = otherHabits;
        _username = username;
        _pendingRequestsCount = pendingCount;
      });
      
      int total = _todayHabits.length;
      int completed = _todayHabits.where((h) => h.isCompletedToday).length;
      double progress = total == 0 ? 0 : completed / total;
      _updateProgressAnimation(progress);

      WidgetService.updateWidget();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _isLoadingData = false;
    }
  }

  Future<void> _toggleHabit(Habit habit) async {
    final id = habit.id;
    if (id == null) return;
    if (_togglingIds.contains(id)) return;

    HapticFeedback.mediumImpact();
    setState(() => _togglingIds.add(id));
    try {
      await _api.toggleHabit(id, habitLocalId: habit.localId);
      
      // Update local state immediately & sort instantly so the user sees the card transition seamlessly
      setState(() {
        final index = _todayHabits.indexWhere((h) => h.id == id);
        if (index != -1) {
          final h = _todayHabits[index];
          final wasCompleted = h.isCompletedToday;
          _todayHabits[index] = h.copyWith(
            isCompletedToday: !wasCompleted,
            completedDays: wasCompleted ? h.completedDays - 1 : h.completedDays + 1,
            currentStreak: wasCompleted ? 0 : h.currentStreak + 1,
          );
        }

        final otherIndex = _otherHabits.indexWhere((h) => h.id == id);
        if (otherIndex != -1) {
          final h = _otherHabits[otherIndex];
          final wasCompleted = h.isCompletedToday;
          _otherHabits[otherIndex] = h.copyWith(
            isCompletedToday: !wasCompleted,
            completedDays: wasCompleted ? h.completedDays - 1 : h.completedDays + 1,
            currentStreak: wasCompleted ? 0 : h.currentStreak + 1,
          );
        }
        
        // Silent instant re-sort
        _todayHabits.sort((a, b) {
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
          return a.title.compareTo(b.title);
        });

        _otherHabits.sort((a, b) {
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
          return a.title.compareTo(b.title);
        });
      });
      
      int total = _todayHabits.length;
      int completed = _todayHabits.where((h) => h.isCompletedToday).length;
      double progress = total == 0 ? 0 : completed / total;
      _updateProgressAnimation(progress);

      WidgetService.updateWidget();
      
      // Silently reload/sync in the background without showing any loading spinner
      await loadData(showLoading: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: context.colors.terracotta, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingIds.remove(id));
    }
  }

  Future<void> _deleteHabit(Habit habit) async {
    final id = habit.id;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Delete habit?', style: TextStyle(color: context.colors.textPrimary)),
        content: Text('"${habit.title}" will be permanently deleted.', style: TextStyle(color: context.colors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: context.colors.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: context.colors.terracotta))),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _api.deleteHabit(id);
      setState(() {
        _todayHabits.removeWhere((h) => h.id == id);
        _otherHabits.removeWhere((h) => h.id == id);
      });
      
      int total = _todayHabits.length;
      int completed = _todayHabits.where((h) => h.isCompletedToday).length;
      double progress = total == 0 ? 0 : completed / total;
      _updateProgressAnimation(progress);
      
      WidgetService.updateWidget();
      
      // Silently reload in the background to ensure consistency
      await loadData(showLoading: false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: context.colors.terracotta, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _navigateToAddHabit() async {
    final result = await Navigator.of(context).pushNamed('/templates');
    if (result == true && mounted) {
      // 1. Instantly show the new habit from local DB (no network wait → no black screen)
      await loadFromLocal();
      // 2. Silently sync with server in the background
      loadData(showLoading: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int total = _todayHabits.length;
    int completed = _todayHabits.where((h) => h.isCompletedToday).length;
    bool isAllDone = total > 0 && completed == total;

    final hour = DateTime.now().hour;
    String greeting;
    if (hour >= 5 && hour < 12) {
      greeting = 'Good morning ';
    } else if (hour >= 12 && hour < 18) {
      greeting = 'Good afternoon ';
    } else if (hour >= 18 && hour < 22) {
      greeting = 'Good evening ';
    } else {
      greeting = 'Good night ';
    }

    if (total > 0) {
      if (isAllDone) greeting = 'Beautiful work ';
      else if (completed > 0) greeting = "You're flowing ";
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildConnectionBanner(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: loadData,
                color: context.colors.sage,
                backgroundColor: context.colors.card,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        DateFormat('EEE, MMM d').format(DateTime.now()).toUpperCase(),
                                        style: TextStyle(color: context.colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          showModalBottomSheet(
                                            context: context,
                                            backgroundColor: Colors.transparent,
                                            builder: (ctx) => _FlowMenuSheet(
                                              pendingRequestsCount: _pendingRequestsCount,
                                              onRefresh: () => loadData(showLoading: false),
                                            ),
                                          );
                                        },
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(color: context.colors.card, shape: BoxShape.circle, border: Border.all(color: context.colors.border)),
                                              child: Icon(Icons.apps_rounded, color: context.colors.textSecondary, size: 20),
                                            ),
                                            if (_pendingRequestsCount > 0)
                                              Positioned(
                                                top: -2,
                                                right: -2,
                                                child: Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: BoxDecoration(
                                                    color: context.colors.terracotta,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: context.colors.background, width: 1.5),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      )
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 500),
                                    child: Text(
                                      greeting,
                                      key: ValueKey(greeting),
                                      style: GoogleFonts.playfairDisplay(color: context.colors.textPrimary, fontSize: 32, fontWeight: FontWeight.w700, height: 1.1),
                                    ),
                                  ),
                                  Text(
                                    '${_username ?? 'there'}.',
                                    style: GoogleFonts.playfairDisplay(
                                      color: isAllDone ? context.colors.sage.withOpacity(0.5) : context.colors.textSecondary,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      height: 1.1,
                                    ),
                                  ),
                                  SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded, color: context.colors.sage.withOpacity(0.6), size: 12),
                                      SizedBox(width: 6),
                                      Text(
                                        'Swipe left on a habit to view details',
                                        style: GoogleFonts.inter(
                                          color: context.colors.textSecondary.withOpacity(0.6),
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 16),
                            // Thin animated ring
                            AnimatedBuilder(
                              animation: _progressAnimation,
                              builder: (context, child) {
                                final val = _progressAnimation.value;
                                Color ringColor = Color.lerp(context.colors.lavender, context.colors.sage, val)!;
                                if (val > 0.99) ringColor = _kGold;

                                return SizedBox(
                                  width: 72,
                                  height: 72,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      SizedBox(
                                        width: 72,
                                        height: 72,
                                        child: CircularProgressIndicator(value: 1.0, strokeWidth: 1.5, color: context.colors.border),
                                      ),
                                      SizedBox(
                                        width: 72,
                                        height: 72,
                                        child: CircularProgressIndicator(
                                          value: val,
                                          strokeWidth: 2,
                                          strokeCap: StrokeCap.round,
                                          color: ringColor,
                                        ),
                                      ),
                                      if (val > 0.99)
                                        TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.0, end: 1.0),
                                          duration: const Duration(milliseconds: 600),
                                          curve: Curves.elasticOut,
                                          builder: (context, scale, child) {
                                            return Transform.scale(
                                              scale: scale,
                                              child: Text('✨', style: TextStyle(fontSize: 24)),
                                            );
                                          },
                                        )
                                      else
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('$completed', style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold, height: 1.0)),
                                            Text('of', style: TextStyle(color: context.colors.textSecondary, fontSize: 10, height: 1.0)),
                                            Text('$total', style: TextStyle(color: context.colors.textSecondary, fontSize: 10, height: 1.0)),
                                          ],
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Today's habits",
                              style: GoogleFonts.playfairDisplay(color: context.colors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isAllDone ? _kGold.withOpacity(0.15) : context.colors.border.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                                border: isAllDone ? Border.all(color: _kGold.withOpacity(0.3)) : null,
                                boxShadow: isAllDone ? [BoxShadow(color: _kGold.withOpacity(0.2), blurRadius: 10)] : [],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: isAllDone ? _kGold : context.colors.textSecondary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    '$completed of $total',
                                    style: TextStyle(color: isAllDone ? _kGold : context.colors.textSecondary, fontSize: 11, fontWeight: isAllDone ? FontWeight.bold : FontWeight.normal),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                    if (_isLoading)
                      SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: context.colors.sage)))
                    else if (_error != null)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, color: context.colors.terracotta, size: 48),
                              SizedBox(height: 16),
                              Text(_error!, style: TextStyle(color: context.colors.textSecondary)),
                              TextButton.icon(onPressed: loadData, icon: Icon(Icons.refresh, color: context.colors.sage), label: Text('Retry', style: TextStyle(color: context.colors.sage))),
                            ],
                          ),
                        ),
                      )
                    else if (_todayHabits.isEmpty && _otherHabits.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.spa_outlined, color: context.colors.textSecondary, size: 64),
                              SizedBox(height: 16),
                              Text('No habits today', style: TextStyle(color: context.colors.textPrimary, fontSize: 18)),
                              SizedBox(height: 8),
                              Text('Enjoy your day or add a new habit', style: TextStyle(color: context.colors.textSecondary)),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      if (_todayHabits.isNotEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) {
                                final habit = _todayHabits[i];
                                return _ZenHabitCard(
                                  habit: habit,
                                  isToggling: _togglingIds.contains(habit.id),
                                  onToggle: () => _toggleHabit(habit),
                                  onDelete: () => _deleteHabit(habit),
                                  onDetails: () async {
                                    final result = await Navigator.of(context).pushNamed(
                                      '/habit_details',
                                      arguments: habit,
                                    );
                                    if (result == true && mounted) loadData(showLoading: false);
                                  },
                                );
                              },
                              childCount: _todayHabits.length,
                            ),
                          ),
                        )
                      else
                        SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: context.colors.card.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: context.colors.border),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.spa_outlined, color: context.colors.textSecondary, size: 36),
                                SizedBox(height: 8),
                                Text(
                                  'No habits scheduled for today',
                                  style: GoogleFonts.inter(color: context.colors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      if (_otherHabits.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
                            child: Text(
                              "Other habits",
                              style: GoogleFonts.playfairDisplay(color: context.colors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) {
                                final habit = _otherHabits[i];
                                return _ZenHabitCard(
                                  habit: habit,
                                  isToggling: _togglingIds.contains(habit.id),
                                  onToggle: () => _toggleHabit(habit),
                                  onDelete: () => _deleteHabit(habit),
                                  onDetails: () async {
                                    final result = await Navigator.of(context).pushNamed(
                                      '/habit_details',
                                      arguments: habit,
                                    );
                                    if (result == true && mounted) loadData(showLoading: false);
                                  },
                                );
                              },
                              childCount: _otherHabits.length,
                            ),
                          ),
                        ),
                      ],
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 120),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _FloatingAddButton(onTap: _navigateToAddHabit),
    );
  }

  Widget _buildConnectionBanner() {
    return StreamBuilder<ConnectionStatus>(
      stream: _offlineManager.connectionStatus,
      builder: (context, snapshot) {
        final status = snapshot.data;
        if (status == null || status == ConnectionStatus.connected) return SizedBox.shrink();
        final (color, icon, text) = switch (status) {
          ConnectionStatus.disconnected => (context.colors.terracotta, Icons.wifi_off, 'Offline mode — changes will sync when connected'),
          ConnectionStatus.syncing => (context.colors.lavender, Icons.sync, 'Syncing...'),
          _ => (context.colors.sage, Icons.wifi, 'Online'),
        };
        return Container(
          color: color.withOpacity(0.15),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(text, style: TextStyle(color: color, fontSize: 12))),
            ],
          ),
        );
      },
    );
  }
}

// ── Floating Action Button with glow & rotation ─────────────────────────────

class _FloatingAddButton extends StatefulWidget {
  final VoidCallback onTap;
  const _FloatingAddButton({required this.onTap});

  @override
  State<_FloatingAddButton> createState() => _FloatingAddButtonState();
}

class _FloatingAddButtonState extends State<_FloatingAddButton> with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  
  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) => _anim.forward();
  void _handleTapUp(TapUpDetails details) { _anim.reverse(); widget.onTap(); }
  void _handleTapCancel() => _anim.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          final scale = 1.0 - (_anim.value * 0.05);
          final rotate = _anim.value * (math.pi / 4); // 45 degrees
          
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [context.colors.sage, context.colors.lavender],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Transform.rotate(
                angle: rotate,
                child: Icon(Icons.add_rounded, color: context.colors.background, size: 32),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Ultra-rounded Bento Habit Card ───────────────────────────────────────────

class _ZenHabitCard extends StatelessWidget {
  final Habit habit;
  final bool isToggling;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onDetails;

  const _ZenHabitCard({
    required this.habit,
    required this.isToggling,
    required this.onToggle,
    required this.onDelete,
    required this.onDetails,
  });

  // Same order as _iconOptions in AddHabitScreen
  static const List<IconData> _kHabitIcons = [
    Icons.water_drop_outlined,   // 0 Water
    Icons.fitness_center,        // 1 Workout
    Icons.book_outlined,         // 2 Read
    Icons.nights_stay_outlined,  // 3 Sleep
    Icons.favorite_border,       // 4 Health
    Icons.local_cafe_outlined,   // 5 Coffee
    Icons.restaurant_outlined,   // 6 Diet
    Icons.psychology_outlined,   // 7 Mind
    Icons.code,                  // 8 Code
    Icons.directions_run,        // 9 Run
    Icons.self_improvement,      // 10 Meditate
    Icons.music_note_outlined,   // 11 Music
    Icons.bed_outlined,          // 12 Bed
    Icons.accessibility_new,     // 13 Stretch
    Icons.directions_walk,       // 14 Walk
    Icons.menu_book,             // 15 Book
    Icons.computer,              // 16 Work
    Icons.edit_note,             // 17 Plan
  ];

  static const List<Color> _kHabitColors = [
    Color(0xFF64B5F6), // 0 Water — blue
    Color(0xFFEF9A9A), // 1 Workout — red
    Color(0xFFFFB74D), // 2 Read — amber
    Color(0xFFB39DDB), // 3 Sleep — purple
    Color(0xFFF48FB1), // 4 Health — pink
    Color(0xFFFFCC80), // 5 Coffee — light orange
    Color(0xFFA5D6A7), // 6 Diet — green
    Color(0xFF80CBC4), // 7 Mind — teal
    Color(0xFF90CAF9), // 8 Code — light blue
    Color(0xFFEF9A9A), // 9 Run — red
    Color(0xFFA5D6A7), // 10 Meditate — green
    Color(0xFFCE93D8), // 11 Music — lilac
    Color(0xFFB39DDB), // 12 Bed — purple
    Color(0xFF80DEEA), // 13 Stretch — cyan
    Color(0xFF80CBC4), // 14 Walk — teal
    Color(0xFFFFB74D), // 15 Book — amber
    Color(0xFF90CAF9), // 16 Work — blue
    Color(0xFFA5D6A7), // 17 Plan — green
  ];

  @override
  Widget build(BuildContext context) {
    final isDone = habit.isCompletedToday;
    final idx = habit.iconIndex.clamp(0, _kHabitIcons.length - 1);
    final iconData = _kHabitIcons[idx];
    final iconColor = _kHabitColors[idx];

    return Dismissible(
      key: Key(habit.id ?? habit.title),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: context.colors.lavender.withOpacity(0.15),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.colors.lavender.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, color: context.colors.lavender),
            SizedBox(height: 4),
            Text('Details', style: TextStyle(color: context.colors.lavender, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onDetails();
        return false; // don't actually dismiss
      },
      child: GestureDetector(
        onLongPress: onDelete,
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDone ? context.colors.card.withOpacity(0.5) : context.colors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDone ? context.colors.sage.withOpacity(0.5) : context.colors.border,
              width: 1.5,
            ),
            boxShadow: isDone ? [
              BoxShadow(
                color: context.colors.sage.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ] : [],
          ),
          child: Row(
            children: [
              // Emoji / Icon tile with depth
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      isDone ? context.colors.sage.withOpacity(0.2) : const Color(0xFF333333),
                      isDone ? context.colors.sage.withOpacity(0.05) : const Color(0xFF222222),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(2, 4),
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(-1, -1),
                    )
                  ],
                ),
                child: Center(
                  child: Icon(
                    iconData,
                    color: isDone ? context.colors.sage : iconColor.withOpacity(0.8),
                    size: 24,
                  ),
                ),
              ),
              SizedBox(width: 16),
              // Text and Streaks
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        color: isDone ? context.colors.textSecondary.withOpacity(0.6) : context.colors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: context.colors.sage.withOpacity(0.5),
                        decorationThickness: 2,
                        fontFamily: GoogleFonts.inter().fontFamily,
                      ),
                      child: Text(habit.title),
                    ),
                    SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          habit.unit != null && habit.unit!.isNotEmpty && habit.unit!.toLowerCase() != 'null'
                            ? '${habit.targetDays} ${habit.unit}'
                            : '${habit.targetDays} time${habit.targetDays > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: isDone ? context.colors.textSecondary.withOpacity(0.3) : context.colors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        if (habit.timeOfDay != null && habit.timeOfDay!.isNotEmpty && habit.timeOfDay!.toLowerCase() != 'null') ...[
                          Text('·', style: TextStyle(color: isDone ? context.colors.textSecondary.withOpacity(0.2) : context.colors.border, fontSize: 13)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time_rounded, size: 13, color: isDone ? context.colors.textSecondary.withOpacity(0.3) : context.colors.sage),
                              SizedBox(width: 4),
                              Text(
                                habit.timeOfDay!,
                                style: TextStyle(color: isDone ? context.colors.textSecondary.withOpacity(0.3) : context.colors.sage, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                        if (habit.currentStreak > 0) ...[
                          Text('·', style: TextStyle(color: isDone ? context.colors.textSecondary.withOpacity(0.2) : context.colors.border, fontSize: 13)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.colors.terracotta.withOpacity(isDone ? 0.05 : 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.whatshot_rounded, size: 12, color: isDone ? context.colors.textSecondary.withOpacity(0.5) : context.colors.terracotta),
                                SizedBox(width: 4),
                                Text('${habit.currentStreak}', style: TextStyle(color: isDone ? context.colors.textSecondary.withOpacity(0.5) : context.colors.terracotta, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),

                  ],
                ),
              ),
              // Visual Swipe Hint & Checkmark
              Icon(Icons.chevron_left_rounded, color: context.colors.textSecondary.withOpacity(0.2), size: 16),
              SizedBox(width: 4),
              // Animated spring checkmark
              if (isToggling)
                SizedBox(width: 32, height: 32, child: Padding(padding: EdgeInsets.all(6), child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.sage)))
              else
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: isDone ? 1.0 : 0.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                  builder: (context, val, child) {
                    return Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color.lerp(Colors.transparent, context.colors.sage.withOpacity(0.15), val),
                        border: Border.all(
                          color: Color.lerp(context.colors.textSecondary.withOpacity(0.3), context.colors.sage, val)!,
                          width: 2,
                        ),
                      ),
                      child: Transform.scale(
                        scale: val,
                        child: Icon(Icons.check_rounded, color: context.colors.sage, size: 20),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Flow Menu Bottom Sheet ───────────────────────────────────────────────────

class _FlowMenuSheet extends StatelessWidget {
  final int pendingRequestsCount;
  final VoidCallback? onRefresh;
  const _FlowMenuSheet({super.key, this.pendingRequestsCount = 0, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(
              'Menu',
              style: GoogleFonts.playfairDisplay(color: context.colors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            _MenuTile(
              icon: Icons.person_outline_rounded,
              title: 'Profile',
              subtitle: 'Account settings and preferences',
              color: context.colors.sage,
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profile');
              },
            ),
            SizedBox(height: 12),
            _MenuTile(
              icon: Icons.bar_chart_rounded,
              title: 'Statistics',
              subtitle: 'Detailed insights on your progress',
              color: context.colors.lavender,
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/stats');
              },
            ),
            SizedBox(height: 12),
            _MenuTile(
              icon: Icons.people_outline_rounded,
              title: 'Friends',
              subtitle: 'Stay connected and motivated together',
              color: context.colors.terracotta,
              badgeCount: pendingRequestsCount,
              onTap: () async {
                final nav = Navigator.of(context);
                nav.pop();
                await nav.pushNamed('/friends');
                onRefresh?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: TextStyle(color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                      if (badgeCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.colors.terracotta,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$badgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.colors.textSecondary),
          ],
        ),
      ),
    );
  }
}
