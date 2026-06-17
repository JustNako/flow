import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../api/habit_api_service.dart';
import '../../models/habit.dart';
import '../../services/local_database.dart';
import '../../services/sync_service.dart';
import '../../theme/app_theme.dart';

class HabitDetailsScreen extends StatefulWidget {
  const HabitDetailsScreen({super.key});

  @override
  State<HabitDetailsScreen> createState() => _HabitDetailsScreenState();
}

class _HabitDetailsScreenState extends State<HabitDetailsScreen> {
  final _api = HabitApiService.instance;

  late Habit _habit;
  bool _initialized = false;
  bool _isToggling = false;
  bool _isDeleting = false;

  // API data
  int _streak = 0;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _heatmap = [];
  bool _loadingStats = true;

  int _selectedTab = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _habit = ModalRoute.of(context)!.settings.arguments as Habit;
      _loadAllData();
      _initialized = true;
    }
  }

  Future<void> _loadAllData() async {
    if (_habit.id == null) return;
    setState(() => _loadingStats = true);
    try {
      final results = await Future.wait([
        _api.getStreak(_habit.id!),
        _api.getStats(_habit.id!),
        _api.getHeatmap(_habit.id!),
      ]);
      if (mounted) {
        setState(() {
          _streak = results[0] as int;
          _stats = results[1] as Map<String, dynamic>;
          _heatmap = results[2] as List<Map<String, dynamic>>;
          _loadingStats = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _toggleHabit() async {
    if (_habit.id == null || _isToggling) return;

    final wasCompleted = _habit.isCompletedToday;
    int newCompletedDays = wasCompleted ? _habit.completedDays - 1 : _habit.completedDays + 1;
    if (newCompletedDays < 0) newCompletedDays = 0;

    final originalHabit = _habit;

    setState(() {
      _isToggling = true;
      _habit = _habit.copyWith(
        isCompletedToday: !wasCompleted,
        completedDays: newCompletedDays,
        currentStreak: wasCompleted ? 0 : _habit.currentStreak + 1,
      );
    });

    try {
      await _api.toggleHabit(_habit.id!);
      await _loadAllData();
    } catch (e) {
      if (mounted) {
        setState(() => _habit = originalHabit);
        _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  Future<void> _toggleVisibility() async {
    if (_habit.id == null) return;

    final wasPublic = _habit.isPublic;

    setState(() {
      _habit = _habit.copyWith(isPublic: !wasPublic);
    });

    try {
      await _api.toggleVisibility(_habit.id!);

      // Update local db
      final localHabit = await LocalDatabase.instance.getHabit(_habit.id!);
      if (localHabit != null) {
        await LocalDatabase.instance.saveHabit(localHabit.copyWith(
          isPublic: !wasPublic,
          isSynced: false,
          updatedAt: DateTime.now()
        ));
        SyncService.instance.sync(); // Trigger background sync
      }
      _showSnack(_habit.isPublic ? 'Habit is now visible to friends' : 'Habit is now private');
    } catch (e) {
      if (mounted) {
        setState(() => _habit = _habit.copyWith(isPublic: wasPublic));
        _showSnack('Failed to update visibility', isError: true);
      }
    }
  }

  Future<void> _deleteHabit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Habit?', style: GoogleFonts.playfairDisplay(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(
          'This will permanently delete the habit and all its history.',
          style: GoogleFonts.inter(color: context.colors.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.inter(color: context.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: GoogleFonts.inter(color: context.colors.terracotta, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await _api.deleteHabit(_habit.id!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _updateNotes(String newNotes) async {
    if (_habit.id == null) return;

    final oldNotes = _habit.notes;
    setState(() {
      _habit = _habit.copyWith(notes: newNotes);
    });

    try {
      await _api.updateNotes(_habit.id!, newNotes);
      _showSnack('Notes updated');
    } catch (e) {
      if (mounted) {
        setState(() => _habit = _habit.copyWith(notes: oldNotes));
        _showSnack('Failed to update notes', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter(color: isError ? Colors.white : Colors.black)),
      backgroundColor: isError ? context.colors.terracotta : context.colors.sage,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String get _repeatLabel {
    switch (_habit.repeatType) {
      case HabitRepeatType.everyDay: return 'Daily';
      case HabitRepeatType.specificDaysOfWeek:
        const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        final sel = _habit.repeatDaysOfWeek?.map((d) => days[d % 7]).join(', ') ?? '';
        return sel.isEmpty ? 'Weekly' : sel;
      case HabitRepeatType.specificDaysOfMonth:
        final dStr = _habit.repeatDaysOfMonth?.join(', ') ?? '';
        return dStr.isEmpty ? 'Monthly' : 'Each month: $dStr';
      case HabitRepeatType.xTimesPerPeriod:
        final t = _habit.repeatTimesPerPeriod ?? '?';
        final p = _habit.repeatPeriod == HabitRepeatPeriod.week ? 'week' : 'month';
        return '${t}x per $p';
    }
  }

  bool _isDateCompleted(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    for (final entry in _heatmap) {
      final entryDateStr = entry['date'] as String?;
      if (entryDateStr != null) {
        try {
          final parsed = DateTime.parse(entryDateStr);
          final parsedOnly = DateTime(parsed.year, parsed.month, parsed.day);
          if (dateOnly.isAtSameMomentAs(parsedOnly)) {
            return (entry['value'] as int?) == 1;
          }
        } catch (_) {}
      }
    }
    return false;
  }

  void _showEditNotesDialog() {
    final controller = TextEditingController(text: _habit.notes);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Personal Notes', style: GoogleFonts.playfairDisplay(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 5,
          style: GoogleFonts.inter(color: context.colors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter your notes here...',
            hintStyle: GoogleFonts.inter(color: context.colors.textSecondary.withValues(alpha: 0.5)),
            filled: true,
            fillColor: context.colors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: context.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateNotes(controller.text.trim());
            },
            child: Text('Save', style: GoogleFonts.inter(color: context.colors.sage, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Icon(
                  _habit.isPublic ? Icons.lock_outline : Icons.people_outline,
                  color: context.colors.textPrimary,
                ),
                title: Text(
                  _habit.isPublic ? 'Make Private' : 'Make Visible to Friends',
                  style: GoogleFonts.inter(color: context.colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _toggleVisibility();
                },
              ),
              Divider(color: context.colors.border),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: context.colors.terracotta,
                ),
                title: Text(
                  'Delete Habit',
                  style: GoogleFonts.inter(color: context.colors.terracotta, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteHabit();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isDeleting) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: Center(child: CircularProgressIndicator(color: context.colors.sage)),
      );
    }

    final targetUnit = _habit.targetDays > 0 ? '${_habit.targetDays} ${_habit.unit ?? ''}'.trim() : '';
    final repeatLabel = _repeatLabel;
    final timeLabel = _habit.timeOfDay ?? 'Anytime';

    // Subtitle string
    final subtitleElements = [
      if (targetUnit.isNotEmpty) targetUnit,
      repeatLabel,
      timeLabel
    ];
    final subtitle = subtitleElements.join(' · ');

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.colors.card,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.chevron_left_rounded, color: context.colors.textPrimary, size: 24),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: context.colors.sage.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.water_drop_rounded, color: context.colors.sage, size: 16),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _habit.title,
                                style: GoogleFonts.playfairDisplay(
                                  color: context.colors.textPrimary,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: GoogleFonts.inter(
                            color: context.colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    onTap: _showMoreMenu,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: context.colors.card,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.more_horiz_rounded, color: context.colors.textPrimary, size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // Segmented Control
            _buildSegmentedControl(),

            // Screen Content
            Expanded(
              child: _loadingStats
                  ? Center(child: CircularProgressIndicator(color: context.colors.sage))
                  : _selectedTab == 0
                      ? _buildOverviewTab()
                      : _buildHistoryTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedControl() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? context.colors.border : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Overview',
                  style: GoogleFonts.inter(
                    color: _selectedTab == 0 ? context.colors.textPrimary : context.colors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? context.colors.border : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  'History',
                  style: GoogleFonts.inter(
                    color: _selectedTab == 1 ? context.colors.textPrimary : context.colors.textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final completionRate = (_stats?['completionRate'] as num?)?.toDouble() ?? 0.0;
    final currentStreak = (_stats?['currentStreak'] as num?)?.toInt() ?? _streak;
    final longestStreak = (_stats?['longestStreak'] as num?)?.toInt() ?? _streak;
    final completedDaysCount = (_stats?['completedDays'] as num?)?.toInt() ?? _habit.completedDays;

    final today = DateTime.now();
    // Sunday starts week in index 0
    final daysSinceSunday = today.weekday % 7;
    final currentSunday = today.subtract(Duration(days: daysSinceSunday));
    final startSunday = currentSunday.subtract(const Duration(days: 28));
    final gridDates = List.generate(35, (index) => startSunday.add(Duration(days: index)));

    // Calculate dynamic monthly rate based on heatmap
    int monthlyRate = 0;
    if (_heatmap.isNotEmpty) {
      final completedInHeatmap = _heatmap.where((e) => (e['value'] as int?) == 1).length;
      monthlyRate = ((completedInHeatmap / _heatmap.length) * 100).toInt();
    } else {
      monthlyRate = completionRate.toInt();
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        children: [
          // Bento Row 1
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circular Progress Card
              Expanded(
                flex: 11,
                child: Container(
                  height: 180,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: context.colors.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: CustomPaint(
                            painter: _GradientCircularProgressPainter(
                              progress: completionRate / 100,
                              trackColor: context.colors.border,
                              gradientColors: [context.colors.sage, context.colors.lavender],
                              strokeWidth: 10,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${completionRate.toInt()}%',
                              style: GoogleFonts.playfairDisplay(
                                color: context.colors.textPrimary,
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'this week',
                              style: GoogleFonts.inter(
                                color: context.colors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Streaks Column
              Expanded(
                flex: 9,
                child: Column(
                  children: [
                    _buildBentoSmallCard(
                      icon: Icons.whatshot_rounded,
                      iconColor: context.colors.terracotta,
                      value: '$currentStreak days',
                      label: 'Current streak',
                    ),
                    const SizedBox(height: 12),
                    _buildBentoSmallCard(
                      icon: Icons.workspace_premium_rounded,
                      iconColor: context.colors.lavender,
                      value: '$longestStreak days',
                      label: 'Best streak',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bento Row 2 (Monthly Rate & Total Done)
          Row(
            children: [
              Expanded(
                child: _buildBentoStatsRowCard(
                  icon: Icons.trending_up_rounded,
                  iconColor: context.colors.sage,
                  value: '$monthlyRate%',
                  label: 'This month',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildBentoStatsRowCard(
                  icon: Icons.track_changes_rounded,
                  iconColor: context.colors.lavender,
                  value: '$completedDaysCount times',
                  label: 'Total done',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bento Row 3: Activity Grid (GitHub style)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ACTIVITY',
                      style: GoogleFonts.inter(
                        color: context.colors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Less',
                          style: GoogleFonts.inter(color: context.colors.textSecondary, fontSize: 10),
                        ),
                        const SizedBox(width: 4),
                        _buildLegendSquare(context.colors.border),
                        const SizedBox(width: 3),
                        _buildLegendSquare(context.colors.sage.withValues(alpha: 0.3)),
                        const SizedBox(width: 3),
                        _buildLegendSquare(context.colors.sage.withValues(alpha: 0.6)),
                        const SizedBox(width: 3),
                        _buildLegendSquare(context.colors.sage),
                        const SizedBox(width: 4),
                        Text(
                          'More',
                          style: GoogleFonts.inter(color: context.colors.textSecondary, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Labels column
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWeekDayLabel(''),  // Sun
                        _buildWeekDayLabel('M'), // Mon
                        _buildWeekDayLabel(''),  // Tue
                        _buildWeekDayLabel('W'), // Wed
                        _buildWeekDayLabel(''),  // Thu
                        _buildWeekDayLabel('F'), // Fri
                        _buildWeekDayLabel(''),  // Sat
                      ],
                    ),
                    const SizedBox(width: 8),
                    // 5 Columns
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(5, (colIndex) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(7, (rowIndex) {
                              final dateIndex = colIndex * 7 + rowIndex;
                              final date = gridDates[dateIndex];
                              final isCompleted = _isDateCompleted(date);
                              final isFuture = date.isAfter(today);

                              Color cellColor;
                              if (isFuture) {
                                cellColor = Colors.transparent;
                              } else if (isCompleted) {
                                cellColor = context.colors.sage;
                              } else {
                                cellColor = context.colors.border;
                              }

                              return Tooltip(
                                message: DateFormat('EEEE, MMM d, yyyy').format(date),
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  margin: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: cellColor,
                                    borderRadius: BorderRadius.circular(6),
                                    border: isFuture ? null : Border.all(color: context.colors.border.withValues(alpha: 0.3)),
                                  ),
                                ),
                              );
                            }),
                          );
                        }),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bento Row 4: Personal Notes
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PERSONAL NOTE',
                      style: GoogleFonts.inter(
                        color: context.colors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    GestureDetector(
                      onTap: _showEditNotesDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.colors.border,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Tap to edit',
                          style: GoogleFonts.inter(
                            color: context.colors.lavender,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  _habit.notes?.isNotEmpty == true
                      ? _habit.notes!
                      : 'Morning sessions hit different. Try to keep it before 8am for maximum focus.',
                  style: GoogleFonts.inter(
                    color: context.colors.textPrimary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Bento Row 5: Huge Mark as Done Button
          GestureDetector(
            onTap: _toggleHabit,
            child: Container(
              height: 56,
              width: double.infinity,
              decoration: BoxDecoration(
                color: _habit.isCompletedToday ? context.colors.card : context.colors.sage,
                borderRadius: BorderRadius.circular(28),
                border: _habit.isCompletedToday ? Border.all(color: context.colors.border) : null,
              ),
              alignment: Alignment.center,
              child: _isToggling
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          color: _habit.isCompletedToday ? context.colors.sage : Colors.black,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _habit.isCompletedToday ? 'Completed Today' : 'Mark as Done',
                          style: GoogleFonts.inter(
                            color: _habit.isCompletedToday ? context.colors.textPrimary : Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoSmallCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      height: 84,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.playfairDisplay(
                    color: context.colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: context.colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoStatsRowCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.playfairDisplay(
                    color: context.colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: context.colors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendSquare(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2.5),
      ),
    );
  }

  Widget _buildWeekDayLabel(String label) {
    return SizedBox(
      height: 30, // matches square height (22) + vertical padding (8)
      child: Center(
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: context.colors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    final currentStreak = (_stats?['currentStreak'] as num?)?.toInt() ?? _streak;
    final longestStreak = (_stats?['longestStreak'] as num?)?.toInt() ?? _streak;

    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(now);
    final daysInMonthSoFar = now.day;

    int completedInMonth = 0;
    for (final entry in _heatmap) {
      final dateStr = entry['date'] as String?;
      if (dateStr != null) {
        try {
          final date = DateTime.parse(dateStr);
          if (date.year == now.year && date.month == now.month && (entry['value'] as int?) == 1) {
            completedInMonth++;
          }
        } catch (_) {}
      }
    }
    // Fallback if heatmap doesn't have current month logs
    if (completedInMonth == 0 && _heatmap.isEmpty) {
      completedInMonth = _habit.completedDays;
    }

    final successRateInMonth = daysInMonthSoFar == 0
        ? 0
        : ((completedInMonth / daysInMonthSoFar) * 100).toInt();

    // Show entries in reverse chronological order (newest first)
    final entries = _heatmap.reversed.toList();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        children: [
          // June 2026 Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthName,
                style: GoogleFonts.playfairDisplay(
                  color: context.colors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.colors.sage.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$completedInMonth / $daysInMonthSoFar days',
                      style: GoogleFonts.inter(
                        color: context.colors.sage,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.colors.border,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$successRateInMonth%',
                      style: GoogleFonts.inter(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Streak Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF261D15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF3D2714)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colors.terracotta.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.whatshot_rounded, color: context.colors.terracotta, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$currentStreak-day streak',
                        style: GoogleFonts.inter(
                          color: context.colors.terracotta,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Keep it up — best is $longestStreak days',
                        style: GoogleFonts.inter(
                          color: context.colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Log List Bento Box
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.colors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LOG',
                  style: GoogleFonts.inter(
                    color: context.colors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 16),
                if (entries.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(Icons.history_rounded, color: context.colors.textSecondary.withValues(alpha: 0.3), size: 40),
                          const SizedBox(height: 12),
                          Text(
                            'No logs yet. Mark the habit completed to start tracking!',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(color: context.colors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: entries.length > 15 ? 15 : entries.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final entry = entries[i];
                      final isCompleted = (entry['value'] as int?) == 1;
                      final dateStr = entry['date'] as String? ?? '';
                      DateTime? date;
                      try { date = DateTime.parse(dateStr); } catch (_) {}

                      final isToday = date != null &&
                          date.year == DateTime.now().year &&
                          date.month == DateTime.now().month &&
                          date.day == DateTime.now().day;

                      final dayLabel = isToday
                          ? 'Today'
                          : (date != null ? DateFormat('E').format(date) : '');
                      final dateLabel = date != null ? DateFormat('MMM d').format(date) : dateStr;

                      return _buildHistoryLogItem(
                        day: dayLabel,
                        date: dateLabel,
                        status: isCompleted ? 'Completed' : 'Missed',
                        isCompleted: isCompleted,
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryLogItem({
    required String day,
    required String date,
    required String status,
    required bool isCompleted,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                day,
                style: GoogleFonts.inter(
                  color: isCompleted ? context.colors.sage : context.colors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                date,
                style: GoogleFonts.inter(
                  color: context.colors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isCompleted ? context.colors.sage : context.colors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  status,
                  style: GoogleFonts.inter(
                    color: isCompleted ? context.colors.textPrimary : context.colors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isCompleted)
            Icon(
              Icons.check_rounded,
              color: context.colors.sage,
              size: 18,
            ),
        ],
      ),
    );
  }
}

class _GradientCircularProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final List<Color> gradientColors;
  final double strokeWidth;

  const _GradientCircularProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.gradientColors,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress
    if (progress > 0) {
      final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
      final gradient = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi,
        colors: gradientColors,
      );

      final progressPaint = Paint()
        ..shader = gradient.createShader(rect)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GradientCircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
