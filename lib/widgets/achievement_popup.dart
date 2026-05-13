import 'package:flutter/material.dart';

class AchievementPopup extends StatefulWidget {
  final String title;
  final String body;

  const AchievementPopup({super.key, required this.title, required this.body});

  static void show(BuildContext context, String title, String body) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Achievement',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return AchievementPopup(title: title, body: body);
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: child,
        );
      },
    );
  }

  @override
  State<AchievementPopup> createState() => _AchievementPopupState();
}

class _AchievementPopupState extends State<AchievementPopup> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF161A22),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFDA22FF).withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFDA22FF).withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 5,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glow effect behind the icon
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFDA22FF), Color(0xFF9733EE)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFDA22FF).withOpacity(0.5 * _glowAnimation.value),
                        blurRadius: 30 * _glowAnimation.value,
                        spreadRadius: 10 * _glowAnimation.value,
                      )
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.emoji_events, color: Colors.white, size: 60),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF8A8F9E),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFDA22FF), width: 1.5),
                  ),
                ),
                child: const Text('Awesome!', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
