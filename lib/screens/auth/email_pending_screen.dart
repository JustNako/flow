import 'dart:async';
import 'package:flutter/material.dart';
import '../../api/api_service.dart';
import '../../theme/app_theme.dart';

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
    // Делаем анимацию более медленной и плавной (Zen-дыхание)
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
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

  // Кастомный мягкий SnackBar без агрессивных системных цветов
  void _showSoftSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            // Терракотовый для ошибок, Шалфейный для успеха
            color: isError ? context.colors.danger : context.colors.sage,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
        backgroundColor: context.colors.card, // Matte charcoal
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32), // Максимальное скругление
          side: BorderSide(color: context.colors.border, width: 1),
        ),
        margin: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _resend() async {
    if (_cooldown > 0 || _isSending) return;
    setState(() => _isSending = true);
    try {
      await ApiService().resendConfirmationEmail(widget.email);
      if (!mounted) return;
      _showSoftSnackbar('✨ A reminder has been sent.');
      _startCooldown();
    } catch (e) {
      if (!mounted) return;
      _showSoftSnackbar(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String get _cooldownLabel {
    if (_cooldown <= 0) return 'Send another link';
    final m = _cooldown ~/ 60;
    final s = _cooldown % 60;
    return m > 0 ? 'Wait ${m}m ${s.toString().padLeft(2, '0')}s' : 'Wait ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background, // Deep Flow background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // Мягкая пульсирующая иконка (вместо градиента и эмодзи)
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.card, // Цвет Bento-карточки
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.sage.withOpacity(0.08), // Нежное шалфейное свечение
                        blurRadius: 40,
                        spreadRadius: 10,
                      ),
                    ],
                    border: Border.all(color: context.colors.border, width: 1),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.mail_outline_rounded,
                      color: context.colors.sage, // Sage green
                      size: 42,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Title (с закосом под премиальную эстетику)
              Text(
                'Your space awaits',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.5,
                  // fontFamily: 'Lora', // Раскомментируй, если используешь Serif шрифты
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Эмпатичный текст
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 16,
                    height: 1.6,
                    fontWeight: FontWeight.w300,
                  ),
                  children: [
                    const TextSpan(text: 'We sent a link to\n'),
                    TextSpan(
                      text: widget.email,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const TextSpan(text: '\n\nCheck your inbox\nto step into your new routine.'),
                  ],
                ),
              ),

              const SizedBox(height: 64),

              // Кнопка повторной отправки
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_cooldown > 0 || _isSending) ? null : _resend,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.colors.card,
                    foregroundColor: context.colors.textPrimary,
                    disabledBackgroundColor: context.colors.background,
                    disabledForegroundColor: context.colors.textSecondary.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(40), // Pill-shape для кнопки
                      side: BorderSide(
                        color: _cooldown > 0 ? Colors.transparent : context.colors.border,
                        width: 1,
                      ),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: _isSending
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: context.colors.sage, // Мягкий лоадер
                      strokeWidth: 2,
                    ),
                  )
                      : Text(
                    _cooldownLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Ссылка возврата
              TextButton(
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false),
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.textSecondary,
                  splashFactory: NoSplash.splashFactory, // Отключаем жесткий ripple-эффект (Zen)
                ),
                child: const Text(
                  'Return to start',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
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