import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api/habit_api_service.dart';
import '../../models/habit_template.dart';
import 'ai_generator_screen.dart';
import '../paywall/paywall_screen.dart';
import '../main_screen.dart';

// ── Zen palette (always dark regardless of system theme) ──────────────────────
import '../../theme/app_theme.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen>
    with TickerProviderStateMixin {
  bool _isPro = false;
  int _remaining = 0;
  int _totalLimit = 0;
  bool _isLoading = true;
  String _searchQuery = '';

  late final AnimationController _glowController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _loadProStatus();
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _handleSuccess() {
    if (!mounted) return;
    final routeName = ModalRoute.of(context)?.settings.name;
    if (routeName == '/templates') {
      Navigator.of(context).pop(true);
    } else {
      final mainState = context.findAncestorStateOfType<MainScreenState>();
      if (mainState != null) {
        mainState.setTab(0, habitCreated: true);
      }
    }
  }

  Future<void> _loadProStatus() async {
    try {
      final stats = await HabitApiService.instance.getGlobalStats();
      if (mounted) {
        setState(() {
          _isPro = stats['isPro'] as bool? ?? false;
          _remaining = (stats['aiGenerationsRemaining'] ??
                  stats['AiGenerationsRemaining']) as int? ?? 0;
          _totalLimit = (stats['aiTotalLimit'] ??
                  stats['AiTotalLimit']) as int? ??
              (_isPro ? 5 : 2);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<HabitTemplateCategory> get _filtered {
    if (_searchQuery.isEmpty) return defaultTemplateCategories;
    final q = _searchQuery.toLowerCase();
    return defaultTemplateCategories
        .map((cat) {
          final ts = cat.templates
              .where((t) =>
                  t.title.toLowerCase().contains(q) ||
                  t.description.toLowerCase().contains(q) ||
                  cat.name.toLowerCase().contains(q))
              .toList();
          return ts.isEmpty ? null : HabitTemplateCategory(
            name: cat.name,
            icon: cat.icon,
            color: cat.color,
            templates: ts,
          );
        })
        .whereType<HabitTemplateCategory>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ────────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back_ios_new,
                          color: context.colors.textPrimary, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Library',
                            style: GoogleFonts.playfairDisplay(
                              color: context.colors.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Build your practice',
                            style: TextStyle(
                              color: context.colors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Search bar ────────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.colors.card,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: TextField(
                    style:
                        TextStyle(color: context.colors.textPrimary, fontSize: 14),
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search habits & templates...',
                      hintStyle:
                          TextStyle(color: context.colors.textSecondary, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: context.colors.textSecondary, size: 20),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 0, vertical: 14),
                    ),
                  ),
                ),
              ),
            ),

            // ── Two action Bento cards ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // AI card – large, glowing
                    Expanded(
                      flex: 6,
                      child: _AiCard(
                        isPro: _isPro,
                        remaining: _remaining,
                        totalLimit: _totalLimit,
                        isLoading: _isLoading,
                        glowAnim: _glowController,
                        onTap: () async {
                          if (!_isPro && _remaining <= 0) {
                            final ok = await Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const PaywallScreen()),
                            );
                            if (ok == true) _loadProStatus();
                            return;
                          }
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const AiGeneratorScreen()),
                          );
                          if (result == true && context.mounted) {
                            _handleSuccess();
                          } else if (context.mounted) {
                            _loadProStatus();
                          }
                        },
                      ),
                    ),
                    SizedBox(width: 12),
                    // Scratch card – smaller, clean
                    Expanded(
                      flex: 4,
                      child: _ScratchCard(
                        onTap: () async {
                          final result = await Navigator.of(context)
                              .pushNamed('/add_habit');
                          if (result == true && context.mounted) {
                            _handleSuccess();
                          } else if (context.mounted) {
                            _loadProStatus();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // ── Section title ─────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Browse by category',
                      style: GoogleFonts.playfairDisplay(
                        color: context.colors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'See all',
                      style: TextStyle(
                          color: context.colors.sage,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Category grid ─────────────────────────────────────────────────
            if (filtered.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
                  child: Column(
                    children: [
                      Icon(Icons.search_off_rounded,
                          color: context.colors.textSecondary, size: 48),
                      SizedBox(height: 16),
                      Text(
                        'No templates found',
                        style: GoogleFonts.playfairDisplay(
                          color: context.colors.textSecondary,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _CategoryCard(
                      category: filtered[i],
                      onTap: () => _showCategorySheet(context, filtered[i]),
                    ),
                    childCount: filtered.length,
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 60)),
          ],
        ),
      ),
    );
  }

  void _showCategorySheet(BuildContext ctx, HabitTemplateCategory cat) async {
    final result = await showModalBottomSheet<bool>(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CategorySheet(category: cat),
    );
    if (result == true) {
      _handleSuccess();
    }
  }
}

// ── AI Card ──────────────────────────────────────────────────────────────────
class _AiCard extends StatelessWidget {
  final bool isPro;
  final int remaining;
  final int totalLimit;
  final bool isLoading;
  final Animation<double> glowAnim;
  final VoidCallback onTap;

  const _AiCard({
    required this.isPro,
    required this.remaining,
    required this.totalLimit,
    required this.isLoading,
    required this.glowAnim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: glowAnim,
        builder: (_, child) => Container(
          height: 200,
          decoration: BoxDecoration(
            color: context.colors.cardSecondary,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: context.colors.terracotta.withOpacity(0.25 + 0.15 * glowAnim.value),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: context.colors.terracotta.withOpacity(0.15 * glowAnim.value),
                blurRadius: 24,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: context.colors.lavender.withOpacity(0.08 * glowAnim.value),
                blurRadius: 32,
                spreadRadius: 8,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Glow blob top-right
                Positioned(
                  right: -20,
                  top: -20,
                  child: AnimatedBuilder(
                    animation: glowAnim,
                    builder: (_, __) => Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          context.colors.terracotta.withOpacity(0.25 * glowAnim.value),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                ),
                // Glow blob bottom-left
                Positioned(
                  left: -10,
                  bottom: -10,
                  child: AnimatedBuilder(
                    animation: glowAnim,
                    builder: (_, __) => Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          context.colors.lavender.withOpacity(0.18 * glowAnim.value),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.colors.sage.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: context.colors.sage.withOpacity(0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: context.colors.sage,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 6),
                            Text(
                              'AI Powered',
                              style: TextStyle(
                                color: context.colors.sage,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Generate\nwith AI',
                        style: GoogleFonts.playfairDisplay(
                          color: context.colors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Personalized just for you',
                        style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                      ),
                      SizedBox(height: 14),
                      Row(
                        children: [
                          // Generation counter pill
                          if (!isLoading)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: (remaining > 0
                                        ? context.colors.sage
                                        : context.colors.terracotta)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: (remaining > 0
                                          ? context.colors.sage
                                          : context.colors.terracotta)
                                      .withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                '$remaining/$totalLimit',
                                style: TextStyle(
                                  color: remaining > 0
                                      ? context.colors.sage
                                      : context.colors.terracotta,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const Spacer(),
                          // Arrow circle
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.colors.terracotta.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: context.colors.terracotta.withOpacity(0.35), width: 1),
                            ),
                            child: Icon(Icons.arrow_forward_rounded,
                                color: context.colors.terracotta, size: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Scratch Card ─────────────────────────────────────────────────────────────
class _ScratchCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ScratchCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.colors.border),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colors.lavender.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: context.colors.lavender.withOpacity(0.2), width: 1),
              ),
              child: Icon(Icons.add_rounded,
                  color: context.colors.lavender, size: 20),
            ),
            const Spacer(),
            Text(
              'Start\nfresh',
              style: GoogleFonts.playfairDisplay(
                color: context.colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Blank canvas',
              style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category Grid Card ────────────────────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  final HabitTemplateCategory category;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.colors.border),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon box
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: category.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: category.color.withOpacity(0.2), width: 1),
              ),
              child: Icon(category.icon, color: category.color, size: 22),
            ),
            const Spacer(),
            Text(
              category.name,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${category.templates.length} templates',
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                ),
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    color: context.colors.textSecondary, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category Bottom Sheet ─────────────────────────────────────────────────────
class _CategorySheet extends StatelessWidget {
  final HabitTemplateCategory category;
  const _CategorySheet({required this.category});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.93,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: context.colors.cardSecondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 0),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Sheet header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: category.color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(category.icon,
                        color: category.color, size: 22),
                  ),
                  SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: GoogleFonts.playfairDisplay(
                          color: context.colors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${category.templates.length} templates',
                        style: TextStyle(
                            color: context.colors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(color: context.colors.border, height: 1),
            // Template list
            Expanded(
              child: ListView.separated(
                controller: ctrl,
                padding: const EdgeInsets.all(16),
                itemCount: category.templates.length,
                separatorBuilder: (_, __) => SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final t = category.templates[i];
                  return GestureDetector(
                    onTap: () async {
                      final result = await Navigator.of(ctx).pushNamed(
                        '/add_habit',
                        arguments: t,
                      );
                      if (result == true && ctx.mounted) {
                        Navigator.of(ctx).pop(true);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: context.colors.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: category.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(t.icon,
                                color: category.color, size: 22),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.title,
                                  style: TextStyle(
                                    color: context.colors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  t.description,
                                  style: TextStyle(
                                      color: context.colors.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.colors.sage.withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: context.colors.sage.withOpacity(0.25)),
                            ),
                            child: Icon(Icons.add_rounded,
                                color: context.colors.sage, size: 16),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
