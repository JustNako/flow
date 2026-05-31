import 'dart:async';
import 'package:flutter/material.dart';
import '../../api/api_service.dart';

class EmailPendingScreen extends StatefulWidget {
  final String email;
  const EmailPendingScreen({super.key, required this.email});

  @override
  State<EmailPendingScreen> createState() => _EmailPendingScreenState();
}

class _EmailPendingScreenState extends State<EmailPendingScreen> with SingleTickerProviderStateMixin {
  static const _cooldownSeconds = 120; // 2 minutes

  bool _isSending = false;
  int _cooldown = 0;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = _cooldownSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _cooldown--;
        if (_cooldown <= 0) t.cancel();
      });
    });
  }

  Future<void> _resend() async {
    if (_cooldown > 0 || _isSending) return;
    setState(() => _isSending = true);
    try {
      await ApiService().resendConfirmationEmail(widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Confirmation email sent! Check your inbox.'),
          backgroundColor: Color(0xFF2ECC71),
        ),
      );
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String get _cooldownLabel {
    if (_cooldown <= 0) return 'Resend Email';
    final m = _cooldown ~/ 60;
    final s = _cooldown % 60;
    return m > 0 ? 'Resend in ${m}m ${s.toString().padLeft(2, '0')}s' : 'Resend in ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1017),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // Animated envelope icon
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8845C), Color(0xFFC96B42)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE8845C).withOpacity(0.35),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('📧', style: TextStyle(fontSize: 52)),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Title
              const Text(
                'Check your inbox',
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              // Subtitle
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 15, height: 1.6),
                  children: [
                    const TextSpan(text: 'We sent a confirmation link to\n'),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    const TextSpan(text: '\n\nClick the link in the email to activate your account.'),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Resend button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: (_cooldown > 0 || _isSending) ? null : _resend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF161A22),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF161A22),
                    disabledForegroundColor: const Color(0xFF4A4F5E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: _cooldown > 0 ? const Color(0xFF262A34) : const Color(0xFFE8845C),
                        width: 1.5,
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: _isSending
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          _cooldownLabel,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Back to login
              TextButton(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false),
                child: const Text(
                  'Back to Login',
                  style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 15),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
