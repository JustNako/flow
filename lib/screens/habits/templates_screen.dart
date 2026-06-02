import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api/habit_api_service.dart';
import '../../models/habit_template.dart';
import 'ai_generator_screen.dart';
import '../paywall/paywall_screen.dart';

// ── Zen palette (always dark regardless of system theme) ──────────────────────
const _kBg         = Color(0xFF1A1A1A);
const _kCard       = Color(0xFF242424);
const _kCardBorder = Color(0xFF2E2E2E);
const _kSage       = Color(0xFF8BA888); // sage green
const _kTerra      = Color(0xFFD68C7A); // muted terracotta
const _kLavender   = Color(0xFF9F92C6); // soft lavender
const _kText       = Color(0xFFE8E8E8);
const _kTextSub    = Color(0xFF888888);

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
      backgroundColor: _kBg,
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
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: _kText, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Library',
                            style: GoogleFonts.playfairDisplay(
                              color: _kText,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Build your practice',
                            style: TextStyle(
                              color: _kTextSub,
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
                    color: _kCard,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: _kCardBorder),
                  ),
                  child: TextField(
                    style:
                        const TextStyle(color: _kText, fontSize: 14),
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: const InputDecoration(
                      hintText: 'Search habits & templates...',
                      hintStyle:
                          TextStyle(color: _kTextSub, fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: _kTextSub, size: 20),
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
                            Navigator.of(context).pop(true);
                          } else if (context.mounted) {
                            _loadProStatus();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Scratch card – smaller, clean
                    Expanded(
                      flex: 4,
                      child: _ScratchCard(
                        onTap: () async {
                          final result = await Navigator.of(context)
                              .pushNamed('/add_habit');
                          if (result == true && context.mounted) {
                            Navigator.of(context).pop(true);
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
                        color: _kText,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'See all',
                      style: TextStyle(
                          color: _kSage,
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
                      const Icon(Icons.search_off_rounded,
                          color: _kTextSub, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'No templates found',
                        style: GoogleFonts.playfairDisplay(
                          color: _kTextSub,
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

  void _showCategorySheet(BuildContext ctx, HabitTemplateCategory cat) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CategorySheet(category: cat),
    );
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
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _kTerra.withOpacity(0.25 + 0.15 * glowAnim.value),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: _kTerra.withOpacity(0.15 * glowAnim.value),
                blurRadius: 24,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: _kLavender.withOpacity(0.08 * glowAnim.value),
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
                          _kTerra.withOpacity(0.25 * glowAnim.value),
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
                          _kLavender.withOpacity(0.18 * glowAnim.value),
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
                          color: _kSage.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _kSage.withOpacity(0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: _kSage,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'AI Powered',
                              style: TextStyle(
                                color: _kSage,
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
                          color: _kText,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Personalized just for you',
                        style: TextStyle(color: _kTextSub, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          // Generation counter pill
                          if (!isLoading)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: (remaining > 0
                                        ? _kSage
                                        : const Color(0xFFD68C7A))
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: (remaining > 0
                                          ? _kSage
                                          : const Color(0xFFD68C7A))
                                      .withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                '$remaining/$totalLimit',
                                style: TextStyle(
                                  color: remaining > 0
                                      ? _kSage
                                      : const Color(0xFFD68C7A),
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
                              color: _kTerra.withOpacity(0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: _kTerra.withOpacity(0.35), width: 1),
                            ),
                            child: const Icon(Icons.arrow_forward_rounded,
                                color: _kTerra, size: 16),
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
          color: _kCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _kCardBorder),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kLavender.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _kLavender.withOpacity(0.2), width: 1),
              ),
              child: const Icon(Icons.add_rounded,
                  color: _kLavender, size: 20),
            ),
            const Spacer(),
            Text(
              'Start\nfresh',
              style: GoogleFonts.playfairDisplay(
                color: _kText,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Blank canvas',
              style: TextStyle(color: _kTextSub, fontSize: 12),
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
          color: _kCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _kCardBorder),
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
              style: const TextStyle(
                color: _kText,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${category.templates.length} templates',
                  style: const TextStyle(color: _kTextSub, fontSize: 12),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                    color: _kTextSub, size: 16),
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
          color: const Color(0xFF1E1E1E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: _kCardBorder),
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
                  color: _kCardBorder,
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
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: GoogleFonts.playfairDisplay(
                          color: _kText,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${category.templates.length} templates',
                        style: const TextStyle(
                            color: _kTextSub, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: _kCardBorder, height: 1),
            // Template list
            Expanded(
              child: ListView.separated(
                controller: ctrl,
                padding: const EdgeInsets.all(16),
                itemCount: category.templates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final t = category.templates[i];
                  return GestureDetector(
                    onTap: () async {
                      final result = await Navigator.of(ctx).pushNamed(
                        '/add_habit',
                        arguments: t,
                      );
                      if (result == true && ctx.mounted) {
                        Navigator.of(ctx).pop();
                        Navigator.of(ctx).pop(true);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _kCardBorder),
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
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.title,
                                  style: const TextStyle(
                                    color: _kText,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  t.description,
                                  style: const TextStyle(
                                      color: _kTextSub, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _kSage.withOpacity(0.12),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: _kSage.withOpacity(0.25)),
                            ),
                            child: const Icon(Icons.add_rounded,
                                color: _kSage, size: 16),
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
