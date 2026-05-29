import 'package:flutter/material.dart';
import 'dart:ui';
import '../../api/habit_api_service.dart';
import '../../api/api_service.dart';
import '../../services/auth_service.dart';
import 'package:fl_chart/fl_chart.dart';
import '../paywall/paywall_screen.dart';
import 'monthly_recap_screen.dart';
import '../../theme/app_theme.dart';
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => StatsScreenState();
}

class StatsScreenState extends State<StatsScreen> {
  final _api = HabitApiService.instance;
  bool _isLoading = true;
  String? _error;
  
  Map<String, dynamic>? _stats;

  // AI Variables
  bool _isLoadingAi = false;
  List<String>? _aiInsights;
  String? _aiError;

  // Chart Toggle
  String _selectedChart = 'Monthly Progress';

  @override
  void initState() {
    super.initState();
    loadStats();
  }

  Future<void> loadStats({bool showLoading = true}) async {
    if (showLoading) setState(() { _isLoading = true; _error = null; });
    try {
      final stats = await _api.getGlobalStats();
      if (mounted) setState(() => _stats = stats);
      
      // Auto-load AI if Pro
      if (_stats?['isPro'] == true && _aiInsights == null) {
        _loadAiInsights();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAiInsights() async {
    setState(() { _isLoadingAi = true; _aiError = null; });
    try {
      final insights = await _api.getAiInsights();
      if (mounted) setState(() => _aiInsights = insights);
    } catch (e) {
      if (mounted) setState(() => _aiError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoadingAi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: context.colors.secondary));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: context.colors.danger, size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: context.colors.textSecondary)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: loadStats,
              child: Text('Retry', style: TextStyle(color: context.colors.secondary)),
            ),
          ],
        ),
      );
    }

    final totalHabits = (_stats?['totalHabits'] as num?)?.toInt() ?? 0;
    final globalStreak = (_stats?['globalStreak'] as num?)?.toInt() ?? 0;
    final totalCompletions = (_stats?['totalCompletions'] as num?)?.toInt() ?? 0;
    final bestHabitName = _stats?['bestHabitName'] as String? ?? 'None';
    final bestHabitCompletions = (_stats?['bestHabitCompletions'] as num?)?.toInt() ?? 0;
    final completionRate = (_stats?['completionRate'] as num?)?.toDouble() ?? 0.0;
    final bestStreak = (_stats?['bestStreak'] as num?)?.toInt() ?? 0;
    final activeDays = (_stats?['activeDays'] as num?)?.toInt() ?? 0;
    final isPro = _stats?['isPro'] as bool? ?? false;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: loadStats,
        color: context.colors.secondary,
        backgroundColor: context.colors.card,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Statistics',
                    style: TextStyle(color: context.colors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: () {
                      final now = DateTime.now();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MonthlyRecapScreen(
                            year: now.year,
                            month: now.month,
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.auto_graph, color: context.colors.secondary, size: 18),
                    label: Text('Monthly Recap', style: TextStyle(color: context.colors.secondary, fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      backgroundColor: context.colors.secondary.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // ── Global Streak Banner ───────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF7A55), Color(0xFFFF4848)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFFF524A).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.white, size: 48),
                    const SizedBox(height: 12),
                    Text('$globalStreak',
                      style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, height: 1)),
                    const SizedBox(height: 4),
                    const Text('Day Global Streak',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // ── Two columns stats ──────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.track_changes,
                      color: const Color(0xFF00B4DB),
                      value: '$totalHabits',
                      label: 'Active Habits',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF11998E),
                      value: '$totalCompletions',
                      label: 'Total Completions',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Best Habit ─────────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [context.colors.secondary, context.colors.secondary.withOpacity(0.8)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: context.colors.secondary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(Icons.emoji_events, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Top Performer',
                            style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(bestHabitName,
                            style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('$bestHabitCompletions completions',
                            style: TextStyle(color: context.colors.success, fontSize: 14, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Additional stats cards ────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.percent,
                      color: const Color(0xFF6A1B9A),
                      value: '${completionRate.toStringAsFixed(1)}%',
                      label: 'Completion Rate',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.whatshot,
                      color: const Color(0xFFFFA726),
                      value: '$bestStreak',
                      label: 'Best Streak',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      icon: Icons.calendar_today,
                      color: const Color(0xFF1976D2),
                      value: '$activeDays',
                      label: 'Active Days',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── AI Coach Insights ────────────────────────────────────────────
              _buildAiCoachCard(isPro),
              const SizedBox(height: 32),

              // ── PRO ONLY CHARTS ──────────────────────────────────────────────
              if (isPro)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
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
                          Text(_selectedChart, style: TextStyle(color: context.colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                          Theme(
                            data: Theme.of(context).copyWith(
                              popupMenuTheme: PopupMenuThemeData(
                                color: context.colors.iconBg,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                            child: PopupMenuButton<String>(
                              icon: Icon(Icons.more_horiz, color: context.colors.textSecondary),
                              offset: const Offset(0, 40),
                              onSelected: (value) => setState(() => _selectedChart = value),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'Monthly Progress',
                                  child: Row(
                                    children: [
                                      Icon(Icons.bar_chart, size: 20, color: _selectedChart == 'Monthly Progress' ? context.colors.secondary : context.colors.textSecondary),
                                      const SizedBox(width: 12),
                                      Text('Monthly Progress', style: TextStyle(color: _selectedChart == 'Monthly Progress' ? context.colors.textPrimary : context.colors.textSecondary)),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'Weekly Completion Rate',
                                  child: Row(
                                    children: [
                                      Icon(Icons.show_chart, size: 20, color: _selectedChart == 'Weekly Completion Rate' ? context.colors.secondary : context.colors.textSecondary),
                                      const SizedBox(width: 12),
                                      Text('Weekly Rate', style: TextStyle(color: _selectedChart == 'Weekly Completion Rate' ? context.colors.textPrimary : context.colors.textSecondary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: SizedBox(
                          key: ValueKey(_selectedChart),
                          height: 200,
                          child: _selectedChart == 'Monthly Progress'
                              ? _buildMonthlyChart()
                              : _buildWeeklyChart(),
                        ),
                      ),
                    ],
                  ),
                )
              else
                _buildLockedAnalyticsCard(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({required IconData icon, required Color color, required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 20),
          Text(value, style: TextStyle(color: context.colors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  // ── Monthly Progress Chart ───────────────────────────────────────
  Widget _buildMonthlyChart() {
    final monthlyProgress = (_stats?['monthlyProgress'] as List<dynamic>?) ?? [];
    if (monthlyProgress.isEmpty) {
      return Center(child: Text('No data', style: TextStyle(color: context.colors.textSecondary)));
    }

    double maxY = 10;
    for (var m in monthlyProgress) {
      final c = (m['completions'] as num).toDouble();
      if (c > maxY) maxY = c;
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value.toInt() >= 0 && value.toInt() < monthlyProgress.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      monthlyProgress[value.toInt()]['month'].toString(),
                      style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value == 0 || value == maxY.toInt()) {
                   return Text(value.toInt().toString(), style: TextStyle(color: context.colors.textSecondary, fontSize: 12));
                }
                return const Text('');
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          monthlyProgress.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: (monthlyProgress[i]['completions'] as num).toDouble(),
                gradient: LinearGradient(
                  colors: [context.colors.secondary, context.colors.secondary.withOpacity(0.8)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 22,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Weekly Completion Rate Chart ───────────────────────────────────
  Widget _buildWeeklyChart() {
    final weeklyProgress = (_stats?['weeklyCompletionRate'] as List<dynamic>?) ?? [];
    if (weeklyProgress.isEmpty) {
      return Center(child: Text('No data', style: TextStyle(color: context.colors.textSecondary)));
    }

    final spots = List.generate(weeklyProgress.length, (i) {
      return FlSpot(i.toDouble(), (weeklyProgress[i]['rate'] as num).toDouble());
    });

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value.toInt() >= 0 && value.toInt() < weeklyProgress.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      weeklyProgress[value.toInt()]['week'].toString(),
                      style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value == 0 || value == 50 || value == 100) {
                   return Text(value.toInt().toString(), style: TextStyle(color: context.colors.textSecondary, fontSize: 12));
                }
                return const Text('');
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: context.colors.success,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 4,
                color: context.colors.success,
                strokeWidth: 2,
                strokeColor: context.colors.card,
              ),
            ),
          ),
        ],
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }
  // ── AI Coach UI ──────────────────────────────────────────────────────────
  Widget _buildAiCoachCard(bool isPro) {
    if (!isPro) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colors.secondary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.auto_awesome, color: context.colors.secondary, size: 24),
                ),
                const SizedBox(width: 12),
                Text('AI Habit Coach', style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Text('Unlock PRO to get weekly personalized insights and productivity tips driven by AI.', style: TextStyle(color: context.colors.textSecondary, fontSize: 14)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final purchased = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
                  if (purchased == true) {
                    try {
                      final token = await AuthService.instance.getToken();
                      if (token != null) await ApiService().upgradeToPro(token, 'monthly');
                    } catch (_) {}
                    loadStats(showLoading: false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.iconBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                child: Text('Unlock AI Coach', style: TextStyle(color: context.colors.secondary, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.secondary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: context.colors.secondary.withOpacity(0.05), blurRadius: 20, spreadRadius: 2),
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [context.colors.secondary, context.colors.secondary.withOpacity(0.8)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('AI Coach Insights', style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                icon: Icon(Icons.refresh, color: context.colors.textSecondary),
                onPressed: _isLoadingAi ? null : _loadAiInsights,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingAi)
            Center(child: Padding(padding: const EdgeInsets.all(32), child: CircularProgressIndicator(color: context.colors.secondary)))
          else if (_aiError != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: context.colors.danger.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
              child: Text('Error: $_aiError', style: TextStyle(color: context.colors.danger, fontSize: 13)),
            )
          else if (_aiInsights != null && _aiInsights!.isNotEmpty)
            ...List.generate(_aiInsights!.length, (index) => _buildInsightCard(_aiInsights![index], index))
          else
            Center(child: Text('No insights available yet.', style: TextStyle(color: context.colors.textSecondary))),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String text, int index) {
    final icons = [Icons.psychology_outlined, Icons.auto_awesome_outlined, Icons.tips_and_updates_outlined];
    final titles = ["Neural Pattern", "Behavioral Logic", "Coach's Action"];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.iconBg.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icons[index % icons.length], color: context.colors.secondary, size: 20),
              const SizedBox(width: 10),
              Text(
                titles[index % titles.length].toUpperCase(),
                style: TextStyle(color: context.colors.secondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(color: context.colors.textPrimary, fontSize: 14, height: 1.6, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedAnalyticsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.secondary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_outline, color: context.colors.secondary, size: 40),
          ),
          const SizedBox(height: 20),
          Text('Advanced Analytics', style: TextStyle(color: context.colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
            'Unlock deep insights into your habit trends, weekly progress, and more.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colors.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () async {
              final purchased = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
              if (purchased == true) {
                try {
                  final token = await AuthService.instance.getToken();
                  if (token != null) await ApiService().upgradeToPro(token, 'monthly');
                } catch (_) {}
                loadStats(showLoading: false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.secondary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
              elevation: 0,
            ),
            child: const Text('Unlock PRO', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
