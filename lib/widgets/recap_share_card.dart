import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// ─────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────

class MonthlyRecapData {
  final String monthName;   // e.g. "MAY 2026"
  final int successRate;    // 0–100
  final int totalCompleted;
  final String starHabit;
  final int bestStreak;
  final String badgeLabel;  // e.g. "On Fire", "Getting There", "Champion"

  const MonthlyRecapData({
    required this.monthName,
    required this.successRate,
    required this.totalCompleted,
    required this.starHabit,
    required this.bestStreak,
    required this.badgeLabel,
  });
}

// ─────────────────────────────────────────────
// COLORS
// ─────────────────────────────────────────────

class _RecapColors {
  static const background   = Color(0xFF0D0D18);
  static const card         = Color(0xFF13131F);
  static const surface      = Color(0xFF1A1A2E);
  static const border       = Color(0x12FFFFFF);
  static const accent       = Color(0xFFE85D3A);
  static const accentSoft   = Color(0x26E85D3A);
  static const accentBorder = Color(0x66E85D3A);
  static const white        = Color(0xFFFFFFFF);
  static const white60      = Color(0x99FFFFFF);
  static const white30      = Color(0x4DFFFFFF);
  static const white15      = Color(0x26FFFFFF);
  static const white08      = Color(0x14FFFFFF);
}

// ─────────────────────────────────────────────
// MAIN CARD WIDGET (shareable)
// ─────────────────────────────────────────────

class RecapShareCard extends StatelessWidget {
  final MonthlyRecapData data;

  const RecapShareCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      decoration: BoxDecoration(
        color: _RecapColors.background,
        borderRadius: BorderRadius.circular(32),
      ),
      padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildHeroRate(),
          const SizedBox(height: 28),
          _buildDivider(),
          const SizedBox(height: 20),
          _buildStatsRow(),
          const SizedBox(height: 12),
          _buildStreakBar(),
          const SizedBox(height: 20),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FLOW',
          style: TextStyle(
            color: _RecapColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 4,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'MONTHLY',
              style: TextStyle(
                color: _RecapColors.white30,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            Text(
              'RECAP',
              style: TextStyle(
                color: _RecapColors.white30,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroRate() {
    return Center(
      child: Column(
        children: [
          Text(
            'SUCCESS RATE',
            style: TextStyle(
              color: _RecapColors.white30,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.center,
            children: [
              // Glow
              Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _RecapColors.accent.withOpacity(0.15),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
              // Ring
              SizedBox(
                width: 160,
                height: 160,
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: data.successRate / 100,
                    trackColor: _RecapColors.white08,
                    progressColor: _RecapColors.accent,
                    strokeWidth: 10,
                  ),
                ),
              ),
              // Number
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${data.successRate}',
                          style: const TextStyle(
                            color: _RecapColors.white,
                            fontSize: 64,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -3,
                            height: 1,
                          ),
                        ),
                        TextSpan(
                          text: '%',
                          style: TextStyle(
                            color: _RecapColors.white60,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.monthName,
                    style: TextStyle(
                      color: _RecapColors.white30,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 0.5,
      color: _RecapColors.white08,
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            label: 'COMPLETED',
            value: '${data.totalCompleted}',
            sub: 'habits done',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            label: 'STAR HABIT',
            value: data.starHabit,
            sub: 'most consistent',
            valueFontSize: data.starHabit.length > 8 ? 14 : 18,
          ),
        ),
      ],
    );
  }

  Widget _buildStreakBar() {
    final dots = min(data.bestStreak, 6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _RecapColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _RecapColors.border, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BEST STREAK',
                style: TextStyle(
                  color: _RecapColors.white30,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${data.bestStreak} days',
                style: const TextStyle(
                  color: _RecapColors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          Row(
            children: List.generate(6, (i) {
              final active = i < dots;
              final opacity = active ? (i == dots - 1 ? 0.6 : 1.0) : 0.15;
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _RecapColors.accent.withOpacity(opacity),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _RecapColors.accentSoft,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _RecapColors.accentBorder, width: 0.5),
          ),
          child: Text(
            data.badgeLabel,
            style: const TextStyle(
              color: _RecapColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Text(
          'flowtracks.app',
          style: TextStyle(
            color: _RecapColors.white15,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// STAT BOX
// ─────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final double valueFontSize;

  const _StatBox({
    required this.label,
    required this.value,
    required this.sub,
    this.valueFontSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _RecapColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _RecapColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _RecapColors.white30,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: _RecapColors.white,
              fontSize: valueFontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            sub,
            style: TextStyle(
              color: _RecapColors.white30,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// RING PAINTER
// ─────────────────────────────────────────────

class _RingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  const _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    canvas.drawArc(
      rect,
      0,
      2 * pi,
      false,
      Paint()
        ..color = trackColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke,
    );

    // Progress
    final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);
    final gradient = SweepGradient(
      startAngle: -pi / 2,
      endAngle: -pi / 2 + 2 * pi,
      colors: [progressColor, progressColor.withOpacity(0.6)],
      tileMode: TileMode.clamp,
    );

    canvas.drawArc(
      rect,
      -pi / 2,
      sweepAngle,
      false,
      Paint()
        ..shader = gradient.createShader(rect)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.progressColor != progressColor;
}

// ─────────────────────────────────────────────
// SCREEN WITH SHARE BUTTON
// ─────────────────────────────────────────────

class MonthlyRecapScreen extends StatefulWidget {
  final MonthlyRecapData data;

  const MonthlyRecapScreen({super.key, required this.data});

  @override
  State<MonthlyRecapScreen> createState() => _MonthlyRecapScreenState();
}

class _MonthlyRecapScreenState extends State<MonthlyRecapScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _sharing = false;

  Future<void> _shareCard() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      final boundary = _repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;

      // Render at 3× for crispy Stories quality
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/flow_recap_${widget.data.monthName.replaceAll(' ', '_')}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My ${widget.data.monthName} recap on @flowhabits 🔥\n#habittracker #flow',
      );
    } catch (e) {
      debugPrint('Share error: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Monthly Recap',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: RecapShareCard(data: widget.data),
                ),
              ),
            ),
          ),

          // Share button
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _sharing ? null : _shareCard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE85D3A),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0x80E85D3A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _sharing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.ios_share_rounded, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Share to Stories',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// USAGE EXAMPLE
// ─────────────────────────────────────────────
//
// Navigator.push(context, MaterialPageRoute(
//   builder: (_) => MonthlyRecapScreen(
//     data: MonthlyRecapData(
//       monthName: 'MAY 2026',
//       successRate: 84,
//       totalCompleted: 109,
//       starHabit: 'Morning Yoga',
//       bestStreak: 42,
//       badgeLabel: 'On Fire 🔥',
//     ),
//   ),
// ));
//
// pubspec.yaml dependencies:
//   share_plus: ^9.0.0
//   path_provider: ^2.1.0