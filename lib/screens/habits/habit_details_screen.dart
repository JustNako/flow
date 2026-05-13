import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/habit_api_service.dart';
import '../../models/habit.dart';
import '../../services/local_database.dart';
import '../../services/sync_service.dart';

class HabitDetailsScreen extends StatefulWidget {
  const HabitDetailsScreen({super.key});

  @override
  State<HabitDetailsScreen> createState() => _HabitDetailsScreenState();
}

class _HabitDetailsScreenState extends State<HabitDetailsScreen>
    with SingleTickerProviderStateMixin {
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

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _habit = ModalRoute.of(context)!.settings.arguments as Habit;
      _loadAllData();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        backgroundColor: const Color(0xFF161A22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Habit?', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: const Text(
          'This will permanently delete the habit and all its history.',
          style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8A8F9E))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.w600)),
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
      content: Text(msg),
      backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF1F3A2E),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────
  static const List<List<Color>> _gradients = [
    [Color(0xFF00B4DB), Color(0xFF0083B0)],
    [Color(0xFFFF512F), Color(0xFFDD2476)],
    [Color(0xFFDA22FF), Color(0xFF9733EE)],
    [Color(0xFF4776E6), Color(0xFF8E54E9)],
    [Color(0xFF11998E), Color(0xFF38EF7D)],
    [Color(0xFFFFB75E), Color(0xFFED8F03)],
  ];

  LinearGradient get _gradient {
    final colors = _gradients[_habit.title.length % _gradients.length];
    return LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight);
  }

  IconData get _icon {
    final l = _habit.title.toLowerCase();
    if (l.contains('water')) return Icons.water_drop_outlined;
    if (l.contains('workout') || l.contains('gym')) return Icons.fitness_center;
    if (l.contains('read') || l.contains('book')) return Icons.book_outlined;
    if (l.contains('sleep') || l.contains('rest')) return Icons.nights_stay_outlined;
    if (l.contains('code') || l.contains('program')) return Icons.code;
    if (l.contains('meditat') || l.contains('mind')) return Icons.self_improvement;
    if (l.contains('run') || l.contains('walk')) return Icons.directions_run;
    return Icons.task_alt;
  }

  String get _repeatLabel {
    switch (_habit.repeatType) {
      case HabitRepeatType.everyDay: return 'Every day';
      case HabitRepeatType.specificDaysOfWeek:
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final sel = _habit.repeatDaysOfWeek?.map((d) => days[d % 7]).join(', ') ?? '';
        return sel.isEmpty ? 'Specific days of week' : sel;
      case HabitRepeatType.specificDaysOfMonth:
        final dStr = _habit.repeatDaysOfMonth?.join(', ') ?? '';
        return dStr.isEmpty ? 'Specific days of month' : 'Each month: $dStr';
      case HabitRepeatType.xTimesPerPeriod:
        final t = _habit.repeatTimesPerPeriod ?? '?';
        final p = _habit.repeatPeriod == HabitRepeatPeriod.week ? 'week' : 'month';
        return '${t}x per $p';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1017),
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF512F)))
          : NestedScrollView(
              headerSliverBuilder: (_, __) => [_buildSliverAppBar()],
              body: Column(
                children: [
                  _buildTabBar(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [_buildOverviewTab(), _buildHistoryTab()],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ─── Sliver AppBar ─────────────────────────────────────────────────────────
  Widget _buildSliverAppBar() {
    final isDone = _habit.isCompletedToday;
    return SliverAppBar(
      expandedHeight: 280,
      floating: false,
      pinned: true,
      backgroundColor: const Color(0xFF0C1017),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Color(0xFFFF5252)),
          onPressed: _deleteHabit,
          tooltip: 'Delete',
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _gradient.colors.first.withOpacity(0.2),
                const Color(0xFF0C1017),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Icon
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          gradient: _gradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: _gradient.colors.first.withOpacity(0.4),
                                blurRadius: 16, offset: const Offset(0, 4))
                          ],
                        ),
                        child: Icon(_icon, color: Colors.white, size: 32),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_habit.title,
                              style: const TextStyle(color: Colors.white, fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.repeat, size: 13, color: _gradient.colors.first),
                                const SizedBox(width: 4),
                                Text(_repeatLabel,
                                  style: TextStyle(color: _gradient.colors.first, fontSize: 13)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Quick stats row
                  Row(
                    children: [
                      _quickStat(_loadingStats ? '…' : '$_streak', 'Streak', Icons.local_fire_department,
                          const Color(0xFFFF7A55)),
                      const SizedBox(width: 12),
                      _quickStat('${_habit.completedDays}', 'Completed', Icons.check_circle_outline,
                          const Color(0xFF00E676)),
                      const SizedBox(width: 12),
                      _quickStat(
                        _habit.targetDays > 0 ? '${_habit.targetDays}' : '∞',
                        'Target', Icons.flag_outlined, const Color(0xFF8E54E9)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickStat(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(value,
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold, height: 1)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ─── TabBar ────────────────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF0C1017),
      child: TabBar(
        controller: _tabController,
        indicatorColor: _gradient.colors.first,
        indicatorWeight: 2,
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF8A8F9E),
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'History'),
        ],
      ),
    );
  }

  // ─── Overview Tab ──────────────────────────────────────────────────────────
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildToggleButton(),
          const SizedBox(height: 16),
          _buildVisibilityToggle(),
          const SizedBox(height: 20),
          if (_habit.description?.isNotEmpty == true) ...[
            _buildInfoCard(Icons.notes_outlined, 'About this Habit', _habit.description!),
            const SizedBox(height: 16),
          ],
          _buildInfoCard(
            Icons.edit_note_outlined,
            'Personal Notes',
            _habit.notes?.isEmpty ?? true ? 'Tap to add notes...' : _habit.notes!,
            onTap: () => _showEditNotesDialog(),
          ),
          const SizedBox(height: 16),
          _buildScheduleCard(),
          const SizedBox(height: 16),
          _buildProgressCard(),
          if (_heatmap.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildHeatmapCard(),
          ],
        ],
      ),
    );
  }

  // ─── Mark as Done Button ───────────────────────────────────────────────────
  Widget _buildToggleButton() {
    final isDone = _habit.isCompletedToday;
    return GestureDetector(
      onTap: _toggleHabit,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: isDone
              ? const LinearGradient(colors: [Color(0xFF1F3A2E), Color(0xFF162B20)])
              : LinearGradient(colors: _gradient.colors),
          border: isDone ? Border.all(color: const Color(0xFF00E676).withOpacity(0.3)) : null,
          boxShadow: isDone ? [] : [
            BoxShadow(color: _gradient.colors.first.withOpacity(0.4),
                blurRadius: 20, offset: const Offset(0, 6))
          ],
        ),
        alignment: Alignment.center,
        child: _isToggling
            ? const SizedBox(width: 24, height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: isDone ? const Color(0xFF00E676) : Colors.white, size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isDone ? 'Completed Today ✓' : 'Mark as Done',
                    style: TextStyle(
                      color: isDone ? const Color(0xFF00E676) : Colors.white,
                      fontSize: 16, fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ─── Visibility Toggle ─────────────────────────────────────────────────────
  Widget _buildVisibilityToggle() {
    return _card(
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _habit.isPublic
                  ? const Color(0xFF00E676).withOpacity(0.15)
                  : const Color(0xFF8A8F9E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _habit.isPublic ? Icons.people_outline : Icons.lock_outline,
              color: _habit.isPublic ? const Color(0xFF00E676) : const Color(0xFF8A8F9E),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _habit.isPublic ? 'Visible to Friends' : 'Private',
                  style: TextStyle(
                    color: _habit.isPublic ? Colors.white : const Color(0xFF8A8F9E),
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _habit.isPublic
                      ? 'Friends can see this habit'
                      : 'Only you can see this habit',
                  style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _habit.isPublic,
            onChanged: (v) => _toggleVisibility(),
            activeColor: const Color(0xFF00E676),
            inactiveThumbColor: const Color(0xFF8A8F9E),
            inactiveTrackColor: const Color(0xFF262A34),
          ),
        ],
      ),
    );
  }

  // ─── Info Card (Description/Notes) ────────────────────────────────────────
  Widget _buildInfoCard(IconData icon, String title, String content, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _cardTitle(icon, title),
                if (onTap != null) ...[
                  const Spacer(),
                  const Icon(Icons.edit_outlined, color: Color(0xFF8A8F9E), size: 16),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: TextStyle(
                color: content.contains('Tap to add') ? const Color(0xFF4A4E5A) : const Color(0xFFD0D5E0),
                fontSize: 14,
                height: 1.6,
                fontStyle: content.contains('Tap to add') ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNotesDialog() {
    final controller = TextEditingController(text: _habit.notes);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161A22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Personal Notes', style: TextStyle(color: Colors.white, fontSize: 18)),
        content: TextField(
          controller: controller,
          maxLines: 5,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter your notes here...',
            hintStyle: const TextStyle(color: Color(0xFF4A4E5A)),
            filled: true,
            fillColor: const Color(0xFF0C1017),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8A8F9E))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _updateNotes(controller.text.trim());
            },
            child: const Text('Save', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── Schedule Card ─────────────────────────────────────────────────────────
  Widget _buildScheduleCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.schedule_outlined, 'Schedule'),
          const SizedBox(height: 16),
          _scheduleRow(Icons.repeat, 'Frequency', _repeatLabel),
          if (_habit.targetDays > 0) ...[
            const SizedBox(height: 10),
            _scheduleRow(Icons.flag_outlined, 'Daily Goal', '${_habit.targetDays} min / day'),
          ],
          if (_habit.repeatType == HabitRepeatType.specificDaysOfWeek &&
              (_habit.repeatDaysOfWeek?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 16),
            _buildDayChips(),
          ],
        ],
      ),
    );
  }

  Widget _scheduleRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF8A8F9E), size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 14)),
        const Spacer(),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14,
            fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildDayChips() {
    const labels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final isActive = _habit.repeatDaysOfWeek?.contains(i) ?? false;
        return Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: isActive ? _gradient.colors.first : const Color(0xFF1E2230),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(labels[i],
              style: TextStyle(
                color: isActive ? Colors.white : const Color(0xFF8A8F9E),
                fontSize: 12, fontWeight: FontWeight.w600,
              )),
          ),
        );
      }),
    );
  }

  // ─── Progress Card ─────────────────────────────────────────────────────────
  Widget _buildProgressCard() {
    final completed = _habit.completedDays;
    final target = _habit.targetDays;
    final progress = target > 0 ? (completed / target).clamp(0.0, 1.0) : 0.0;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.bar_chart_rounded, 'Progress'),
          const SizedBox(height: 20),
          Row(
            children: [
              // Large circular stat
              SizedBox(
                width: 80, height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80, height: 80,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 7,
                        backgroundColor: Colors.white.withOpacity(0.07),
                        valueColor: AlwaysStoppedAnimation(_gradient.colors.first),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Text('${(progress * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: [
                    _progressStatRow('Completed Days', '$completed'),
                    const SizedBox(height: 8),
                    _progressStatRow('Target Days', target > 0 ? '$target' : '—'),
                    const SizedBox(height: 8),
                    _progressStatRow('Current Streak',
                        _loadingStats ? '…' : '$_streak days 🔥'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13,
            fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ─── Heatmap ───────────────────────────────────────────────────────────────
  Widget _buildHeatmapCard() {
    // Show last 35 days
    final recent = _heatmap.length > 35 ? _heatmap.sublist(_heatmap.length - 35) : _heatmap;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.grid_view, 'Activity (Last 5 Weeks)'),
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: recent.map((entry) {
              final isCompleted = (entry['value'] as int?) == 1;
              final dateStr = entry['date'] as String? ?? '';
              DateTime? date;
              try { date = DateTime.parse(dateStr); } catch (_) {}
              return Tooltip(
                message: date != null ? DateFormat('MMM d').format(date) : dateStr,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted ? _gradient.colors.first : const Color(0xFF1E2230),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isCompleted ? [
                      BoxShadow(color: _gradient.colors.first.withOpacity(0.4),
                          blurRadius: 6, offset: const Offset(0, 2))
                    ] : [],
                  ),
                  child: isCompleted
                      ? Icon(Icons.check, color: Colors.white, size: 16) : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(width: 12, height: 12,
                decoration: BoxDecoration(color: const Color(0xFF1E2230),
                    borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 6),
              const Text('Skipped', style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 12)),
              const SizedBox(width: 16),
              Container(width: 12, height: 12,
                decoration: BoxDecoration(
                    gradient: _gradient, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 6),
              const Text('Completed', style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  // ─── History Tab ───────────────────────────────────────────────────────────
  Widget _buildHistoryTab() {
    if (_loadingStats) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF512F)));
    }

    if (_heatmap.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, color: const Color(0xFF8A8F9E).withOpacity(0.4), size: 56),
            const SizedBox(height: 16),
            const Text('No history yet', style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 16)),
            const SizedBox(height: 8),
            const Text('Start completing this habit to see your history!',
              style: TextStyle(color: Color(0xFF4A4E5A), fontSize: 13),
              textAlign: TextAlign.center),
          ],
        ),
      );
    }

    // Show entries in reverse order (newest first)
    final entries = _heatmap.reversed.toList();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E2230), height: 1),
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

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isCompleted ? const Color(0xFF1F3A2E) : const Color(0xFF3A1F26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isCompleted ? Icons.check : Icons.close,
                  color: isCompleted ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isCompleted ? 'Completed' : 'Skipped',
                          style: TextStyle(
                            color: isCompleted ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                            fontSize: 15, fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isToday) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _gradient.colors.first.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Today',
                              style: TextStyle(color: _gradient.colors.first, fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date != null ? DateFormat('EEEE, MMMM d, yyyy').format(date) : dateStr,
                      style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── Shared Widgets ────────────────────────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: child,
    );
  }

  Widget _cardTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: _gradient.colors.first, size: 18),
        const SizedBox(width: 8),
        Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
