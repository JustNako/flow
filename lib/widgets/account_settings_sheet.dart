import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../api/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../screens/auth/email_pending_screen.dart';
import '../theme/app_theme.dart';

class AccountSettingsBottomSheet extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  const AccountSettingsBottomSheet({super.key, this.initialData});

  @override
  State<AccountSettingsBottomSheet> createState() => _AccountSettingsBottomSheetState();
}

class _AccountSettingsBottomSheetState extends State<AccountSettingsBottomSheet> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  
  bool _isLoading = false;
  String? _error;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _usernameController.text = widget.initialData!['userName'] ?? '';
      _emailController.text = widget.initialData!['email'] ?? '';
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await AuthService.instance.getToken();
      if (token == null) return;

      final response = await ApiService().editProfile(
        token,
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        currentPassword: _currentPasswordController.text.isNotEmpty ? _currentPasswordController.text : null,
        newPassword: _newPasswordController.text.isNotEmpty ? _newPasswordController.text : null,
      );

      if (mounted) {
        if (response['emailChanged'] == true) {
          final newEmail = _emailController.text.trim();
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => EmailPendingScreen(email: newEmail)),
            (route) => false,
          );
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _launchPrivacyPolicy() async {
    final url = Uri.parse('${ApiService.serverRoot}/privacy.html');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      setState(() => _error = 'Could not open privacy policy: $e');
    }
  }

  Future<void> _cancelPro() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        title: Text('Cancel Pro Plan', style: TextStyle(color: context.colors.textPrimary)),
        content: Text('Are you sure you want to cancel your Pro plan? You will lose access to advanced analytics and AI insights.', style: TextStyle(color: context.colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Pro', style: TextStyle(color: context.colors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Cancel Plan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await AuthService.instance.getToken();
      if (token == null) return;

      await ApiService().cancelProPlan(token);
      if (mounted) Navigator.pop(context, true); // Return true to reload profile
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 28, right: 28, top: 28,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Text('Account Settings',
              style: TextStyle(color: context.colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            _buildField('Username', _usernameController, icon: Icons.person_outline),
            const SizedBox(height: 16),
            _buildField('Email', _emailController, icon: Icons.mail_outline),
            const SizedBox(height: 24),
            Divider(color: context.colors.border),
            const SizedBox(height: 24),
            Text('Change Password', style: TextStyle(color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            _buildField(
              'Current Password', _currentPasswordController, 
              icon: Icons.lock_outline, isPassword: true, hint: 'Required for changes',
              obscureText: _obscureCurrentPassword,
              onToggleObscure: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword)
            ),
            const SizedBox(height: 16),
            _buildField(
              'New Password', _newPasswordController, 
              icon: Icons.lock_reset, isPassword: true, hint: 'Leave empty to keep current',
              obscureText: _obscureNewPassword,
              onToggleObscure: () => setState(() => _obscureNewPassword = !_obscureNewPassword)
            ),
            
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8845C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),

            if (widget.initialData != null && widget.initialData!['isPro'] == true) ...[
              const SizedBox(height: 32),
              Divider(color: context.colors.border),
              const SizedBox(height: 24),
              Text('Subscription', style: TextStyle(color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _cancelPro,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Cancel Pro Plan', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],

            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: _launchPrivacyPolicy,
                icon: Icon(Icons.privacy_tip_outlined, size: 18, color: context.colors.textSecondary),
                label: Text('Privacy Policy', style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {required IconData icon, bool isPassword = false, String? hint, bool? obscureText, VoidCallback? onToggleObscure}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscureText ?? false,
          style: TextStyle(color: context.colors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: context.colors.textSecondary.withOpacity(0.5), fontSize: 14),
            prefixIcon: Icon(icon, color: const Color(0xFFE8845C), size: 20),
            suffixIcon: isPassword 
                ? IconButton(
                    icon: Icon(
                      (obscureText ?? true) ? Icons.visibility_off : Icons.visibility,
                      color: context.colors.textSecondary,
                      size: 20,
                    ),
                    onPressed: onToggleObscure,
                  )
                : null,
            filled: true,
            fillColor: context.colors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
