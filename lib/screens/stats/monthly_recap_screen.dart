import 'package:flutter/material.dart';
import '../../api/habit_api_service.dart';
import 'dart:ui';

class MonthlyRecapScreen extends StatefulWidget {
  final int year;
  final int month;

  const MonthlyRecapScreen({super.key, required this.year, required this.month});

  @override
  State<MonthlyRecapScreen> createState() => _MonthlyRecapScreenState();
}

class _MonthlyRecapScreenState extends State<MonthlyRecapScreen> {
  final _api = HabitApiService.instance;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _recap;

  @override
  void initState() {
    super.initState();
    _loadRecap();
  }

  Future<void> _loadRecap() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _api.getMonthlyRecap(widget.year, widget.month);
      setState(() => _recap = data);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1017),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _recap?['monthName'] ?? 'Monthly Recap',
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFDA22FF)))
          : _error != null
              ? _buildErrorView()
              : _buildRecapView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics_outlined, color: Color(0xFF8A8F9E), size: 64),
            const SizedBox(height: 24),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadRecap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDA22FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecapView() {
    final totalRate = (_recap?['totalCompletionRate'] as num?)?.toInt() ?? 0;
    final totalCompletions = (_recap?['completedDaysCount'] as num?)?.toInt() ?? 0;
    final habitSummaries = (_recap?['habitSummaries'] as List<dynamic>?) ?? [];
    final aiInsight = _recap?['aiInsight'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main Score Card ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDA22FF), Color(0xFF9733EE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDA22FF).withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 120,
                      width: 120,
                      child: CircularProgressIndicator(
                        value: totalRate / 100,
                        strokeWidth: 12,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        color: Colors.white,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '$totalRate%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Success',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Total Completions: $totalCompletions',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ── AI Insight Card ─────────────────────────────────────────────
          if (aiInsight.isNotEmpty) ...[
            const Text(
              'Coach Insights',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF161A22),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFDA22FF).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Color(0xFFDA22FF), size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'AI ANALYSIS',
                        style: TextStyle(
                          color: const Color(0xFFDA22FF).withOpacity(0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    aiInsight,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.6,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],

          // ── Habit Summaries List ────────────────────────────────────────
          const Text(
            'Habit Performance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...habitSummaries.map((s) => _buildHabitSummaryCard(s)).toList(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHabitSummaryCard(Map<String, dynamic> summary) {
    final title = summary['title'] as String? ?? 'Habit';
    final rate = (summary['completionRate'] as num?)?.toInt() ?? 0;
    final bestStreak = (summary['bestStreak'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.whatshot, color: Color(0xFFFFA726), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Best Streak: $bestStreak days',
                      style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$rate%',
                style: TextStyle(
                  color: _getRateColor(rate),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Text(
                'Rate',
                style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRateColor(int rate) {
    if (rate >= 80) return const Color(0xFF00E676);
    if (rate >= 50) return const Color(0xFFFFA726);
    return const Color(0xFFFF5252);
  }
}
