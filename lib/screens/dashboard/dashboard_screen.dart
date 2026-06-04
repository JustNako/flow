import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../api/habit_api_service.dart';
import '../../models/habit.dart';
import '../../services/auth_service.dart';
import '../../services/offline_manager.dart';
import '../../services/update_service.dart';
import '../../services/widget_service.dart';

const _kBg = Color(0xFF1A1A1A);
const _kCard = Color(0xFF242424);
const _kCardBorder = Color(0xFF2E2E2E);
const _kSage = Color(0xFF8BA888);
const _kTerra = Color(0xFFD68C7A);
const _kLavender = Color(0xFF9F92C6);
const _kGold = Color(0xFFFFD700);
const _kText = Color(0xFFE8E8E8);
const _kTextSub = Color(0xFF888888);

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
  String? _error;
  String? _username;

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

  Future<void> loadData({bool showLoading = true}) async {
    if (showLoading) setState(() { _isLoading = true; _error = null; });
    if (!showLoading && mounted) {
      UpdateService.checkForUpdates(context);
    }
    
    try {
      final results = await Future.wait([
        _api.getHabits(),
        _authService.getUsername(),
      ]);
      
      final habits = results[0] as List<Habit>;
      final username = results[1] as String?;
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
      });
      
      int total = _todayHabits.length;
      int completed = _todayHabits.where((h) => h.isCompletedToday).length;
      double progress = total == 0 ? 0 : completed / total;
      _updateProgressAnimation(progress);

      WidgetService.updateWidget();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleHabit(Habit habit) async {
    final id = habit.id;
    if (id == null) return;

    HapticFeedback.mediumImpact();
    setState(() => _togglingIds.add(id));
    try {
      await _api.toggleHabit(id);
      
      // Update local state immediately & sort instantly so the user sees the card transition seamlessly
      setState(() {
        final index = _todayHabits.indexWhere((h) => h.id == id);
        if (index != -1) {
          final h = _todayHabits[index];
          final wasCompleted = h.isCompletedToday;
          _todayHabits[index] = h.copyWith(
            isCompletedToday: !wasCompleted,
            completedDays: wasCompleted ? h.completedDays - 1 : h.completedDays + 1,
          );
        }

        final otherIndex = _otherHabits.indexWhere((h) => h.id == id);
        if (otherIndex != -1) {
          final h = _otherHabits[otherIndex];
          final wasCompleted = h.isCompletedToday;
          _otherHabits[otherIndex] = h.copyWith(
            isCompletedToday: !wasCompleted,
            completedDays: wasCompleted ? h.completedDays - 1 : h.completedDays + 1,
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
          SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: _kTerra, behavior: SnackBarBehavior.floating),
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
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete habit?', style: TextStyle(color: _kText)),
        content: Text('"${habit.title}" will be permanently deleted.', style: const TextStyle(color: _kTextSub)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: _kTextSub))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: _kTerra))),
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
          SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: _kTerra, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Future<void> _navigateToAddHabit() async {
    final result = await Navigator.of(context).pushNamed('/templates');
    if (result == true) {
      // Silently load new habits in the background without any blocking full-screen loaders
      loadData(showLoading: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int total = _todayHabits.length;
    int completed = _todayHabits.where((h) => h.isCompletedToday).length;
    bool isAllDone = total > 0 && completed == total;

    String greeting = 'Good morning ';
    if (total > 0) {
      if (isAllDone) greeting = 'Beautiful work ';
      else if (completed > 0) greeting = "You're flowing ";
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildConnectionBanner(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: loadData,
                color: _kSage,
                backgroundColor: _kCard,
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
                                        style: const TextStyle(color: _kTextSub, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.2),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          showModalBottomSheet(
                                            context: context,
                                            backgroundColor: Colors.transparent,
                                            builder: (ctx) => const _FlowMenuSheet(),
                                          );
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(color: _kCard, shape: BoxShape.circle, border: Border.all(color: _kCardBorder)),
                                          child: const Icon(Icons.apps_rounded, color: _kTextSub, size: 20),
                                        ),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 500),
                                    child: Text(
                                      greeting,
                                      key: ValueKey(greeting),
                                      style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 32, fontWeight: FontWeight.w700, height: 1.1),
                                    ),
                                  ),
                                  Text(
                                    '${_username ?? 'there'}.',
                                    style: GoogleFonts.playfairDisplay(
                                      color: isAllDone ? _kSage.withOpacity(0.5) : _kTextSub,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Icon(Icons.info_outline_rounded, color: _kSage.withOpacity(0.6), size: 12),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Swipe left on a habit to view details',
                                        style: GoogleFonts.inter(
                                          color: _kTextSub.withOpacity(0.6),
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Thin animated ring
                            AnimatedBuilder(
                              animation: _progressAnimation,
                              builder: (context, child) {
                                final val = _progressAnimation.value;
                                Color ringColor = Color.lerp(_kLavender, _kSage, val)!;
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
                                        child: CircularProgressIndicator(value: 1.0, strokeWidth: 1.5, color: _kCardBorder),
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
                                              child: const Text('✨', style: TextStyle(fontSize: 24)),
                                            );
                                          },
                                        )
                                      else
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('$completed', style: const TextStyle(color: _kText, fontSize: 18, fontWeight: FontWeight.bold, height: 1.0)),
                                            const Text('of', style: TextStyle(color: _kTextSub, fontSize: 10, height: 1.0)),
                                            Text('$total', style: const TextStyle(color: _kTextSub, fontSize: 10, height: 1.0)),
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
                              style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 22, fontWeight: FontWeight.w600),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isAllDone ? _kGold.withOpacity(0.15) : _kCardBorder.withOpacity(0.5),
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
                                      color: isAllDone ? _kGold : _kTextSub,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$completed of $total',
                                    style: TextStyle(color: isAllDone ? _kGold : _kTextSub, fontSize: 11, fontWeight: isAllDone ? FontWeight.bold : FontWeight.normal),
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
                      const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: _kSage)))
                    else if (_error != null)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: _kTerra, size: 48),
                              const SizedBox(height: 16),
                              Text(_error!, style: const TextStyle(color: _kTextSub)),
                              TextButton.icon(onPressed: loadData, icon: const Icon(Icons.refresh, color: _kSage), label: const Text('Retry', style: TextStyle(color: _kSage))),
                            ],
                          ),
                        ),
                      )
                    else if (_todayHabits.isEmpty && _otherHabits.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.spa_outlined, color: _kTextSub, size: 64),
                              SizedBox(height: 16),
                              Text('No habits today', style: TextStyle(color: _kText, fontSize: 18)),
                              SizedBox(height: 8),
                              Text('Enjoy your day or add a new habit', style: TextStyle(color: _kTextSub)),
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
                              color: _kCard.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: _kCardBorder),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.spa_outlined, color: _kTextSub, size: 36),
                                const SizedBox(height: 8),
                                Text(
                                  'No habits scheduled for today',
                                  style: GoogleFonts.inter(color: _kTextSub, fontSize: 14, fontWeight: FontWeight.w500),
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
                              style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 22, fontWeight: FontWeight.w600),
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
        if (status == null || status == ConnectionStatus.connected) return const SizedBox.shrink();
        final (color, icon, text) = switch (status) {
          ConnectionStatus.disconnected => (_kTerra, Icons.wifi_off, 'Offline mode — changes will sync when connected'),
          ConnectionStatus.syncing => (_kLavender, Icons.sync, 'Syncing...'),
          _ => (_kSage, Icons.wifi, 'Online'),
        };
        return Container(
          color: color.withOpacity(0.15),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
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
                gradient: const LinearGradient(
                  colors: [_kSage, _kLavender],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: _kLavender.withOpacity(0.4), blurRadius: 30, spreadRadius: 4 + (_anim.value * 6), offset: const Offset(0, 10)),
                  BoxShadow(color: _kSage.withOpacity(0.3), blurRadius: 20, spreadRadius: 2 + (_anim.value * 4), offset: const Offset(0, 5)),
                ],
              ),
              child: Transform.rotate(
                angle: rotate,
                child: const Icon(Icons.add_rounded, color: _kBg, size: 32),
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

  IconData _getDynamicIcon(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('water') || lower.contains('drink')) return Icons.water_drop_rounded;
    if (lower.contains('read') || lower.contains('book')) return Icons.menu_book_rounded;
    if (lower.contains('meditat') || lower.contains('breath')) return Icons.self_improvement_rounded;
    if (lower.contains('journal') || lower.contains('write')) return Icons.book_rounded;
    if (lower.contains('walk') || lower.contains('step')) return Icons.directions_walk_rounded;
    if (lower.contains('run') || lower.contains('jog')) return Icons.directions_run_rounded;
    if (lower.contains('sleep') || lower.contains('bed')) return Icons.nights_stay_rounded;
    if (lower.contains('workout') || lower.contains('gym')) return Icons.fitness_center_rounded;
    if (lower.contains('code') || lower.contains('program')) return Icons.code_rounded;
    return Icons.spa_rounded;
  }

  Color _getDynamicColor(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('water') || lower.contains('read')) return const Color(0xFF64B5F6);
    if (lower.contains('meditat') || lower.contains('walk')) return _kSage;
    if (lower.contains('journal') || lower.contains('sleep')) return _kLavender;
    if (lower.contains('workout') || lower.contains('run')) return _kTerra;
    return const Color(0xFFFFB74D);
  }

  @override
  Widget build(BuildContext context) {
    final isDone = habit.isCompletedToday;
    final iconData = _getDynamicIcon(habit.title);
    final iconColor = _getDynamicColor(habit.title);

    return Dismissible(
      key: Key(habit.id ?? habit.title),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _kLavender.withOpacity(0.15),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _kLavender.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded, color: _kLavender),
            const SizedBox(height: 4),
            Text('Details', style: TextStyle(color: _kLavender, fontSize: 11, fontWeight: FontWeight.w600)),
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
            color: isDone ? _kCard.withOpacity(0.5) : _kCard,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDone ? _kSage.withOpacity(0.5) : _kCardBorder,
              width: 1.5,
            ),
            boxShadow: isDone ? [
              BoxShadow(
                color: _kSage.withOpacity(0.1),
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
                      isDone ? _kSage.withOpacity(0.2) : const Color(0xFF333333),
                      isDone ? _kSage.withOpacity(0.05) : const Color(0xFF222222),
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
                    color: isDone ? _kSage : iconColor.withOpacity(0.8),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Text and Streaks
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        color: isDone ? _kTextSub.withOpacity(0.6) : _kText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: _kSage.withOpacity(0.5),
                        decorationThickness: 2,
                        fontFamily: GoogleFonts.inter().fontFamily,
                      ),
                      child: Text(habit.title),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: Row(
                            children: [
                              Flexible(
                                child: habit.unit != null && habit.unit!.isNotEmpty && habit.unit!.toLowerCase() != 'null'
                                  ? Text('${habit.targetDays} ${habit.unit}', overflow: TextOverflow.ellipsis, style: TextStyle(color: isDone ? _kTextSub.withOpacity(0.3) : _kTextSub, fontSize: 13))
                                  : Text('${habit.targetDays} time${habit.targetDays > 1 ? 's' : ''}', overflow: TextOverflow.ellipsis, style: TextStyle(color: isDone ? _kTextSub.withOpacity(0.3) : _kTextSub, fontSize: 13)),
                              ),
                              
                              if (habit.timeOfDay != null && habit.timeOfDay!.isNotEmpty && habit.timeOfDay!.toLowerCase() != 'null') ...[
                                const SizedBox(width: 8),
                                Text('|', style: TextStyle(color: isDone ? _kTextSub.withOpacity(0.1) : _kCardBorder, fontSize: 13)),
                                const SizedBox(width: 8),
                                Icon(Icons.access_time_rounded, size: 13, color: isDone ? _kTextSub.withOpacity(0.3) : _kSage),
                                const SizedBox(width: 4),
                                Flexible(child: Text(habit.timeOfDay!, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDone ? _kTextSub.withOpacity(0.3) : _kSage, fontSize: 13, fontWeight: FontWeight.w600))),
                              ],

                              if (habit.completedDays > 0) ...[
                                const SizedBox(width: 8),
                                Text('|', style: TextStyle(color: isDone ? _kTextSub.withOpacity(0.1) : _kCardBorder, fontSize: 13)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _kTerra.withOpacity(isDone ? 0.05 : 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('🔥', style: TextStyle(fontSize: 10, color: isDone ? _kTextSub : Colors.white)),
                                      const SizedBox(width: 4),
                                      Text('${habit.completedDays}', style: TextStyle(color: isDone ? _kTextSub.withOpacity(0.5) : _kTerra, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                )
                              ]
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Visual Swipe Hint & Checkmark
              Icon(Icons.chevron_left_rounded, color: _kTextSub.withOpacity(0.2), size: 16),
              const SizedBox(width: 4),
              // Animated spring checkmark
              if (isToggling)
                const SizedBox(width: 32, height: 32, child: Padding(padding: EdgeInsets.all(6), child: CircularProgressIndicator(strokeWidth: 2, color: _kSage)))
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
                        color: Color.lerp(Colors.transparent, _kSage.withOpacity(0.15), val),
                        border: Border.all(
                          color: Color.lerp(_kTextSub.withOpacity(0.3), _kSage, val)!,
                          width: 2,
                        ),
                      ),
                      child: Transform.scale(
                        scale: val,
                        child: const Icon(Icons.check_rounded, color: _kSage, size: 20),
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
  const _FlowMenuSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: const BoxDecoration(
        color: _kBg,
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
                decoration: BoxDecoration(color: _kCardBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text(
              'Menu',
              style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _MenuTile(
              icon: Icons.person_outline_rounded,
              title: 'Profile',
              subtitle: 'Account settings and preferences',
              color: _kSage,
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profile');
              },
            ),
            const SizedBox(height: 12),
            _MenuTile(
              icon: Icons.bar_chart_rounded,
              title: 'Statistics',
              subtitle: 'Detailed insights on your progress',
              color: _kLavender,
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/stats');
              },
            ),
            const SizedBox(height: 12),
            _MenuTile(
              icon: Icons.people_outline_rounded,
              title: 'Friends',
              subtitle: 'Stay connected and motivated together',
              color: _kTerra,
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/friends');
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

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kCardBorder),
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
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: _kText, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: _kTextSub, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _kTextSub),
          ],
        ),
      ),
    );
  }
}
