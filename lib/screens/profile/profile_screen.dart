import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../api/habit_api_service.dart';
import '../../api/api_service.dart';
import '../paywall/paywall_screen.dart';

import '../../widgets/notification_settings_sheet.dart';
import '../../widgets/account_settings_sheet.dart';
import '../../api/achievements_api_service.dart';
import '../../theme/app_theme.dart';
import 'achievements_screen.dart';

// ─── Отдельный виджет для диалога удаления ─────────────────────────────────
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  bool _obscureText = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: context.colors.danger, size: 28),
          const SizedBox(width: 12),
          Text(
            'Delete Account',
            style: TextStyle(color: context.colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This action is permanent and cannot be undone. All your habits and data will be deleted.',
            style: TextStyle(color: context.colors.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          Text(
            'Enter your password to confirm:',
            style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: _obscureText,
            style: TextStyle(color: context.colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Your password',
              hintStyle: TextStyle(color: context.colors.textSecondary),
              filled: true,
              fillColor: context.colors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.colors.danger, width: 1.5),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: context.colors.textSecondary,
                ),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text('Cancel', style: TextStyle(color: context.colors.textSecondary, fontSize: 16)),
        ),
        TextButton(
          onPressed: () {
            final password = _passwordController.text.trim();
            if (password.isEmpty) return;
            Navigator.of(context).pop(password); // Возвращаем пароль, не вызываем async код
          },
          child: Text(
            'Delete',
            style: TextStyle(color: context.colors.danger, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ─── Основной экран профиля ─────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  bool _isDeletingAccount = false;
  Map<String, dynamic>? _userProfile;
  int _totalHabits = 0;
  int _globalStreak = 0;
  List<UserAchievementDto> _unlockedAchievements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final token = await AuthService.instance.getToken();
      if (token != null) {
        final profile = await ApiService().getUserProfile(token);
        final habits = await HabitApiService.instance.getHabits();
        final streak = await HabitApiService.instance.getGlobalStreak();
        List<UserAchievementDto> achievements = [];
        try {
          achievements = await AchievementsApiService.instance.getAchievements();
        } catch (e) {
          debugPrint('Error loading achievements: $e');
        }
        
        if (mounted) {
          setState(() {
            _userProfile = profile;
            _totalHabits = habits.length;
            _globalStreak = streak;
            _unlockedAchievements = achievements;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    // Используем отдельный виджет вместо StatefulBuilder
    final confirmedPassword = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _DeleteAccountDialog(),
    );

    // Только после полного закрытия диалога — вызываем async операцию
    if (confirmedPassword != null && mounted) {
      await _deleteAccount(confirmedPassword);
    }
  }

  Future<void> _deleteAccount(String password) async {
    setState(() => _isDeletingAccount = true);
    try {
      await AuthService.instance.deleteAccount(password);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  void _showPrivacyBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: context.colors.iconBg, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Text('Privacy & Security',
              style: TextStyle(color: context.colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () async {
                // Ждем пока BottomSheet полностью закроется
                await Navigator.of(ctx).maybePop();
                if (mounted) _showDeleteAccountDialog();
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.colors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.danger.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: context.colors.danger.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.delete_forever_outlined, color: context.colors.danger, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Delete Account',
                            style: TextStyle(color: context.colors.danger, fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Permanently delete your account and all data',
                            style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: context.colors.danger, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: Center(child: CircularProgressIndicator(color: context.colors.secondary)),
      );
    }

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadData,
          color: context.colors.secondary,
          backgroundColor: context.colors.card,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profile',
                  style: TextStyle(color: context.colors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 32),
                _buildUserCard(),
                if (_userProfile?['isPro'] != true) ...[
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () async {
                      final purchased = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PaywallScreen()));
                      if (purchased == true) {
                        // Temporarily activate Pro on backend until RevenueCat webhook is live
                        try {
                          final token = await AuthService.instance.getToken();
                          if (token != null) await ApiService().upgradeToPro(token, 'monthly');
                        } catch (_) {}
                        loadData(showLoading: false);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: context.colors.secondary,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: context.colors.secondary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.workspace_premium, color: Colors.white, size: 32),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Unlock PRO', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text('Unlimited habits & stats', style: TextStyle(color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                Text('Settings',
                  style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.w500)),
                const SizedBox(height: 16),
                _buildSettingsList(),
                const SizedBox(height: 40),
                _buildLogOutButton(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard() {
    final userName = _userProfile?['userName'] ?? 'User';
    final email = _userProfile?['email'] ?? 'No email';
    final joinedAtStr = _userProfile?['joinedAt'] != null 
        ? DateFormat('MMM yyyy').format(DateTime.parse(_userProfile!['joinedAt']))
        : 'Jan 2026';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.colors.secondary,
              boxShadow: [BoxShadow(color: context.colors.secondary.withOpacity(0.3), blurRadius: 24, spreadRadius: 4, offset: const Offset(0, 4))],
            ),
            child: const Icon(Icons.person_outline, color: Colors.white, size: 48),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(userName, style: TextStyle(color: context.colors.textPrimary, fontSize: 22, fontWeight: FontWeight.w600)),
              if (_userProfile?['isPro'] == true) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: context.colors.secondary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.mail_outline, email),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.calendar_today_outlined, 'Member since $joinedAtStr'),
          const SizedBox(height: 32),
          Divider(color: context.colors.iconBg, thickness: 1),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(Icons.track_changes, const Color(0xFF00B4DB), '$_totalHabits', 'Total Habits', null),
              _buildStatItem(Icons.local_fire_department, const Color(0xFFFF512F), '$_globalStreak', 'Current Streak', null),
              _buildStatItem(Icons.emoji_events, const Color(0xFFFFB75E), '${_unlockedAchievements.length}', 'Achievements', () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => AchievementsScreen(unlockedAchievements: _unlockedAchievements)));
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: context.colors.textSecondary, size: 16),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: context.colors.textSecondary, fontSize: 14)),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, Color color, String value, String label, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 16),
          Text(value, style: TextStyle(color: context.colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  void _showNotificationSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const NotificationSettingsBottomSheet(),
    );
  }

  void _showAccountSettings() async {
    final result = await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => AccountSettingsBottomSheet(initialData: _userProfile),
    );

    if (result == true) {
      loadData(); // Refresh profile info if updated
    }
  }

  Widget _buildSettingsList() {
    return Column(
      children: [
        _buildSettingsItem(Icons.notifications_none, 'Notifications', onTap: _showNotificationSettings),
        const SizedBox(height: 12),
        _buildSettingsItem(Icons.settings_outlined, 'Account Settings', onTap: _showAccountSettings),
        const SizedBox(height: 12),
        _buildSettingsItem(Icons.shield_outlined, 'Privacy & Security', onTap: _showPrivacyBottomSheet),
      ],
    );
  }

  Widget _buildSettingsItem(IconData icon, String title, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: context.colors.textPrimary, size: 24),
            const SizedBox(width: 16),
            Expanded(child: Text(title,
              style: TextStyle(color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500))),
            Icon(Icons.chevron_right, color: context.colors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLogOutButton() {
    return GestureDetector(
      onTap: _isDeletingAccount ? null : () async {
        await AuthService.instance.logout();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: context.colors.danger.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
        child: _isDeletingAccount
          ? Center(child: SizedBox(width: 24, height: 24,
              child: CircularProgressIndicator(color: context.colors.danger, strokeWidth: 2)))
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout, color: context.colors.danger, size: 24),
                const SizedBox(width: 12),
                Text('Log Out',
                  style: TextStyle(color: context.colors.danger, fontSize: 18, fontWeight: FontWeight.w600)),
              ],
            ),
      ),
    );
  }
}
