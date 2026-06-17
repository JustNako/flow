import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../api/habit_api_service.dart';
import '../../models/ai_insights_response.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';
import 'full_analysis_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

mixin _ThemeColorsMixin<T extends StatefulWidget> on State<T> {
  Color get _kBg => context.colors.background;
  Color get _kCard => context.colors.card;
  Color get _kCardBorder => context.colors.border;
  Color get _kSage => context.colors.sage;
  Color get _kLavender => context.colors.lavender;
  Color get _kTerra => context.colors.terracotta;
  Color get _kGold => context.colors.gold;
  Color get _kText => context.colors.textPrimary;
  Color get _kTextSub => context.colors.textSecondary;
}

class _StatsScreenState extends State<StatsScreen> with _ThemeColorsMixin<StatsScreen> {
  final _api = HabitApiService.instance;
  bool _isLoading = true;
  String? _error;
  
  Map<String, dynamic>? _stats;
  AiInsightsResponse? _aiInsights;
  String? _aiInsightsError;
  bool _aiInsightsLoading = false;
  bool _isWeekly = false;

  // Retry cooldown — 30 seconds between retry attempts
  static const _retryCooldownSecs = 30;
  int _retryCountdown = 0;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }

  void _startRetryCooldown() {
    _retryTimer?.cancel();
    setState(() => _retryCountdown = _retryCooldownSecs);
    _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _retryCountdown--;
        if (_retryCountdown <= 0) {
          _retryCountdown = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final stats = await _api.getGlobalStats();
      if (mounted) setState(() => _stats = stats);

      if (_stats?['isPro'] == true) {
        _loadAiInsights();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAiInsights() async {
    if (_aiInsightsLoading || _retryCountdown > 0) return;
    setState(() {
      _aiInsightsLoading = true;
      _aiInsightsError = null;
    });
    try {
      final insights = await _api.getAiInsights();
      if (mounted) {
        setState(() {
          _aiInsights = insights;
          _aiInsightsError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiInsightsError = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _aiInsightsLoading = false);
        _startRetryCooldown();
      }
    }
  }

  void _showMonthlyRecapSheet(BuildContext context, double completionRate) {
    final now = DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(now);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _MonthlyRecapSheet(
        api: _api,
        year: now.year,
        month: now.month,
        monthName: monthName,
        completionRate: completionRate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kGold)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: _kBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: _kTerra, size: 48),
              SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: _kTextSub)),
              SizedBox(height: 16),
              TextButton(
                onPressed: _loadData,
                child: Text('Retry', style: TextStyle(color: _kGold)),
              ),
            ],
          ),
        ),
      );
    }

    final globalStreak = (_stats?['globalStreak'] as num?)?.toInt() ?? 0;
    final totalHabits = (_stats?['totalHabits'] as num?)?.toInt() ?? 0;
    final bestStreak = (_stats?['bestStreak'] as num?)?.toInt() ?? 0;
    final completionRate = (_stats?['completionRate'] as num?)?.toDouble() ?? 0.0;
    final isPro = _stats?['isPro'] as bool? ?? false;
    
    // Real data for completions
    final currentWeekData = (_stats?['currentWeekCompletions'] as List<dynamic>?)?.map((e) => e as int).toList() ?? List.filled(7, 0);
    final currentMonthData = (_stats?['last30DaysCompletions'] as List<dynamic>?)?.map((e) => e as int).toList() ?? List.filled(24, 0);
    
    final completions = _isWeekly 
        ? currentWeekData.fold<int>(0, (p, c) => p + c)
        : currentMonthData.fold<int>(0, (p, c) => p + c);

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: _kGold,
          backgroundColor: _kCard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: EdgeInsets.fromLTRB(24, 32, 24, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR JOURNEY',
                          style: GoogleFonts.inter(
                            color: _kTextSub,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Insights',
                          style: GoogleFonts.playfairDisplay(
                            color: _kText,
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                    // Toggle
                    Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _kCardBorder.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: _kCardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ToggleBtn(
                            label: 'Weekly',
                            isSelected: _isWeekly,
                            onTap: () => setState(() => _isWeekly = true),
                          ),
                          _ToggleBtn(
                            label: 'Monthly',
                            isSelected: !_isWeekly,
                            onTap: () => setState(() => _isWeekly = false),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
                SizedBox(height: 32),

                // Top Bento - Completions Chart
                _BentoCard(
                  height: 160,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.show_chart_rounded, color: context.colors.blue, size: 16),
                          ),
                          SizedBox(width: 12),
                          Text('Completions', style: TextStyle(color: _kTextSub, fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('$completions', style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 42, fontWeight: FontWeight.bold, height: 1.0)),
                              SizedBox(height: 4),
                              Text(_isWeekly ? 'this week' : 'last 24 days', style: TextStyle(color: _kTextSub, fontSize: 13)),
                            ],
                          ),
                          SizedBox(width: 24),
                          Expanded(
                            child: _buildArtisticBarChart(_isWeekly, _isWeekly ? currentWeekData : currentMonthData),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Middle Bento row 1
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: _BentoCard(
                        height: 175,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _kTerra.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.local_fire_department_rounded, color: _kTerra, size: 18),
                            ),
                            const Spacer(),
                            Text('$globalStreak', style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 32, fontWeight: FontWeight.bold, height: 1.0)),
                            SizedBox(height: 4),
                            Text('global streak', style: TextStyle(color: _kTextSub, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      flex: 6,
                      child: _BentoCard(
                        height: 175,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _kLavender.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.bolt_rounded, color: _kLavender, size: 18),
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                _miniEmojiTile('🧘‍♀️', _kSage),
                                SizedBox(width: 6),
                                _miniEmojiTile('💧', context.colors.blue),
                                SizedBox(width: 6),
                                _miniEmojiTile('📖', _kLavender),
                              ],
                            ),
                            const Spacer(),
                            Text('$totalHabits', style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 32, fontWeight: FontWeight.bold, height: 1.0)),
                            SizedBox(height: 4),
                            Text('active habits', style: TextStyle(color: _kTextSub, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Middle Bento row 2
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: _BentoCard(
                        height: 175,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _kGold.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.emoji_events_rounded, color: _kGold, size: 18),
                            ),
                            const Spacer(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text('$bestStreak', style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 32, fontWeight: FontWeight.bold, height: 1.0)),
                                SizedBox(width: 4),
                                Text('d', style: TextStyle(color: _kTextSub, fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            SizedBox(height: 4),
                            Text('best streak', style: TextStyle(color: _kTextSub, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      flex: 6,
                      child: _BentoCard(
                        height: 175,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 90,
                                height: 90,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // 1. Dark, elegant progress ring background track
                                    SizedBox(
                                      width: 82,
                                      height: 82,
                                      child: CircularProgressIndicator(
                                        value: 1.0,
                                        strokeWidth: 6.5,
                                        color: context.isDark ? const Color(0xFF262E26) : context.colors.border, // progress track
                                      ),
                                    ),
                                    // 2. Animated Active Sage green progress ring
                                    SizedBox(
                                      width: 82,
                                      height: 82,
                                      child: TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 0.0, end: (completionRate / 100).clamp(0.0, 1.0)),
                                        duration: const Duration(milliseconds: 1500),
                                        curve: Curves.easeOutCubic,
                                        builder: (context, val, child) {
                                          return CircularProgressIndicator(
                                            value: val.isNaN ? 0.0 : val,
                                            strokeWidth: 6.5,
                                            strokeCap: StrokeCap.round,
                                            color: _kSage,
                                            backgroundColor: Colors.transparent,
                                          );
                                        },
                                      ),
                                    ),
                                    // 3. High-end typography matching the user mockup
                                    RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '${completionRate.isNaN ? 0 : completionRate.toInt()}',
                                            style: GoogleFonts.playfairDisplay(
                                              color: _kText,
                                              fontSize: 30,
                                              fontWeight: FontWeight.w400,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                          WidgetSpan(
                                            alignment: PlaceholderAlignment.top,
                                            child: Padding(
                                              padding: EdgeInsets.only(left: 1, top: 4),
                                              child: Text(
                                                '%',
                                                style: GoogleFonts.inter(
                                                  color: _kText.withOpacity(0.45),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'completion rate',
                                style: TextStyle(
                                  color: _kTextSub,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // AI Coach Insight Card — shown only for Pro users
                if (isPro) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _kLavender.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(color: _kLavender.withOpacity(0.08), blurRadius: 40, spreadRadius: 0),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.auto_awesome_rounded, color: _kLavender, size: 20),
                                SizedBox(width: 8),
                                Text('AI Coach', style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 18, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                color: (_aiInsights?.isPersonalized ?? false) ? _kSage : _kGold,
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: (_aiInsights?.isPersonalized ?? false) ? _kSage : _kGold, blurRadius: 4)],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        if (_aiInsightsLoading)
                          Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: _kLavender),
                              ),
                            ),
                          )
                        else if (_aiInsightsError != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Personalized analysis unavailable',
                                style: TextStyle(color: _kTerra, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              SizedBox(height: 8),
                              Text(
                                _aiInsightsError!,
                                style: TextStyle(color: _kTextSub, fontSize: 13, height: 1.5),
                              ),
                              SizedBox(height: 8),
                              GestureDetector(
                                onTap: _retryCountdown > 0 ? null : _loadAiInsights,
                                child: Text(
                                  _retryCountdown > 0
                                      ? 'Retry in ${_retryCountdown}s...'
                                      : 'Tap to retry',
                                  style: TextStyle(
                                    color: _retryCountdown > 0 ? _kTextSub : _kLavender,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _aiInsights != null && _aiInsights!.insights.isNotEmpty
                                    ? _aiInsights!.insights.first
                                    : 'Your personalized insights will appear here once we have enough data from the past week.',
                                style: TextStyle(color: _kTextSub, fontSize: 14, height: 1.6),
                              ),
                              if (_aiInsights != null && !_aiInsights!.isPersonalized) ...[
                                SizedBox(height: 8),
                                GestureDetector(
                                  onTap: _retryCountdown > 0 ? null : _loadAiInsights,
                                  child: Text(
                                    _retryCountdown > 0
                                        ? 'Retry in ${_retryCountdown}s...'
                                        : 'Tap to retry',
                                    style: TextStyle(
                                      color: _retryCountdown > 0 ? _kTextSub : _kLavender,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        SizedBox(height: 20),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const FullAnalysisScreen(),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Text('Full analysis', style: TextStyle(color: _kLavender, fontSize: 13, fontWeight: FontWeight.w500)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, color: _kLavender, size: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                ],

                // Monthly Recap CTA
                GestureDetector(
                  onTap: () => _showMonthlyRecapSheet(context, completionRate),
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _kCardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _kSage.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.calendar_today_rounded, color: _kSage, size: 20),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Monthly Recap', style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 18, fontWeight: FontWeight.w600)),
                              SizedBox(height: 4),
                              Text('${DateFormat('MMMM yyyy').format(DateTime.now())} - ${completionRate.toInt()}% completion', style: TextStyle(color: _kTextSub, fontSize: 13)),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _kTextSub.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.arrow_forward_rounded, color: _kTextSub, size: 16),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniEmojiTile(String emoji, Color color) {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(child: Text(emoji, style: TextStyle(fontSize: 12))),
    );
  }

  Widget _buildArtisticBarChart(bool isWeekly, List<int> values) {
    final count = isWeekly ? 7 : 24;
    final displayValues = values.take(count).toList();
    if (displayValues.length < count) {
      displayValues.addAll(List.filled(count - displayValues.length, 0));
    }

    final maxVal = displayValues.reduce((a, b) => math.max(a, b));
    final baseline = maxVal > 0 ? maxVal : 1;
    
    final bars = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(count, (index) {
        final val = displayValues[index];
        final heightRatio = 0.2 + ((val / baseline) * 0.8);
        final isToday = index == (isWeekly ? DateTime.now().weekday - 1 : count - 1);
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          width: isWeekly ? 16 : 4,
          height: 60 * heightRatio,
          decoration: BoxDecoration(
            color: isToday ? context.colors.blue : context.colors.blue.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );

    if (!isWeekly) return SizedBox(height: 60, child: bars);

    return SizedBox(
      height: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Expanded(child: bars),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
              return SizedBox(
                width: 16,
                child: Center(
                  child: Text(day, style: TextStyle(color: _kTerra.withOpacity(0.7), fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleBtn({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final _kCardBorder = context.colors.border;
    final _kText = context.colors.textPrimary;
    final _kTextSub = context.colors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _kCardBorder : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? _kText : _kTextSub,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _BentoCard extends StatelessWidget {
  final Widget child;
  final double height;

  const _BentoCard({required this.child, required this.height});

  @override
  Widget build(BuildContext context) {
    final _kCard = context.colors.card;
    final _kCardBorder = context.colors.border;
    return Container(
      height: height,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kCardBorder),
      ),
      child: child,
    );
  }
}

class _MonthlyRecapSheet extends StatefulWidget {
  final HabitApiService api;
  final int year;
  final int month;
  final String monthName;
  final double completionRate;

  const _MonthlyRecapSheet({
    required this.api,
    required this.year,
    required this.month,
    required this.monthName,
    required this.completionRate,
  });

  @override
  State<_MonthlyRecapSheet> createState() => _MonthlyRecapSheetState();
}

class _MonthlyRecapSheetState extends State<_MonthlyRecapSheet> with _ThemeColorsMixin<_MonthlyRecapSheet> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _recapData;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _fetchRecap();
  }

  Future<void> _fetchRecap() async {
    try {
      final data = await widget.api.getMonthlyRecap(widget.year, widget.month);
      setState(() {
        _recapData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _shareRecap(bool copyToClipboard) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final totalRate = (_recapData?['totalCompletionRate'] as num?)?.toInt() ?? widget.completionRate.toInt();
      final bestHabit = _recapData?['bestHabit'] as String? ?? 'None';
      final summaries = (_recapData?['habitSummaries'] as List<dynamic>? ?? []);
      final bestStreak = summaries.fold<int>(0, (prev, s) {
        final v = ((s as Map<String, dynamic>)['bestStreak'] as num?)?.toInt() ?? 0;
        return v > prev ? v : prev;
      });

      String archetypeTitle;
      String archetypeDesc;
      if (totalRate >= 85) {
        archetypeTitle = 'DISCIPLINE MACHINE';
        archetypeDesc = 'You kept showing up even on difficult days.';
      } else if (totalRate >= 60 && bestStreak > 10) {
        archetypeTitle = 'MOMENTUM BUILDER';
        archetypeDesc = 'You know how to keep a chain going.';
      } else if (totalRate >= 40) {
        archetypeTitle = 'THE CONSISTENT ONE';
        archetypeDesc = 'Slow and steady wins the race.';
      } else {
        archetypeTitle = 'COMEBACK HERO';
        archetypeDesc = 'Every great journey starts with a single step.';
      }

      final link = await widget.api.shareMonthlyRecap(
        year: widget.year,
        month: widget.month,
        totalRate: totalRate,
        bestStreak: bestStreak,
        bestHabit: bestHabit,
        archetypeTitle: archetypeTitle,
        archetypeDesc: archetypeDesc,
      );

      if (copyToClipboard) {
        await Clipboard.setData(ClipboardData(text: link));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recap link copied to clipboard! 📋'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        await Share.share(
          "I crushed my habits this month! See my interactive recap: $link",
          subject: "My ${widget.monthName} Recap",
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share recap: $e'),
            backgroundColor: _kTerra,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _kCardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MONTHLY RECAP',
                    style: GoogleFonts.inter(
                      color: _kTextSub,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close_rounded, color: _kTextSub, size: 22),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.monthName,
                  style: GoogleFonts.playfairDisplay(
                    color: _kText,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(height: 24),

              if (_isLoading)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: _kGold),
                  ),
                )
              else if (_error != null)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline_rounded, color: _kTerra, size: 40),
                      SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _kTextSub, fontSize: 14),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _fetchRecap();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kCard,
                          foregroundColor: _kText,
                        ),
                        child: Text('Retry'),
                      )
                    ],
                  ),
                )
              else
                ..._buildRecapContent(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRecapContent() {
    final totalRate = (_recapData?['totalCompletionRate'] as num?)?.toInt() ?? widget.completionRate.toInt();
    final bestHabit = _recapData?['bestHabit'] as String? ?? 'None';
    final completedDays = (_recapData?['completedDaysCount'] as num?)?.toInt() ?? 0;
    final summaries = (_recapData?['habitSummaries'] as List<dynamic>? ?? []);
    final bestStreak = summaries.fold<int>(0, (prev, s) {
      final v = ((s as Map<String, dynamic>)['bestStreak'] as num?)?.toInt() ?? 0;
      return v > prev ? v : prev;
    });
    final aiInsight = _recapData?['aiInsight'] as String?;

    String archetypeTitle;
    String archetypeDesc;
    Color archetypeColor;
    if (totalRate >= 85) {
      archetypeTitle = 'DISCIPLINE MACHINE';
      archetypeDesc = 'You kept showing up even on difficult days.';
      archetypeColor = _kGold;
    } else if (totalRate >= 60 && bestStreak > 10) {
      archetypeTitle = 'MOMENTUM BUILDER';
      archetypeDesc = 'You know how to keep a chain going.';
      archetypeColor = _kLavender;
    } else if (totalRate >= 40) {
      archetypeTitle = 'THE CONSISTENT ONE';
      archetypeDesc = 'Slow and steady wins the race.';
      archetypeColor = _kSage;
    } else {
      archetypeTitle = 'COMEBACK HERO';
      archetypeDesc = 'Every great journey starts with a single step.';
      archetypeColor = _kTerra;
    }

    return [
      // Circular Indicator & Archetype Badge
      Center(
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
                  child: CircularProgressIndicator(
                    value: totalRate / 100,
                    strokeWidth: 10,
                    color: archetypeColor,
                    backgroundColor: _kCardBorder,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$totalRate%',
                      style: GoogleFonts.playfairDisplay(
                        color: _kText,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Success Rate',
                      style: TextStyle(color: _kTextSub, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 24),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: archetypeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: archetypeColor.withOpacity(0.3)),
              ),
              child: Text(
                archetypeTitle,
                style: TextStyle(
                  color: archetypeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                archetypeDesc,
                textAlign: TextAlign.center,
                style: TextStyle(color: _kTextSub, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
      SizedBox(height: 32),

      // Stats Grid (Bento style)
      Row(
        children: [
          Expanded(
            child: _BentoStatCard(
              title: 'BEST STREAK',
              value: '$bestStreak days',
              icon: Icons.local_fire_department_rounded,
              iconColor: _kTerra,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: _BentoStatCard(
              title: 'BEST HABIT',
              value: bestHabit,
              icon: Icons.star_rounded,
              iconColor: _kGold,
            ),
          ),
        ],
      ),
      SizedBox(height: 16),
      _BentoStatCard(
        title: 'COMPLETIONS',
        value: '$completedDays habit logs completed',
        icon: Icons.check_circle_rounded,
        iconColor: _kSage,
        isFullWidth: true,
      ),
      SizedBox(height: 20),

      // AI Insight if present
      if (aiInsight != null && aiInsight.isNotEmpty) ...[
        Container(
          padding: EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kCardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _kLavender.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.auto_awesome_rounded, color: _kLavender, size: 16),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'AI INSIGHT',
                    style: GoogleFonts.inter(
                      color: _kLavender,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              Text(
                aiInsight,
                style: TextStyle(color: _kText, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        SizedBox(height: 24),
      ],

      // Actions
      Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isSharing ? null : () => _shareRecap(false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGold,
                  foregroundColor: Colors.black,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSharing
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.share_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Share Link',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: 54,
            height: 54,
            child: TextButton(
              onPressed: _isSharing ? null : () => _shareRecap(true),
              style: TextButton.styleFrom(
                backgroundColor: _kCard,
                foregroundColor: _kText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: _kCardBorder),
                ),
              ),
              child: Icon(Icons.copy_rounded, size: 20),
            ),
          ),
        ],
      ),
      SizedBox(height: 20),
    ];
  }
}

class _BentoStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final bool isFullWidth;

  const _BentoStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final _kCard = context.colors.card;
    final _kCardBorder = context.colors.border;
    final _kTextSub = context.colors.textSecondary;
    final _kText = context.colors.textPrimary;
    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: _kTextSub,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              color: _kText,
              fontSize: isFullWidth ? 18 : 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
