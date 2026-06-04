import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  // Colors based on premium palette
  final Color bgDark = const Color(0xFF1A1A1A); // Matte charcoal-dark
  
  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -15, end: 15).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      emoji: '🌱',
      title: 'The Welcome',
      subtitle: 'Find your flow state',
      description:
          'A minimalist anti-anxiety habit tracker designed to help you build powerful routines without the pressure.',
      gradientColors: [const Color(0xFFC4B5E3), const Color(0xFF9CAFA3)], // Soft lavender to sage green
      accentColor: const Color(0xFFC4B5E3),
    ),
    _OnboardingPage(
      emoji: '🧠',
      title: 'Your AI Guide',
      subtitle: 'Personalized bento insights',
      description:
          'Chat with our conversational wizard and get brutally honest, tailored coaching to optimize your dynamic routine.',
      gradientColors: [const Color(0xFF9CAFA3), const Color(0xFF7A8B7E)], // Sage green
      accentColor: const Color(0xFF9CAFA3),
    ),
    _OnboardingPage(
      emoji: '🌿',
      title: 'No Pressure Stats',
      subtitle: 'Forgiving analytics',
      description:
          'Watch your progress with a forgiving dashboard that celebrates consistency over perfection.',
      gradientColors: [const Color(0xFFE07A5F), const Color(0xFFC96B42)], // Earthy terracotta
      accentColor: const Color(0xFFE07A5F),
    ),
    _OnboardingPage(
      emoji: '🤝',
      title: 'Empathetic Friends',
      subtitle: 'Supportive social circle',
      description:
          'Share your journey with status tags and build healthy life routines together with people who understand.',
      gradientColors: [const Color(0xFFC4B5E3), const Color(0xFFE07A5F)], // Lavender to terracotta
      accentColor: const Color(0xFFC4B5E3),
    ),
    _OnboardingPage(
      emoji: '📱',
      title: 'Interactive Widgets',
      subtitle: 'Seamless tracking',
      description:
          'Stay connected to your goals with elegant widgets right on your smartphone home screen.',
      gradientColors: [const Color(0xFF9CAFA3), const Color(0xFFC4B5E3)], // Sage green to lavender
      accentColor: const Color(0xFF9CAFA3),
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarded', true);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];

    return Scaffold(
      backgroundColor: bgDark,
      body: Stack(
        children: [
          // Animated ambient glow (breathing organic glow)
          AnimatedBuilder(
            animation: _floatController,
            builder: (_, __) => Positioned(
              top: -100 + _floatAnimation.value,
              right: -50,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      page.accentColor.withOpacity(0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _floatController,
            builder: (_, __) => Positioned(
              bottom: 50 - _floatAnimation.value,
              left: -80,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      page.accentColor.withOpacity(0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Skip button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withOpacity(0.5),
                        textStyle: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      child: const Text('Skip'),
                    ),
                  ),
                ),

                // Page view
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) =>
                        _PageContent(page: _pages[index], floatAnimation: _floatAnimation),
                  ),
                ),

                // Bottom section
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                  child: Column(
                    children: [
                      // Dots indicator
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (i) {
                          final isActive = i == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 32 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: isActive
                                  ? page.accentColor
                                  : Colors.white.withOpacity(0.15),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 40),

                      // Next / Step into Flow button
                      Container(
                        width: double.infinity,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: page.gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: page.accentColor.withOpacity(0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _nextPage,
                            borderRadius: BorderRadius.circular(32),
                            splashColor: Colors.white.withOpacity(0.2),
                            highlightColor: Colors.white.withOpacity(0.1),
                            child: Container(
                              alignment: Alignment.center,
                              child: Text(
                                _currentPage == _pages.length - 1
                                    ? "Step into Flow ✨"
                                    : 'Continue',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF1A1A1A), // Dark text on light button for premium feel
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (_currentPage == _pages.length - 1) ...[
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: () =>
                              Navigator.of(context).pushReplacementNamed('/login'),
                          child: Text(
                            'Already have an account? Sign in',
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  final _OnboardingPage page;
  final Animation<double> floatAnimation;

  const _PageContent({required this.page, required this.floatAnimation});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Floating Glassmorphism card for emoji
          AnimatedBuilder(
            animation: floatAnimation,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, floatAnimation.value * 0.8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40), // Ultra rounded
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: page.accentColor.withOpacity(0.15),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        page.emoji,
                        style: const TextStyle(fontSize: 70),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 56),

          // Title (Sophisticated serif)
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          
          // Subtitle
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: page.accentColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 24),

          // Description (Clean sans-serif)
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.6),
              fontSize: 16,
              height: 1.6,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final String emoji;
  final String title;
  final String subtitle;
  final String description;
  final List<Color> gradientColors;
  final Color accentColor;

  const _OnboardingPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.gradientColors,
    required this.accentColor,
  });
}
