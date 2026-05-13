import 'package:flutter/material.dart';
import '../../api/habit_api_service.dart';
import '../../models/habit_template.dart';
import 'ai_generator_screen.dart';
import '../paywall/paywall_screen.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  bool _isPro = false;
  int _remaining = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProStatus();
  }

  Future<void> _loadProStatus() async {
    try {
      final stats = await HabitApiService.instance.getGlobalStats();
      if (mounted) {
        setState(() {
          _isPro = stats['isPro'] as bool? ?? false;
          _remaining = (stats['aiGenerationsRemaining'] ?? stats['AiGenerationsRemaining']) as int? ?? 0;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1017),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Choose a Habit',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: InkWell(
                onTap: () async {
                  final result = await Navigator.of(context).pushNamed('/add_habit');
                  if (result == true && context.mounted) {
                    Navigator.of(context).pop(true);
                  } else if (context.mounted) {
                    _loadProStatus(); // Refresh when returning
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start from Scratch',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Create a fully custom habit',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white70),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: InkWell(
                onTap: () async {
                  if (!_isPro && _remaining <= 0) {
                    final purchased = await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PaywallScreen()),
                    );
                    if (purchased == true) _loadProStatus();
                    return;
                  }

                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => AiGeneratorScreen()),
                  );
                  if (result == true && context.mounted) {
                    Navigator.of(context).pop(true);
                  } else if (context.mounted) {
                    _loadProStatus(); // Refresh limit when returning
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFDA22FF), Color(0xFF9733EE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFDA22FF).withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Generate with AI ⚡',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (!_isLoading)
                                  _ProBadge(isPro: _isPro),
                              ],
                            ),
                            const SizedBox(height: 4),
                             const Text(
                               'Tell AI your goal, get a ready routine',
                               style: TextStyle(color: Colors.white70, fontSize: 14),
                             ),
                             if (!_isLoading) ...[
                               const SizedBox(height: 10),
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                 decoration: BoxDecoration(
                                   color: _isPro 
                                     ? const Color(0xFFFFD700).withOpacity(0.1) // Gold for Pro
                                     : (_remaining > 0 ? Colors.white.withOpacity(0.1) : const Color(0xFFFF5252).withOpacity(0.1)),
                                   borderRadius: BorderRadius.circular(8),
                                   border: Border.all(
                                     color: _isPro 
                                       ? const Color(0xFFFFD700).withOpacity(0.3)
                                       : (_remaining > 0 ? Colors.white.withOpacity(0.2) : const Color(0xFFFF5252).withOpacity(0.3)),
                                   ),
                                 ),
                                 child: Row(
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     Icon(
                                       _isPro ? Icons.workspace_premium : (_remaining > 0 ? Icons.flash_on : Icons.lock_clock),
                                       color: _isPro ? const Color(0xFFFFD700) : (_remaining > 0 ? Colors.white : const Color(0xFFFF5252)),
                                       size: 12,
                                     ),
                                     const SizedBox(width: 6),
                                     Text(
                                       _isPro 
                                         ? 'PRO: $_remaining DAILY LEFT'
                                         : (_remaining > 0 ? '$_remaining FREE GENERATIONS LEFT' : 'DAILY LIMIT REACHED'),
                                       style: TextStyle(
                                         color: _isPro ? const Color(0xFFFFD700) : (_remaining > 0 ? Colors.white : const Color(0xFFFF5252)),
                                         fontSize: 10,
                                         fontWeight: FontWeight.w800,
                                         letterSpacing: 0.5,
                                       ),
                                     ),
                                   ],
                                 ),
                               ),
                             ],
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white70),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Popular Templates',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final category = defaultTemplateCategories[index];
                  return _CategorySection(category: category);
                },
                childCount: defaultTemplateCategories.length,
              ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final HabitTemplateCategory category;

  const _CategorySection({required this.category});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Row(
            children: [
              Icon(category.icon, color: category.color, size: 20),
              const SizedBox(width: 8),
              Text(
                category.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: category.templates.length,
          itemBuilder: (context, index) {
            final template = category.templates[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: InkWell(
                onTap: () async {
                  final result = await Navigator.of(context).pushNamed(
                    '/add_habit',
                    arguments: template,
                  );
                  if (result == true && context.mounted) {
                    Navigator.of(context).pop(true);
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: category.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(template.icon, color: category.color, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              template.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              template.description,
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.add_circle_outline, color: Colors.white38),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _ProBadge extends StatelessWidget {
  final bool isPro;
  const _ProBadge({required this.isPro});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isPro ? '5 daily' : '2 free',
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
