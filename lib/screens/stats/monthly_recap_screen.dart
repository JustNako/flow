import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../api/habit_api_service.dart';
import '../../services/share_service.dart';
import '../../widgets/recap_share_card.dart';

class MonthlyRecapScreen extends StatefulWidget {
  final int year;
  final int month;

  const MonthlyRecapScreen({super.key, required this.year, required this.month});

  @override
  State<MonthlyRecapScreen> createState() => _MonthlyRecapScreenState();
}

class _MonthlyRecapScreenState extends State<MonthlyRecapScreen> with TickerProviderStateMixin {
  final _api = HabitApiService.instance;
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _recap;

  // Stories navigation
  final int _totalSlides = 6;
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _progressController;

  // Extracted Data
  late int _totalRate;
  late int _bestStreak;
  late String _bestHabit;
  late String _monthName;
  late String _archetypeTitle;
  late String _archetypeDesc;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    
    _pageController = PageController();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextSlide();
      }
    });

    _loadRecap();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _loadRecap() async {
    try {
      final data = await _api.getMonthlyRecap(widget.year, widget.month);
      
      _totalRate = (data['totalCompletionRate'] as num?)?.toInt() ?? 0;
      _monthName = data['monthName']?.toString().toUpperCase() ?? 'MONTHLY RECAP';
      _bestHabit = data['bestHabit'] as String? ?? 'Showing Up';
      
      final summaries = (data['habitSummaries'] as List<dynamic>? ?? []);
      _bestStreak = summaries.fold<int>(0, (prev, s) {
        final v = ((s as Map<String, dynamic>)['bestStreak'] as num?)?.toInt() ?? 0;
        return v > prev ? v : prev;
      });

      _determineArchetype();

      setState(() {
        _recap = data;
        _isLoading = false;
      });

      _progressController.forward();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _determineArchetype() {
    if (_totalRate >= 85) {
      _archetypeTitle = 'DISCIPLINE MACHINE';
      _archetypeDesc = 'You kept showing up even on difficult days.';
    } else if (_totalRate >= 60 && _bestStreak > 10) {
      _archetypeTitle = 'MOMENTUM BUILDER';
      _archetypeDesc = 'You know how to keep a chain going.';
    } else if (_totalRate >= 40) {
      _archetypeTitle = 'THE CONSISTENT ONE';
      _archetypeDesc = 'Slow and steady wins the race.';
    } else {
      _archetypeTitle = 'COMEBACK HERO';
      _archetypeDesc = 'Every great journey starts with a single step.';
    }
  }

  void _nextSlide() {
    if (_currentIndex < _totalSlides - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // Stay on last slide, just fill progress
    }
  }

  void _prevSlide() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onTapDown(TapDownDetails details) {
    if (_isLoading || _error != null) return;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final tapPosition = details.globalPosition.dx;

    if (tapPosition < screenWidth / 3) {
      _prevSlide();
    } else {
      _nextSlide();
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    _progressController.reset();
    if (index < _totalSlides - 1) {
      _progressController.forward();
    } else {
      // Last slide doesn't auto-advance
      _progressController.value = 1.0;
    }
  }

  Future<void> _showShareMenu() async {
    _progressController.stop();

    try {
      final link = await _api.shareMonthlyRecap(
        year: widget.year,
        month: widget.month,
        totalRate: _totalRate,
        bestStreak: _bestStreak,
        bestHabit: _bestHabit,
        archetypeTitle: _archetypeTitle,
        archetypeDesc: _archetypeDesc,
      );

      await Share.share(
        "I crushed my habits this month! See my interactive recap: $link",
        subject: "My $_monthName Recap",
      );
    } catch (e) {
      debugPrint('Share failed: $e');
    } finally {
      if (_currentIndex < _totalSlides - 1) {
        _progressController.forward();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF07070F),
        body: Center(
          child: CircularProgressIndicator(color: const Color(0xFFE85D3A)),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF07070F),
        body: Center(
          child: Text('Failed to load recap\n$_error', style: const TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF07070F),
      body: GestureDetector(
        onTapDown: _onTapDown,
        onLongPressDown: (_) => _progressController.stop(),
        onLongPressUp: () {
          if (_currentIndex < _totalSlides - 1) _progressController.forward();
        },
        child: Stack(
          children: [
            // Slides
            PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const ClampingScrollPhysics(),
              children: [
                _Slide1Intro(monthName: _monthName),
                _Slide2SuccessRate(rate: _totalRate),
                _Slide3Streak(streak: _bestStreak),
                _Slide4BestHabit(habit: _bestHabit),
                _Slide5Personality(title: _archetypeTitle, desc: _archetypeDesc),
                _Slide6Ending(onShareTap: _showShareMenu),
              ],
            ),

            // Top Progress Bars
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Row(
                children: List.generate(_totalSlides, (index) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, child) {
                          double progress = 0.0;
                          if (index < _currentIndex) {
                            progress = 1.0;
                          } else if (index == _currentIndex) {
                            progress = _progressController.value;
                          }
                          return Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: progress,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(1.5),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Close Button
            Positioned(
              top: MediaQuery.of(context).padding.top + 32,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIDE 1: INTRO (Deep purple/midnight, floating orbs)
// ─────────────────────────────────────────────────────────────────────────────
class _Slide1Intro extends StatefulWidget {
  final String monthName;
  const _Slide1Intro({required this.monthName});

  @override
  State<_Slide1Intro> createState() => _Slide1IntroState();
}

class _Slide1IntroState extends State<_Slide1Intro> with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
  }
  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background
        Container(color: const Color(0xFF090514)),
        
        // Floating Orbs
        AnimatedBuilder(
          animation: _anim,
          builder: (context, child) {
            return Stack(
              children: [
                Positioned(
                  top: -100 + (_anim.value * 50),
                  left: -50 - (_anim.value * 30),
                  child: _buildOrb(const Color(0xFF6B21A8), 400),
                ),
                Positioned(
                  bottom: -150 - (_anim.value * 40),
                  right: -100 + (_anim.value * 60),
                  child: _buildOrb(const Color(0xFF312E81), 500),
                ),
              ],
            );
          },
        ),
        
        // Content
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(seconds: 2),
            curve: Curves.easeOutCubic,
            builder: (context, val, child) {
              return Transform.translate(
                offset: Offset(0, 40 * (1 - val)),
                child: Opacity(
                  opacity: val,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'THIS MONTH\nYOU SHOWED UP',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 16, letterSpacing: 4, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        widget.monthName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrb(Color color, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.4),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIDE 2: SUCCESS RATE (Emerald glow, animated ring)
// ─────────────────────────────────────────────────────────────────────────────
class _Slide2SuccessRate extends StatelessWidget {
  final int rate;
  const _Slide2SuccessRate({required this.rate});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF021B10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Emerald glow
          Container(
            width: 300, height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: const Color(0xFF10B981).withOpacity(0.2), blurRadius: 150),
              ],
            ),
          ),
          
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: rate / 100.0),
            duration: const Duration(seconds: 3),
            curve: Curves.easeOutExpo,
            builder: (context, val, child) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 280, height: 280,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 2,
                          color: Colors.white.withOpacity(0.05),
                        ),
                        CircularProgressIndicator(
                          value: val,
                          strokeWidth: 12,
                          strokeCap: StrokeCap.round,
                          color: const Color(0xFF10B981),
                        ),
                        Center(
                          child: Text(
                            '${(val * 100).toInt()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 72,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 64),
                  Opacity(
                    opacity: val > 0.1 ? 1.0 : 0.0,
                    child: const Text(
                      'SUCCESS RATE',
                      style: TextStyle(
                        color: Color(0xFF34D399),
                        fontSize: 20,
                        letterSpacing: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIDE 3: STREAK (Amber, fiery, ember particles)
// ─────────────────────────────────────────────────────────────────────────────
class _Slide3Streak extends StatefulWidget {
  final int streak;
  const _Slide3Streak({required this.streak});

  @override
  State<_Slide3Streak> createState() => _Slide3StreakState();
}

class _Slide3StreakState extends State<_Slide3Streak> with SingleTickerProviderStateMixin {
  late AnimationController _particlesController;

  @override
  void initState() {
    super.initState();
    _particlesController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _particlesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1F0900),
      child: Stack(
        children: [
          // Fiery Backdrop Glow
          Center(
            child: Container(
              width: double.infinity,
              height: 400,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [const Color(0xFFF97316).withOpacity(0.3), Colors.transparent],
                  radius: 0.8,
                ),
              ),
            ),
          ),
          
          // Particles
          AnimatedBuilder(
            animation: _particlesController,
            builder: (context, child) {
              return CustomPaint(
                painter: _EmbersPainter(progress: _particlesController.value),
                size: Size.infinite,
              );
            },
          ),

          // Content
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: widget.streak.toDouble()),
              duration: const Duration(seconds: 3),
              curve: Curves.easeOutExpo,
              builder: (context, val, child) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      val.toInt().toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 140,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'DAYS IN A ROW',
                      style: TextStyle(
                        color: Color(0xFFFDBA74),
                        fontSize: 24,
                        letterSpacing: 6,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmbersPainter extends CustomPainter {
  final double progress;
  _EmbersPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFDBA74).withOpacity(0.6);
    final random = Random(42); // Fixed seed for consistent positions
    
    for (int i = 0; i < 40; i++) {
      final startX = random.nextDouble() * size.width;
      final startY = size.height + random.nextDouble() * 200;
      final speed = 0.5 + random.nextDouble();
      
      double currentY = startY - (progress * size.height * speed * 2);
      if (currentY < -50) currentY += size.height + 100;
      
      final currentX = startX + sin(progress * pi * 4 + i) * 20;
      final radius = 1.0 + random.nextDouble() * 3;
      
      canvas.drawCircle(Offset(currentX, currentY), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_EmbersPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIDE 4: STAR HABIT (Spotlight, Shimmer sweep)
// ─────────────────────────────────────────────────────────────────────────────
class _Slide4BestHabit extends StatefulWidget {
  final String habit;
  const _Slide4BestHabit({required this.habit});

  @override
  State<_Slide4BestHabit> createState() => _Slide4BestHabitState();
}

class _Slide4BestHabitState extends State<_Slide4BestHabit> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
  }

  @override
  void dispose() { _shimmerCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A0A),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Spotlight effect
          Positioned(
            top: 0,
            child: Container(
              width: MediaQuery.of(context).size.width,
              height: 500,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withOpacity(0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'YOUR STAR HABIT',
                style: TextStyle(color: Colors.white54, fontSize: 16, letterSpacing: 4),
              ),
              const SizedBox(height: 32),
              AnimatedBuilder(
                animation: _shimmerCtrl,
                builder: (context, child) {
                  return ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: const [Colors.white30, Colors.white, Colors.white30],
                        stops: const [0.0, 0.5, 1.0],
                        begin: Alignment(-2.0 + (_shimmerCtrl.value * 4), 0),
                        end: Alignment(0.0 + (_shimmerCtrl.value * 4), 0),
                      ).createShader(bounds);
                    },
                    child: Text(
                      widget.habit.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: 2,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              const Text(
                'Was your strongest ritual.',
                style: TextStyle(color: Colors.white70, fontSize: 20, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIDE 5: PERSONALITY (Aurora Borealis, Typewriter)
// ─────────────────────────────────────────────────────────────────────────────
class _Slide5Personality extends StatefulWidget {
  final String title;
  final String desc;
  const _Slide5Personality({required this.title, required this.desc});

  @override
  State<_Slide5Personality> createState() => _Slide5PersonalityState();
}

class _Slide5PersonalityState extends State<_Slide5Personality> with SingleTickerProviderStateMixin {
  late AnimationController _auroraCtrl;

  @override
  void initState() {
    super.initState();
    _auroraCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() { _auroraCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF020617),
      child: Stack(
        children: [
          // Aurora Gradient
          AnimatedBuilder(
            animation: _auroraCtrl,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: -200 + (_auroraCtrl.value * 100),
                    left: -100,
                    child: _buildGlow(const Color(0xFF0EA5E9), 600),
                  ),
                  Positioned(
                    bottom: -200 - (_auroraCtrl.value * 100),
                    right: -100,
                    child: _buildGlow(const Color(0xFF8B5CF6), 700),
                  ),
                ],
              );
            },
          ),
          
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: widget.title.length.toDouble()),
              duration: const Duration(seconds: 2),
              curve: Curves.linear,
              builder: (context, val, child) {
                String revealedText = widget.title.substring(0, val.toInt());
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('YOUR ARCHETYPE', style: TextStyle(color: Colors.white54, fontSize: 14, letterSpacing: 4)),
                    const SizedBox(height: 32),
                    Text(
                      revealedText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900, height: 1.1),
                    ),
                    const SizedBox(height: 32),
                    Opacity(
                      opacity: val == widget.title.length ? 1.0 : 0.0,
                      child: Text(
                        widget.desc,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlow(Color color, double size) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.3)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Container(color: Colors.transparent),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SLIDE 6: ENDING (Radial gold, Glassmorphism CTA)
// ─────────────────────────────────────────────────────────────────────────────
class _Slide6Ending extends StatefulWidget {
  final Future<void> Function() onShareTap;
  const _Slide6Ending({required this.onShareTap});

  @override
  State<_Slide6Ending> createState() => _Slide6EndingState();
}

class _Slide6EndingState extends State<_Slide6Ending> with SingleTickerProviderStateMixin {
  bool _isSharing = false;
  bool _isSuccess = false;
  late AnimationController _bloomCtrl;

  @override
  void initState() {
    super.initState();
    _bloomCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
  }

  @override
  void dispose() {
    _bloomCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleShare() async {
    if (_isSharing || _isSuccess) return;

    setState(() => _isSharing = true);
    await widget.onShareTap();
    
    if (mounted) {
      setState(() {
        _isSharing = false;
        _isSuccess = true;
      });
      _bloomCtrl.forward(from: 0.0);

      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) {
          _bloomCtrl.reverse();
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) setState(() => _isSuccess = false);
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F0A00),
      child: Stack(
        children: [
          // Radial Gold Glow
          Center(
            child: AnimatedBuilder(
              animation: _bloomCtrl,
              builder: (context, child) {
                final bloomValue = _bloomCtrl.value;
                return Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color.lerp(const Color(0xFFEAB308).withOpacity(0.2), const Color(0xFFF59E0B).withOpacity(0.5), bloomValue)!,
                        Colors.transparent,
                      ],
                      radius: 0.8 + (bloomValue * 0.4),
                    ),
                  ),
                );
              },
            ),
          ),

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 3),
                curve: Curves.easeOut,
                builder: (context, val, child) {
                  return Opacity(
                    opacity: val,
                    child: const Text(
                      'Keep going.',
                      style: TextStyle(
                        color: Color(0xFFFEF08A),
                        fontSize: 48,
                        fontWeight: FontWeight.w300,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 2,
                      ),
                    ),
                  );
                },
              ),
              const Spacer(),
              
              // Glassmorphism Share CTA
              Padding(
                padding: const EdgeInsets.only(bottom: 80, left: 32, right: 32),
                child: GestureDetector(
                  onTap: _handleShare,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    transform: Matrix4.identity()..scale(_isSharing ? 0.95 : 1.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          height: 64,
                          decoration: BoxDecoration(
                            color: _isSuccess 
                                ? const Color(0xFFF59E0B).withOpacity(0.2) 
                                : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: _isSuccess 
                                  ? const Color(0xFFFBBF24).withOpacity(0.5) 
                                  : Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Default State
                              AnimatedOpacity(
                                opacity: (!_isSharing && !_isSuccess) ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(Icons.ios_share, color: Colors.white, size: 24),
                                    SizedBox(width: 12),
                                    Text(
                                      'SHARE YOUR RECAP',
                                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
                                    ),
                                  ],
                                ),
                              ),
                              // Loading State
                              AnimatedOpacity(
                                opacity: _isSharing ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 200),
                                child: const SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                ),
                              ),
                              // Success State
                              AnimatedOpacity(
                                opacity: _isSuccess ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 300),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: _isSuccess ? 1.0 : 0.0),
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.elasticOut,
                                  builder: (context, val, child) {
                                    return Transform.scale(
                                      scale: val,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.check_circle_outline, color: Color(0xFFFBBF24), size: 24),
                                          SizedBox(width: 12),
                                          Text(
                                            'SHARED!',
                                            style: TextStyle(color: Color(0xFFFBBF24), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
