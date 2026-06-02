import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../api/habit_api_service.dart';
import 'monthly_recap_screen.dart';

const _kBg = Color(0xFF1A1A1A);
const _kCard = Color(0xFF242424);
const _kCardBorder = Color(0xFF2E2E2E);
const _kSage = Color(0xFF8BA888);
const _kLavender = Color(0xFF9F92C6);
const _kTerra = Color(0xFFD68C7A);
const _kGold = Color(0xFFFFD700);
const _kText = Color(0xFFE8E8E8);
const _kTextSub = Color(0xFF888888);

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _api = HabitApiService.instance;
  bool _isLoading = true;
  String? _error;
  
  Map<String, dynamic>? _stats;
  List<String>? _aiInsights;
  bool _isWeekly = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final stats = await _api.getGlobalStats();
      if (mounted) setState(() => _stats = stats);
      
      if (_stats?['isPro'] == true && _aiInsights == null) {
        final insights = await _api.getAiInsights();
        if (mounted) setState(() => _aiInsights = insights);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
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
              const Icon(Icons.error_outline, color: _kTerra, size: 48),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: _kTextSub)),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _loadData,
                child: const Text('Retry', style: TextStyle(color: _kGold)),
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
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
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
                        const SizedBox(height: 4),
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
                      padding: const EdgeInsets.all(4),
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
                const SizedBox(height: 32),

                // Top Bento - Completions Chart
                _BentoCard(
                  height: 160,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF64B5F6).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.show_chart_rounded, color: Color(0xFF64B5F6), size: 16),
                          ),
                          const SizedBox(width: 12),
                          const Text('Completions', style: TextStyle(color: _kTextSub, fontSize: 13, fontWeight: FontWeight.w500)),
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
                              const SizedBox(height: 4),
                              Text(_isWeekly ? 'this week' : 'last 24 days', style: const TextStyle(color: _kTextSub, fontSize: 13)),
                            ],
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildArtisticBarChart(_isWeekly, _isWeekly ? currentWeekData : currentMonthData),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

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
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _kTerra.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.local_fire_department_rounded, color: _kTerra, size: 18),
                            ),
                            const Spacer(),
                            Text('$globalStreak', style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 32, fontWeight: FontWeight.bold, height: 1.0)),
                            const SizedBox(height: 4),
                            const Text('global streak', style: TextStyle(color: _kTextSub, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 6,
                      child: _BentoCard(
                        height: 175,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _kLavender.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.bolt_rounded, color: _kLavender, size: 18),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _miniEmojiTile('🧘‍♀️', _kSage),
                                const SizedBox(width: 6),
                                _miniEmojiTile('💧', const Color(0xFF64B5F6)),
                                const SizedBox(width: 6),
                                _miniEmojiTile('📖', _kLavender),
                              ],
                            ),
                            const Spacer(),
                            Text('$totalHabits', style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 32, fontWeight: FontWeight.bold, height: 1.0)),
                            const SizedBox(height: 4),
                            const Text('active habits', style: TextStyle(color: _kTextSub, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

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
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _kGold.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.emoji_events_rounded, color: _kGold, size: 18),
                            ),
                            const Spacer(),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text('$bestStreak', style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 32, fontWeight: FontWeight.bold, height: 1.0)),
                                const SizedBox(width: 4),
                                const Text('d', style: TextStyle(color: _kTextSub, fontSize: 16, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text('best streak', style: TextStyle(color: _kTextSub, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
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
                                        color: const Color(0xFF262E26), // very dark green-charcoal
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
                                              color: Colors.white,
                                              fontSize: 30,
                                              fontWeight: FontWeight.w400,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                          WidgetSpan(
                                            alignment: PlaceholderAlignment.top,
                                            child: Padding(
                                              padding: const EdgeInsets.only(left: 1, top: 4),
                                              child: Text(
                                                '%',
                                                style: GoogleFonts.inter(
                                                  color: Colors.white.withOpacity(0.45),
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
                              const SizedBox(height: 16),
                              const Text(
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
                const SizedBox(height: 16),

                // AI Coach Insight Card — shown only for Pro users
                if (isPro) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
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
                                const Icon(Icons.auto_awesome_rounded, color: _kLavender, size: 20),
                                const SizedBox(width: 8),
                                Text('AI Coach', style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 18, fontWeight: FontWeight.w600)),
                              ],
                            ),
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(color: _kSage, shape: BoxShape.circle, boxShadow: [BoxShadow(color: _kSage, blurRadius: 4)]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _aiInsights != null && _aiInsights!.isNotEmpty
                              ? _aiInsights!.first
                              : 'Breathing exercises show 91% adherence — your highest performing habit. Consistency is your superpower. 🌿',
                          style: const TextStyle(color: _kTextSub, fontSize: 14, height: 1.6),
                        ),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Full analysis report is being generated... (Coming soon!)'),
                                backgroundColor: _kLavender,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: const Row(
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
                  const SizedBox(height: 16),
                ],

                // Monthly Recap CTA
                GestureDetector(
                  onTap: () {
                    final now = DateTime.now();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MonthlyRecapScreen(year: now.year, month: now.month),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: _kCardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _kSage.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.calendar_today_rounded, color: _kSage, size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Monthly Recap', style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 18, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('${DateFormat('MMMM yyyy').format(DateTime.now())} - ${completionRate.toInt()}% completion', style: const TextStyle(color: _kTextSub, fontSize: 13)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _kTextSub.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_forward_rounded, color: _kTextSub, size: 16),
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
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 12))),
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
            color: isToday ? const Color(0xFF64B5F6) : const Color(0xFF64B5F6).withOpacity(0.3),
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
          const SizedBox(height: 8),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    return Container(
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kCardBorder),
      ),
      child: child,
    );
  }
}
