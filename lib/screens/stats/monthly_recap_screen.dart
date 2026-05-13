import 'package:flutter/material.dart';
import '../../api/habit_api_service.dart';

class MonthlyRecapScreen extends StatefulWidget {
  final int year;
  final int month;

  const MonthlyRecapScreen({super.key, required this.year, required this.month});

  @override
  State<MonthlyRecapScreen> createState() => _MonthlyRecapScreenState();
}

class _MonthlyRecapScreenState extends State<MonthlyRecapScreen>
    with SingleTickerProviderStateMixin {
  final _api = HabitApiService.instance;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _recap;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _loadRecap();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadRecap() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _api.getMonthlyRecap(widget.year, widget.month);
      setState(() => _recap = data);
      _animController.forward();
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Badge helpers ──────────────────────────────────────────────────────────

  _BadgeData _getBadge(int rate) {
    if (rate >= 80) {
      return _BadgeData(
        emoji: '🏆', label: 'Excellent Month!',
        subtitle: 'You crushed it. Top performance!',
        gradient: const [Color(0xFFFFD700), Color(0xFFFFA500)],
        glow: const Color(0xFFFFD700),
      );
    } else if (rate >= 50) {
      return _BadgeData(
        emoji: '🔥', label: 'Good Work!',
        subtitle: 'Solid consistency. Keep the fire going!',
        gradient: const [Color(0xFFFF512F), Color(0xFFDD2476)],
        glow: const Color(0xFFFF512F),
      );
    } else {
      return _BadgeData(
        emoji: '💪', label: 'Keep Going!',
        subtitle: "Every day is a new chance. You've got this!",
        gradient: const [Color(0xFF00B4DB), Color(0xFF0072FF)],
        glow: const Color(0xFF00B4DB),
      );
    }
  }

  Color _getRateColor(int rate) {
    if (rate >= 80) return const Color(0xFF00E676);
    if (rate >= 50) return const Color(0xFFFFA726);
    return const Color(0xFFFF5252);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFDA22FF)))
          : _error != null
              ? _buildErrorView()
              : FadeTransition(opacity: _fadeAnim, child: _buildRecapView()),
    );
  }

  // ── Error View ─────────────────────────────────────────────────────────────

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics_outlined,
                color: Color(0xFF8A8F9E), size: 64),
            const SizedBox(height: 24),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadRecap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDA22FF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recap View ─────────────────────────────────────────────────────────────

  Widget _buildRecapView() {
    final totalRate       = (_recap?['totalCompletionRate'] as num?)?.toInt() ?? 0;
    final totalCompletions = (_recap?['completedDaysCount'] as num?)?.toInt() ?? 0;
    final habitSummaries  = (_recap?['habitSummaries'] as List<dynamic>?) ?? [];
    final aiInsight       = _recap?['aiInsight'] as String? ?? '';
    final bestHabit       = _recap?['bestHabit'] as String?;
    final worstHabit      = _recap?['worstHabit'] as String?;
    final prevRate        = (_recap?['previousMonthRate'] as num?)?.toInt();
    final badge           = _getBadge(totalRate);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── 1. Score Card ────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFDA22FF), Color(0xFF9733EE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDA22FF).withOpacity(0.35),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 130, width: 130,
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
                        Text('$totalRate%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                height: 1)),
                        const SizedBox(height: 4),
                        const Text('Success',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text('$totalCompletions completions this month',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 2. Badge ─────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: badge.gradient
                    .map((c) => c.withOpacity(0.15))
                    .toList(),
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: badge.gradient.first.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                    color: badge.glow.withOpacity(0.15), blurRadius: 20, spreadRadius: 2),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: badge.gradient),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: badge.glow.withOpacity(0.4), blurRadius: 12),
                    ],
                  ),
                  child: Center(
                    child: Text(badge.emoji,
                        style: const TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(badge.label,
                          style: TextStyle(
                              color: badge.gradient.first,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(badge.subtitle,
                          style: const TextStyle(
                              color: Color(0xFF8A8F9E),
                              fontSize: 13,
                              height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── 3. Month-over-Month Delta ─────────────────────────────────
          if (prevRate != null) ...[
            _buildDeltaCard(totalRate, prevRate),
            const SizedBox(height: 24),
          ],

          // ── 4. Best & Worst Highlights ────────────────────────────────
          if (bestHabit != null || worstHabit != null)
            ..._buildHighlights(bestHabit, worstHabit),

          // ── 5. Habit Performance ──────────────────────────────────────
          const Text('Habit Performance',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...habitSummaries.map((s) => _buildHabitCard(s)).toList(),

          // ── 6. AI Insight ─────────────────────────────────────────────
          if (aiInsight.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Coach Insights',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF161A22),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: const Color(0xFFDA22FF).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          color: Color(0xFFDA22FF), size: 18),
                      const SizedBox(width: 10),
                      Text('AI ANALYSIS',
                          style: TextStyle(
                              color: const Color(0xFFDA22FF).withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(aiInsight,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.65,
                          fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Habit Card ─────────────────────────────────────────────────────────────

  Widget _buildHabitCard(Map<String, dynamic> summary) {
    final title      = summary['title'] as String? ?? 'Habit';
    final rate       = (summary['completionRate'] as num?)?.toInt() ?? 0;
    final bestStreak = (summary['bestStreak'] as num?)?.toInt() ?? 0;
    final color      = _getRateColor(rate);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ),
              Text('$rate%',
                  style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: rate / 100,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.local_fire_department,
                  color: Color(0xFFFFA726), size: 15),
              const SizedBox(width: 5),
              Text(
                'Best streak: $bestStreak day${bestStreak == 1 ? '' : 's'}',
                style: const TextStyle(
                    color: Color(0xFF8A8F9E), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Delta Card ─────────────────────────────────────────────────────────────

  Widget _buildDeltaCard(int current, int previous) {
    final delta = current - previous;
    final isUp  = delta >= 0;
    final color = isUp ? const Color(0xFF00E676) : const Color(0xFFFF5252);
    final icon  = isUp ? Icons.trending_up : Icons.trending_down;
    final sign  = isUp ? '+' : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('vs Last Month',
                    style: TextStyle(
                        color: color.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text('$sign$delta% compared to $previous% last month',
                    style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
          Text('$sign$delta%',
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── Highlights (Best / Worst) ──────────────────────────────────────────────

  List<Widget> _buildHighlights(String? best, String? worst) {
    return [
      const Text('Highlights',
          style: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      Row(
        children: [
          if (best != null)
            Expanded(
              child: _buildHighlightTile(
                emoji: '⭐', label: 'Star Habit', name: best,
                color: const Color(0xFF00E676),
              ),
            ),
          if (best != null && worst != null) const SizedBox(width: 12),
          if (worst != null)
            Expanded(
              child: _buildHighlightTile(
                emoji: '🎯', label: 'Needs Work', name: worst,
                color: const Color(0xFFFF5252),
              ),
            ),
        ],
      ),
      const SizedBox(height: 24),
    ];
  }

  Widget _buildHighlightTile({
    required String emoji,
    required String label,
    required String name,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1)),
          const SizedBox(height: 4),
          Text(name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Badge data model ───────────────────────────────────────────────────────────

class _BadgeData {
  final String emoji;
  final String label;
  final String subtitle;
  final List<Color> gradient;
  final Color glow;

  const _BadgeData({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.glow,
  });
}
