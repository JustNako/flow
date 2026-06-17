import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../api/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'email_pending_screen.dart';
import '../../theme/app_theme.dart';
import '../../services/notification_service.dart';
import '../../widgets/google_sign_in_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  final _authService = AuthService();
  bool _isLoading = false;
  bool _agreedToPrivacy = false;

  Future<void> _launchPrivacyPolicy() async {
    //final url = Uri.parse('${ApiService.serverRoot}/privacy.html');
    final url = Uri.parse('https://flowtracks.app/privacy');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open privacy policy")));
      }
    }
  }

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    if (!_agreedToPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must agree to the Privacy Policy")),
      );
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid email address")),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters")),
      );
      return;
    }

    // Check for special character
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_=\-+]'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must contain at least one special character (e.g. _, !)")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.register(username, email, password);

      // Tell OS that registration is finished (so it prompts to save password)
      TextInput.finishAutofillContext();

      if (!mounted) return;

      // Navigate to EmailPendingScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EmailPendingScreen(email: email),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: context.colors.danger,
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    if (!_agreedToPrivacy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must agree to the Privacy Policy")),
      );
      return;
    }

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

      // Navigate to MainScreen (go home and clear backstack)
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
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

  Widget _buildGoogleSignInButton() {
    return GoogleSignInButton(
      label: 'Sign up with Google',
      onPressed: _loginWithGoogle,
      isLoading: _isLoading,
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
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
                    'Create Account',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Start your habit tracking journey',
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
  
                  // Username Field
                  _buildLabel('Username'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _usernameController,
                    hintText: 'Your username',
                    autofillHints: [AutofillHints.newUsername],
                  ),
                  const SizedBox(height: 24),
  
                  // Email Field
                  _buildLabel('Email'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _emailController,
                    hintText: 'your@email.com',
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: [AutofillHints.email],
                  ),
                  const SizedBox(height: 24),
  
                  // Password Field
                  _buildLabel('Password'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _passwordController,
                    hintText: 'Create a password',
                    obscureText: true,
                    autofillHints: [AutofillHints.newPassword],
                  ),
  
                  // Privacy Policy Checkbox
                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _agreedToPrivacy,
                          onChanged: (val) => setState(() => _agreedToPrivacy = val ?? false),
                          activeColor: context.colors.textPrimary,
                          checkColor: context.colors.background,
                          side: BorderSide(color: context.colors.textSecondary.withOpacity(0.5), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _launchPrivacyPolicy,
                          child: Text.rich(
                            TextSpan(
                              text: "I agree to the ",
                              style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
                              children: [
                                TextSpan(
                                  text: "Privacy Policy",
                                  style: TextStyle(color: context.colors.textPrimary, decoration: TextDecoration.underline),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
  
                  const SizedBox(height: 32),
  
                  // Create Account Button
                  _buildRegisterButton(),
  
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
                  const SizedBox(height: 24),
  
                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Already have an account? ",
                        style: TextStyle(
                          color: context.colors.textSecondary,
                          fontSize: 15,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // Go back to login screen
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          "Sign in",
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

  Widget _buildRegisterButton() {
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
        onPressed: _isLoading ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colors.textPrimary,
          foregroundColor: context.colors.background,
          disabledBackgroundColor: context.colors.textSecondary.withOpacity(0.5),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
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
                'Create Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
