import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/auth_service.dart';
import '../../api/api_service.dart';
import 'dart:convert';
import 'email_pending_screen.dart';
import 'forgot_password_screen.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/google_sign_in_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  Future<void> _login() async {
    final username = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your username and password")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.login(username, password);
      
      // Tell OS that autofill is finished (so it prompts to save password)
      TextInput.finishAutofillContext();

      // Upload FCM token to backend now that we are authenticated
      await NotificationService.instance.sendTokenToServer();

      if (!mounted) return;

      // Navigate to MainScreen
      Navigator.of(context).pushReplacementNamed('/main');
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');

      // Check if email is not confirmed
      if (msg.startsWith('email_not_confirmed:')) {
        final email = msg.split(':')[1];
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EmailPendingScreen(email: email)),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Login error: $msg"),
          backgroundColor: context.colors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final token = await _authService.signInWithGoogle();
      if (token == null) {
        // User cancelled login
        return;
      }

      // Upload FCM token to backend
      await NotificationService.instance.sendTokenToServer();

      if (!mounted) return;

      // Navigate to MainScreen
      Navigator.of(context).pushReplacementNamed('/main');
    } catch (e) {
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Google Sign-In error: $msg"),
          backgroundColor: context.colors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchPrivacyPolicy() async {
    final url = Uri.parse('https://flowtracks.app/privacy');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open privacy policy")),
        );
      }
    }
  }

  Widget _buildGoogleSignInButton() {
    return GoogleSignInButton(
      label: 'Sign in with Google',
      onPressed: _loginWithGoogle,
      isLoading: _isLoading,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 48.0),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header
                  Text(
                    'Welcome Back',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sign in to continue tracking your habits',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
  
                  // Email Field
                  _buildLabel('Username'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _emailController,
                    hintText: 'Enter your username',
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: [AutofillHints.username, AutofillHints.email],
                  ),
                  const SizedBox(height: 24),
  
                  // Password Field
                  _buildLabel('Password'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _passwordController,
                    hintText: 'Enter your password',
                    obscureText: true,
                    autofillHints: [AutofillHints.password],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ForgotPasswordScreen(
                              initialEmail: _emailController.text.contains('@') 
                                  ? _emailController.text 
                                  : null,
                            ),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
  
                  const SizedBox(height: 32),
  
                  // Sign In Button
                  _buildSignInButton(),
  
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: Divider(color: context.colors.border, thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or',
                          style: TextStyle(
                            color: context.colors.textSecondary.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: context.colors.border, thickness: 1)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildGoogleSignInButton(),
                  const SizedBox(height: 12),

                  // Privacy disclosure — shown below Google button
                  // (standard pattern: no checkbox needed on login, just disclosure)
                  GestureDetector(
                    onTap: _launchPrivacyPolicy,
                    child: Text.rich(
                      TextSpan(
                        text: 'By continuing, you agree to our ',
                        style: TextStyle(
                          color: context.colors.textSecondary.withOpacity(0.55),
                          fontSize: 12,
                        ),
                        children: [
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: context.colors.textSecondary.withOpacity(0.8),
                              fontSize: 12,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 24),
  
                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pushNamed('/register');
                        },
                        child: Text(
                          "Create one",
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: context.colors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType? keyboardType,
    Iterable<String>? autofillHints,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        style: TextStyle(color: context.colors.textPrimary, fontSize: 16),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: context.colors.textSecondary.withOpacity(0.5), fontSize: 16),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildSignInButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.colors.primary.withOpacity(0.15),
            blurRadius: 24,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colors.textPrimary,
          foregroundColor: context.colors.background,
          disabledBackgroundColor: context.colors.textSecondary.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0, // using Container shadow instead
        ),
        child: _isLoading
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: context.colors.background,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
