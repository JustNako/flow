import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -12, end: 12).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
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
      emoji: '⚡',
      title: 'Welcome to Flow',
      subtitle: 'The habit tracker that actually\nunderstands you',
      description:
          'Build powerful routines, track your progress, and become the best version of yourself — one habit at a time.',
      gradientColors: [Color(0xFFDA22FF), Color(0xFF9733EE)],
      accentColor: Color(0xFFDA22FF),
    ),
    _OnboardingPage(
      emoji: '🔥',
      title: 'Build Streaks.\nStay Consistent.',
      subtitle: 'Never break the chain',
      description:
          'Track your daily habits, watch your streaks grow, and unlock achievements as you reach new milestones.',
      gradientColors: [Color(0xFFFF512F), Color(0xFFDD2476)],
      accentColor: Color(0xFFFF512F),
    ),
    _OnboardingPage(
      emoji: '🤖',
      title: 'Meet Your AI Coach',
      subtitle: 'Powered by advanced AI',
      description:
          'Get brutally honest, personalized weekly insights. Your coach analyzes your patterns and tells you exactly what to improve.',
      gradientColors: [Color(0xFF00C6FF), Color(0xFF0072FF)],
      accentColor: Color(0xFF00C6FF),
    ),
    _OnboardingPage(
      emoji: '👥',
      title: 'Better Together',
      subtitle: 'Accountability changes everything',
      description:
          'Add friends, share your progress, and compete on leaderboards. Having people watch makes you 65% more likely to succeed.',
      gradientColors: [Color(0xFF00E676), Color(0xFF00BFA5)],
      accentColor: Color(0xFF00E676),
    ),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_currentPage];

    return Scaffold(
      backgroundColor: const Color(0xFF0C1017),
      body: Stack(
        children: [
          // Animated background glow
          AnimatedBuilder(
            animation: _floatController,
            builder: (_, __) => Positioned(
              top: -80 + _floatAnimation.value,
              right: -80,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      page.accentColor.withOpacity(0.25),
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
              bottom: 100 - _floatAnimation.value,
              left: -60,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      page.accentColor.withOpacity(0.15),
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
                    padding: const EdgeInsets.all(20),
                    child: TextButton(
                      onPressed: _finish,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
                            width: isActive ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: isActive
                                  ? page.accentColor
                                  : Colors.white.withOpacity(0.2),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 32),

                      // Next / Get Started button
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                            elevation: 0,
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: page.gradientColors,
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: page.accentColor.withOpacity(0.4),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              child: Text(
                                _currentPage == _pages.length - 1
                                    ? "Let's Go! 🚀"
                                    : 'Continue →',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      if (_currentPage == _pages.length - 1) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () =>
                              Navigator.of(context).pushReplacementNamed('/login'),
                          child: Text(
                            'Already have an account? Sign in',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.4),
                              fontSize: 13,
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
          // Floating emoji icon
          AnimatedBuilder(
            animation: floatAnimation,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, floatAnimation.value * 0.5),
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: page.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: page.accentColor.withOpacity(0.5),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(page.emoji,
                      style: const TextStyle(fontSize: 60)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),

          // Title
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.2,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 16,
              height: 1.65,
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
