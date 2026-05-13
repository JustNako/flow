import 'package:flutter/material.dart';
import 'dart:ui';
import '../../api/habit_api_service.dart';
import '../../api/api_service.dart';
import '../../services/auth_service.dart';
import 'package:fl_chart/fl_chart.dart';
import '../paywall/paywall_screen.dart';
import 'monthly_recap_screen.dart';
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
      return const Center(child: CircularProgressIndicator(color: Color(0xFFDA22FF)));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFFF5252), size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Color(0xFF8A8F9E))),
            const SizedBox(height: 16),
            TextButton(
              onPressed: loadStats,
              child: const Text('Retry', style: TextStyle(color: Color(0xFFDA22FF))),
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
        color: const Color(0xFFDA22FF),
        backgroundColor: const Color(0xFF161A22),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Statistics',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
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
                    icon: const Icon(Icons.auto_graph, color: Color(0xFFDA22FF), size: 18),
                    label: const Text('Monthly Recap', style: TextStyle(color: Color(0xFFDA22FF), fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFDA22FF).withOpacity(0.1),
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
                  color: const Color(0xFF161A22),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.03)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFDA22FF), Color(0xFF9733EE)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: const Color(0xFFDA22FF).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
                      ),
                      child: const Icon(Icons.emoji_events, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Top Performer',
                            style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(bestHabitName,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Text('$bestHabitCompletions completions',
                            style: const TextStyle(color: Color(0xFF00E676), fontSize: 14, fontWeight: FontWeight.w500)),
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
                    color: const Color(0xFF161A22),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.03)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_selectedChart, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          Theme(
                            data: Theme.of(context).copyWith(
                              popupMenuTheme: PopupMenuThemeData(
                                color: const Color(0xFF262A34),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                            child: PopupMenuButton<String>(
                              icon: const Icon(Icons.more_horiz, color: Color(0xFF8A8F9E)),
                              offset: const Offset(0, 40),
                              onSelected: (value) => setState(() => _selectedChart = value),
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'Monthly Progress',
                                  child: Row(
                                    children: [
                                      Icon(Icons.bar_chart, size: 20, color: _selectedChart == 'Monthly Progress' ? const Color(0xFFDA22FF) : const Color(0xFF8A8F9E)),
                                      const SizedBox(width: 12),
                                      Text('Monthly Progress', style: TextStyle(color: _selectedChart == 'Monthly Progress' ? Colors.white : const Color(0xFF8A8F9E))),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'Weekly Completion Rate',
                                  child: Row(
                                    children: [
                                      Icon(Icons.show_chart, size: 20, color: _selectedChart == 'Weekly Completion Rate' ? const Color(0xFFDA22FF) : const Color(0xFF8A8F9E)),
                                      const SizedBox(width: 12),
                                      Text('Weekly Rate', style: TextStyle(color: _selectedChart == 'Weekly Completion Rate' ? Colors.white : const Color(0xFF8A8F9E))),
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
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
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
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 13)),
        ],
      ),
    );
  }

  // ── Monthly Progress Chart ───────────────────────────────────────
  Widget _buildMonthlyChart() {
    final monthlyProgress = (_stats?['monthlyProgress'] as List<dynamic>?) ?? [];
    if (monthlyProgress.isEmpty) {
      return const Center(child: Text('No data', style: TextStyle(color: Color(0xFF8A8F9E))));
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
                      style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 12),
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
                   return Text(value.toInt().toString(), style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 12));
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
                gradient: const LinearGradient(
                  colors: [Color(0xFFDA22FF), Color(0xFF9733EE)],
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
      return const Center(child: Text('No data', style: TextStyle(color: Color(0xFF8A8F9E))));
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
                      style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 12),
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
                   return Text(value.toInt().toString(), style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 12));
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
            color: const Color(0xFF00E676),
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 4,
                color: const Color(0xFF00E676),
                strokeWidth: 2,
                strokeColor: const Color(0xFF161A22),
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
          color: const Color(0xFF161A22),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.03)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDA22FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Color(0xFFDA22FF), size: 24),
                ),
                const SizedBox(width: 12),
                const Text('AI Habit Coach', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Unlock PRO to get weekly personalized insights and productivity tips driven by AI.', style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 14)),
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
                  backgroundColor: const Color(0xFF262A34),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Unlock AI Coach', style: TextStyle(color: Color(0xFFDA22FF), fontWeight: FontWeight.bold)),
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
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDA22FF).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: const Color(0xFFDA22FF).withOpacity(0.05), blurRadius: 20, spreadRadius: 2),
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
                      gradient: const LinearGradient(colors: [Color(0xFFDA22FF), Color(0xFF9733EE)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('AI Coach Insights', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Color(0xFF8A8F9E)),
                onPressed: _isLoadingAi ? null : _loadAiInsights,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoadingAi)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFFDA22FF))))
          else if (_aiError != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
              child: Text('Error: $_aiError', style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            )
          else if (_aiInsights != null && _aiInsights!.isNotEmpty)
            ...List.generate(_aiInsights!.length, (index) => _buildInsightCard(_aiInsights![index], index))
          else
            const Center(child: Text('No insights available yet.', style: TextStyle(color: Color(0xFF8A8F9E)))),
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
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icons[index % icons.length], color: const Color(0xFFDA22FF), size: 20),
              const SizedBox(width: 10),
              Text(
                titles[index % titles.length].toUpperCase(),
                style: const TextStyle(color: Color(0xFFDA22FF), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.6, letterSpacing: 0.2),
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
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFDA22FF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline, color: Color(0xFFDA22FF), size: 40),
          ),
          const SizedBox(height: 20),
          const Text('Advanced Analytics', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text(
            'Unlock deep insights into your habit trends, weekly progress, and more.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 14, height: 1.5),
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
              backgroundColor: const Color(0xFFDA22FF),
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
