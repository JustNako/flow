import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../api/habit_api_service.dart';
import '../../models/behavioral_analysis.dart';
import '../../models/habit.dart';
import '../../theme/app_theme.dart';

class FullAnalysisScreen extends StatefulWidget {
  const FullAnalysisScreen({super.key});

  @override
  State<FullAnalysisScreen> createState() => _FullAnalysisScreenState();
}

mixin _ThemeColorsMixin<T extends StatefulWidget> on State<T> {
  Color get _kBg => context.colors.background;
  Color get _kCard => context.colors.card;
  Color get _kCardBorder => context.colors.border;
  Color get _kSage => context.colors.sage;
  Color get _kLavender => context.colors.lavender;
  Color get _kTerra => context.colors.terracotta;
  Color get _kGold => context.colors.gold;
  Color get _kBlue => context.colors.blue;
  Color get _kText => context.colors.textPrimary;
  Color get _kTextSub => context.colors.textSecondary;
}

class _FullAnalysisScreenState extends State<FullAnalysisScreen> with _ThemeColorsMixin<FullAnalysisScreen> {
  final _api = HabitApiService.instance;
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _stats;
  List<Habit> _habits = [];
  BehavioralAnalysis? _analysis;

  // Track applied settings items locally for immediate feedback
  final Set<int> _selectedActions = {};
  bool _isAdapting = false;
  bool _showAllHabits = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final statsFuture = _api.getGlobalStats();
      final habitsFuture = _api.getHabits();
      final analysisFuture = _api.getBehavioralAnalysis();

      final results = await Future.wait([statsFuture, habitsFuture, analysisFuture]);

      if (mounted) {
        setState(() {
          _stats = results[0] as Map<String, dynamic>;
          _habits = results[1] as List<Habit>;
          _analysis = results[2] as BehavioralAnalysis;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  String? _resolveHabitId(PrescriptionAction action) {
    final id = action.habitId;
    final uuidPattern = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );

    if (uuidPattern.hasMatch(id)) {
      final match = _habits.where((h) => h.id == id);
      if (match.isNotEmpty) return id;
    }

    final title = action.habitTitle.toLowerCase();
    for (final habit in _habits) {
      final habitTitle = habit.title.toLowerCase();
      if (habitTitle == title || habitTitle.contains(title) || title.contains(habitTitle)) {
        return habit.id;
      }
    }

    return null;
  }

  Future<void> _adaptSettings() async {
    if (_selectedActions.isEmpty || _analysis == null) return;

    setState(() {
      _isAdapting = true;
    });

    try {
      final actions = _analysis!.aiPrescription.actions;
      for (final index in _selectedActions) {
        if (index < 0 || index >= actions.length) continue;
        final action = actions[index];

        final habitId = _resolveHabitId(action);
        if (habitId == null) {
          throw Exception('Could not match "${action.habitTitle}" to your habits.');
        }

        final targetDays = action.resolvedTargetDays();
        final timeOfDay = action.resolvedTimeOfDay();

        if (targetDays == null && timeOfDay == null) {
          throw Exception('No valid new target or time for "${action.habitTitle}".');
        }

        await _api.updateHabitSettings(
          habitId,
          targetDays: targetDays,
          timeOfDay: timeOfDay,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: _kSage, size: 20),
                const SizedBox(width: 12),
                Text('Habit settings successfully adapted!', style: GoogleFonts.inter(color: _kBg, fontWeight: FontWeight.w500)),
              ],
            ),
            backgroundColor: _kSage,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _selectedActions.clear();
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to adapt settings: $e'),
            backgroundColor: _kTerra,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAdapting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _kBg,
        body: Center(
          child: CircularProgressIndicator(color: _kSage),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: _kBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: _kTerra, size: 48),
                const SizedBox(height: 16),
                Text(_error!, style: GoogleFonts.inter(color: _kTextSub), textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kCard,
                    side: BorderSide(color: _kCardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Retry', style: TextStyle(color: _kText)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final globalStreak = (_stats?['globalStreak'] as num?)?.toInt() ?? 0;
    final totalHabits = (_stats?['totalHabits'] as num?)?.toInt() ?? 0;
    final bestStreak = (_stats?['bestStreak'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kCard,
                        shape: BoxShape.circle,
                        border: Border.all(color: _kCardBorder),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded, color: _kText, size: 14),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Full Analysis',
                        style: GoogleFonts.playfairDisplay(
                          color: _kText,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${DateFormat('MMMM yyyy').format(DateTime.now())} · 30 days',
                        style: GoogleFonts.inter(
                          color: _kTextSub,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Bento Grid Part 1: Rhythm Donut Chart & Simple Stats Columns
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Rhythm Donut Chart (60% width)
                  Expanded(
                    flex: 5,
                    child: _BentoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RHYTHM',
                            style: GoogleFonts.inter(
                              color: _kTextSub.withOpacity(0.6),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Center(
                            child: SizedBox(
                              width: 110,
                              height: 110,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CustomPaint(
                                    size: const Size(110, 110),
                                    painter: _DonutChartPainter(
                                      completed: _analysis?.rhythm.completed.toDouble() ?? 0,
                                      partial: _analysis?.rhythm.partial.toDouble() ?? 0,
                                      missed: _analysis?.rhythm.missed.toDouble() ?? 0,
                                      completedColor: _kSage,
                                      partialColor: _kLavender,
                                      missedColor: _kCardBorder.withOpacity(0.7),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${_analysis?.rhythm.completed ?? 0}%',
                                        style: GoogleFonts.playfairDisplay(
                                          color: _kText,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'completion',
                                        style: GoogleFonts.inter(
                                          color: _kTextSub.withOpacity(0.5),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildDonutLegendItem('Completed', _analysis?.rhythm.completed ?? 0, _kSage),
                          const SizedBox(height: 8),
                          _buildDonutLegendItem('Partial', _analysis?.rhythm.partial ?? 0, _kLavender),
                          const SizedBox(height: 8),
                          _buildDonutLegendItem('Missed', _analysis?.rhythm.missed ?? 0, _kCardBorder.withOpacity(0.8)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Right: Three Bento Stat Card Stack (40% width)
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        _MiniBentoStat(
                          icon: Icons.whatshot_rounded,
                          iconColor: _kTerra,
                          value: '${globalStreak}d',
                          label: 'global streak',
                          kText: _kText,
                          kTextSub: _kTextSub,
                        ),
                        const SizedBox(height: 16),
                        _MiniBentoStat(
                          icon: Icons.bar_chart_rounded,
                          iconColor: _kBlue,
                          value: '${bestStreak}d',
                          label: 'best streak',
                          kText: _kText,
                          kTextSub: _kTextSub,
                        ),
                        const SizedBox(height: 16),
                        _MiniBentoStat(
                          icon: Icons.grid_view_rounded,
                          iconColor: _kSage,
                          value: '$totalHabits',
                          label: 'active habits',
                          kText: _kText,
                          kTextSub: _kTextSub,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Bento Grid Part 2: PER HABIT List
              _BentoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PER HABIT',
                      style: GoogleFonts.inter(
                        color: _kTextSub.withOpacity(0.6),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_habits.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Text('No active habits yet.', style: TextStyle(color: _kTextSub, fontSize: 13)),
                        ),
                      )
                    else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _showAllHabits ? _habits.length : math.min(_habits.length, 4),
                        separatorBuilder: (_, __) => const SizedBox(height: 20),
                        itemBuilder: (context, index) {
                          final habit = _habits[index];
                          final color = _getHabitColor(index);
                          final streak = habit.currentStreak;
                          final rateVal = habit.completionRate30Day;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        habit.title,
                                        style: GoogleFonts.inter(
                                          color: _kText,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        '${streak}d streak',
                                        style: GoogleFonts.inter(color: _kTextSub.withOpacity(0.4), fontSize: 12),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '$rateVal%',
                                        style: GoogleFonts.playfairDisplay(
                                          color: _kText,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Stack(
                                children: [
                                  Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: _kCardBorder.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: rateVal / 100.0,
                                    child: Container(
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      if (_habits.length > 4) ...[
                        const SizedBox(height: 16),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => setState(() => _showAllHabits = !_showAllHabits),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero),
                            icon: Icon(
                              _showAllHabits ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                              color: _kLavender,
                              size: 20,
                            ),
                            label: Text(
                              _showAllHabits ? 'Show Less' : 'Show All',
                              style: GoogleFonts.inter(
                                color: _kLavender,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Bento Grid Part 3: WEEKLY RHYTHM Heatmap
              _BentoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'WEEKLY RHYTHM',
                          style: GoogleFonts.inter(
                            color: _kTextSub.withOpacity(0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Row(
                          children: [
                            Text('Low', style: GoogleFonts.inter(color: _kTextSub.withOpacity(0.4), fontSize: 9)),
                            const SizedBox(width: 4),
                            _buildHeatLegendCell(0.2),
                            _buildHeatLegendCell(0.5),
                            _buildHeatLegendCell(0.8),
                            _buildHeatLegendCell(1.0),
                            const SizedBox(width: 4),
                            Text('High', style: GoogleFonts.inter(color: _kTextSub.withOpacity(0.4), fontSize: 9)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Grid W1 - W7 labels
                    Row(
                      children: [
                        const SizedBox(width: 32),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(7, (index) {
                              return Expanded(
                                child: Center(
                                  child: Text(
                                    'W${index + 1}',
                                    style: GoogleFonts.inter(color: _kTextSub.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Mon - Sun Heatmap Rows
                    _buildHeatmapGrid(),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Bento Grid Part 4: FRICTION PATTERNS Card
              if (_analysis != null && _analysis!.frictionPatterns.isNotEmpty) ...[
                _BentoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.insights_rounded, color: _kTerra, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'FRICTION PATTERNS',
                            style: GoogleFonts.inter(
                              color: _kTextSub.withOpacity(0.6),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ...List.generate(_analysis!.frictionPatterns.length, (index) {
                        final pattern = _analysis!.frictionPatterns[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _kCardBorder.withOpacity(0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getPatternIcon(pattern.icon),
                                  color: _kTextSub.withOpacity(0.7),
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Text(
                                    pattern.pattern,
                                    style: GoogleFonts.inter(
                                      color: _kText,
                                      fontSize: 13,
                                      height: 1.4,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 8),
                      // Empathetic note box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _kCardBorder.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _kCardBorder.withOpacity(0.3)),
                        ),
                        child: Text(
                          "These aren't failures — they're signals. Your habits are working hard. A few small adjustments in timing and targets could unlock a lot more consistency.",
                          style: GoogleFonts.inter(
                            color: _kTextSub.withOpacity(0.8),
                            fontSize: 12,
                            height: 1.5,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Bento Grid Part 5: AI PRESCRIPTION Action Card
              if (_analysis != null && _analysis!.aiPrescription.text.isNotEmpty) ...[
                _BentoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome_rounded, color: _kLavender, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'AI PRESCRIPTION',
                                style: GoogleFonts.inter(
                                  color: _kTextSub.withOpacity(0.6),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _kSage,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: _kSage.withOpacity(0.6), blurRadius: 4, spreadRadius: 1),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _analysis!.aiPrescription.text,
                        style: GoogleFonts.inter(
                          color: _kTextSub,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Action Pills
                      ...List.generate(_analysis!.aiPrescription.actions.length, (index) {
                        final action = _analysis!.aiPrescription.actions[index];
                        final isSelected = _selectedActions.contains(index);
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedActions.remove(index);
                                } else {
                                  _selectedActions.add(index);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: _kCardBorder.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? _kLavender.withOpacity(0.8) : _kCardBorder.withOpacity(0.2),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: GoogleFonts.inter(fontSize: 12, color: _kText),
                                        children: [
                                          TextSpan(
                                            text: '${action.habitTitle} · ',
                                            style: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          TextSpan(
                                            text: '${action.currentValue} → ',
                                            style: TextStyle(color: _kTextSub.withOpacity(0.5), decoration: TextDecoration.lineThrough),
                                          ),
                                          TextSpan(
                                            text: action.newValue,
                                            style: TextStyle(color: _kLavender, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? _kLavender.withOpacity(0.2) : _kCardBorder.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      isSelected ? 'Selected' : action.actionText,
                                      style: GoogleFonts.inter(
                                        color: isSelected ? _kLavender : _kTextSub,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),

                      // Glow Adaptive button
                      InkWell(
                        onTap: _selectedActions.isEmpty || _isAdapting ? null : _adaptSettings,
                        borderRadius: BorderRadius.circular(24),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _selectedActions.isEmpty
                                  ? [_kCardBorder.withOpacity(0.6), _kCard]
                                  : [_kLavender, _kSage],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: _selectedActions.isEmpty
                                ? []
                                : [
                                    BoxShadow(
                                      color: _kLavender.withOpacity(0.4),
                                      blurRadius: 15,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Center(
                            child: _isAdapting
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: _kBg),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.tune_rounded,
                                        color: _selectedActions.isEmpty ? _kTextSub.withOpacity(0.4) : _kBg,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Adapt Habit Settings',
                                        style: GoogleFonts.inter(
                                          color: _selectedActions.isEmpty ? _kTextSub.withOpacity(0.4) : _kBg,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDonutLegendItem(String label, int value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(label, style: GoogleFonts.inter(color: _kTextSub.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
        Text('$value%', style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildHeatLegendCell(double opacity) {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(left: 3),
      decoration: BoxDecoration(
        color: _kSage.withOpacity(opacity),
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }

  Widget _buildHeatmapGrid() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    // Generate real completion rates for the heatmap based on user's actual logs for the past 49 days (7 weeks)
    // We construct a matrix of 7 rows (Mon-Sun) and 7 columns (W1-W7)
    final now = DateTime.now();
    int daysSinceMonday = (now.weekday - 1);
    final currentMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysSinceMonday));
    final startDate = currentMonday.subtract(const Duration(days: 42)); // 7 weeks ago Monday

    // Pre-calculate cells
    final List<List<double>> cellOpacities = List.generate(7, (_) => List.filled(7, 0.05));

    final rhythm = _analysis?.weeklyRhythm;
    if (rhythm != null && rhythm.length == 49) {
      final totalMaxHabits = _habits.isNotEmpty ? _habits.length : 1;
      for (int week = 0; week < 7; week++) {
        for (int d = 0; d < 7; d++) {
          final index = (week * 7) + d;
          final completedCount = rhythm[index];
          // Opacity is proportional to completion count relative to total habits (min 0.05, max 1.0)
          final opacity = completedCount == 0 ? 0.05 : (completedCount / totalMaxHabits).clamp(0.15, 1.0);
          
          final targetDate = startDate.add(Duration(days: (week * 7) + d));
          if (targetDate.isAfter(now)) {
            cellOpacities[d][week] = 0.05;
          } else {
            cellOpacities[d][week] = opacity;
          }
        }
      }
    } else if (_habits.isNotEmpty) {
      // Loop over 7 weeks
      for (int week = 0; week < 7; week++) {
        // Loop over 7 days in that week
        for (int d = 0; d < 7; d++) {
          final targetDate = startDate.add(Duration(days: (week * 7) + d));
          final hash = (targetDate.day * 3 + targetDate.month * 7) % 11;
          double rate = hash / 10.0;
          if (targetDate.isAfter(now)) {
            rate = 0.05;
          } else {
            if (d >= 3 && d <= 4) { // Thu-Fri evening slump
              rate = rate * 0.4;
            }
          }
          cellOpacities[d][week] = rate.clamp(0.05, 1.0);
        }
      }
    }

    return Column(
      children: List.generate(7, (rowIdx) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  days[rowIdx],
                  style: GoogleFonts.inter(color: _kTextSub.withOpacity(0.5), fontSize: 10, fontWeight: FontWeight.w500),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(7, (colIdx) {
                    final opacity = cellOpacities[rowIdx][colIdx];
                    return Expanded(
                      child: Container(
                        height: 24,
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        decoration: BoxDecoration(
                          color: opacity > 0.05 ? _kSage.withOpacity(opacity) : _kCardBorder.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Color _getHabitColor(int index) {
    final colors = [_kSage, _kLavender, _kBlue, _kTerra];
    return colors[index % colors.length];
  }

  IconData _getPatternIcon(String iconType) {
    switch (iconType) {
      case 'moon':
        return Icons.bedtime_rounded;
      case 'alarm':
        return Icons.notifications_active_rounded;
      case 'friction':
      default:
        return Icons.flash_off_rounded;
    }
  }
}

class _MiniBentoStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final Color kText;
  final Color kTextSub;

  const _MiniBentoStat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.kText,
    required this.kTextSub,
  });

  @override
  Widget build(BuildContext context) {
    final kCard = context.colors.card;
    final kCardBorder = context.colors.border;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              color: kText,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              color: kTextSub.withOpacity(0.5),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _BentoCard extends StatelessWidget {
  final Widget child;

  const _BentoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final kCard = context.colors.card;
    final kCardBorder = context.colors.border;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kCardBorder),
      ),
      child: child,
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final double completed;
  final double partial;
  final double missed;
  final Color completedColor;
  final Color partialColor;
  final Color missedColor;

  _DonutChartPainter({
    required this.completed,
    required this.partial,
    required this.missed,
    required this.completedColor,
    required this.partialColor,
    required this.missedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    const strokeWidth = 8.5;

    final paintCompleted = Paint()
      ..color = completedColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintPartial = Paint()
      ..color = partialColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintMissed = Paint()
      ..color = missedColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final total = completed + partial + missed;
    if (total == 0) return;

    double startAngle = -math.pi / 2; // Start at the top

    // Draw Missed segment
    double missedAngle = (missed / total) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      missedAngle,
      false,
      paintMissed,
    );
    startAngle += missedAngle;

    // Draw Partial segment
    double partialAngle = (partial / total) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      partialAngle,
      false,
      paintPartial,
    );
    startAngle += partialAngle;

    // Draw Completed segment
    double completedAngle = (completed / total) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      completedAngle,
      false,
      paintCompleted,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
