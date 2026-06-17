import 'package:flutter/material.dart';
import '../../api/api_service.dart';
import '../../theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? initialEmail;
  const ForgotPasswordScreen({super.key, this.initialEmail});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _emailController.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // Кастомный мягкий SnackBar для сохранения Zen-атмосферы
  void _showSoftSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
            color: isError ? context.colors.danger : context.colors.sage,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
        backgroundColor: context.colors.card,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(32),
          side: BorderSide(color: context.colors.border, width: 1),
        ),
        margin: const EdgeInsets.only(bottom: 40, left: 24, right: 24),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSoftSnackbar("Please enter your email address.", isError: true);
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showSoftSnackbar("That doesn't look quite right. Try again.", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiService().forgotPassword(email);
      if (!mounted) return;
      setState(() => _success = true);
    } catch (e) {
      if (!mounted) return;
      _showSoftSnackbar(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background, // Deep Flow background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: context.colors.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            physics: const BouncingScrollPhysics(),
            child: _success ? _buildSuccessState() : _buildInputState(),
          ),
        ),
      ),
    );
  }

  Widget _buildInputState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Мягкая иконка ключа
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.colors.card,
            border: Border.all(color: context.colors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: context.colors.lavender.withOpacity(0.08), // Lavender glow
                blurRadius: 30,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Icon(Icons.vpn_key_outlined, size: 32, color: context.colors.lavender),
        ),
        const SizedBox(height: 32),

        // Заголовок
        Text(
          'Find your way back',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Эмпатичный текст
        Text(
          'Breathe, it happens. Enter your email and we\'ll send you a reminder to reset your password.',
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 16,
            height: 1.6,
            fontWeight: FontWeight.w300,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 48),

        // Поле ввода Email (Bento-стиль)
        Container(
          decoration: BoxDecoration(
            color: context.colors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.colors.border, width: 1),
          ),
          child: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: context.colors.textPrimary, fontSize: 16),
            cursorColor: context.colors.lavender,
            decoration: InputDecoration(
              hintText: 'your@email.com',
              hintStyle: TextStyle(color: context.colors.textSecondary.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.w300),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Главная кнопка действия (Lavender)
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _sendResetLink,
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.lavender, // Soft Lavender
              foregroundColor: Colors.black87, // Темный текст для контраста
              disabledBackgroundColor: context.colors.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            child: _isLoading
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.black87, strokeWidth: 2)
            )
                : const Text(
              'Send Reset Link',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Иконка успеха (Sage Green)
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.colors.card,
            border: Border.all(color: context.colors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: context.colors.sage.withOpacity(0.08),
                blurRadius: 30,
                spreadRadius: 8,
              ),
            ],
          ),
          child: Icon(Icons.mail_outline_rounded, size: 32, color: context.colors.sage),
        ),
        const SizedBox(height: 32),

        Text(
          'Check your inbox',
          style: TextStyle(
            color: context.colors.textPrimary,
            fontSize: 28,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

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
              const TextSpan(text: 'We sent a reset link to\n'),
              TextSpan(
                text: _emailController.text,
                style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w500),
              ),
              const TextSpan(text: '\n\nClick the link to create a new password.'),
            ],
          ),
        ),
        const SizedBox(height: 48),

        // Кнопка возврата (TextButton вместо агрессивного Outlined)
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            foregroundColor: context.colors.textSecondary,
            splashFactory: NoSplash.splashFactory,
          ),
          child: const Text(
            'Return to Sign In',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
          ),
        ),
      ],
    );
  }
}