import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../services/theme_service.dart';
import '../../api/habit_api_service.dart';
import '../../api/api_service.dart';
import '../../api/achievements_api_service.dart';
import '../../widgets/notification_settings_sheet.dart';
import '../../widgets/account_settings_sheet.dart';
import '../paywall/paywall_screen.dart';
import '../../theme/app_theme.dart';
import 'achievements_screen.dart';

// Gold is not in AppColors so we keep it as a constant
const _kGold = Color(0xFFFFD700);

// ─── Delete Account Dialog ───────────────────────────────────────────────────
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
    final colors = context.colors;
    return AlertDialog(
      backgroundColor: colors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.terracotta, size: 28),
          SizedBox(width: 12),
          Text('Delete Account',
              style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This action is permanent and cannot be undone. All your habits and data will be deleted.',
            style: GoogleFonts.inter(color: colors.textSecondary, fontSize: 14, height: 1.5),
          ),
          SizedBox(height: 24),
          Text('Enter your password to confirm:',
              style: GoogleFonts.inter(color: colors.textPrimary, fontSize: 14)),
          SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: _obscureText,
            style: GoogleFonts.inter(color: colors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Your password',
              hintStyle: GoogleFonts.inter(color: colors.textSecondary),
              filled: true,
              fillColor: colors.background,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.terracotta, width: 1.5)),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: colors.textSecondary),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text('Cancel', style: GoogleFonts.inter(color: colors.textSecondary, fontSize: 15))),
        TextButton(
          onPressed: () {
            final password = _passwordController.text.trim();
            if (password.isEmpty) return;
            Navigator.of(context).pop(password);
          },
          child: Text('Delete',
              style: GoogleFonts.inter(color: colors.terracotta, fontSize: 15, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ─── Main Profile Screen ─────────────────────────────────────────────────────
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
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData({bool showLoading = true}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final packageInfo = await PackageInfo.fromPlatform();
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
            _appVersion = packageInfo.version;
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
    final confirmedPassword = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _DeleteAccountDialog(),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: context.colors.terracotta,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration:
                    BoxDecoration(color: context.colors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            SizedBox(height: 24),
            Text('Privacy & Security',
                style: GoogleFonts.playfairDisplay(
                    color: context.colors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 24),
            GestureDetector(
              onTap: () async {
                await Navigator.of(ctx).maybePop();
                if (mounted) _showDeleteAccountDialog();
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.colors.terracotta.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.terracotta.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: context.colors.terracotta.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.delete_forever_outlined, color: context.colors.terracotta, size: 22),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Delete Account',
                              style: GoogleFonts.inter(
                                  color: context.colors.terracotta, fontSize: 15, fontWeight: FontWeight.w600)),
                          SizedBox(height: 4),
                          Text('Permanently delete your account and all data',
                              style: GoogleFonts.inter(color: context.colors.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: context.colors.terracotta, size: 20),
                  ],
                ),
              ),
            ),
            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showDailyReminders() {
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
    if (result == true) loadData(showLoading: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.colors.background,
        body: Center(child: CircularProgressIndicator(color: context.colors.sage)),
      );
    }

    final userName = _userProfile?['userName'] ?? 'User';
    final email = _userProfile?['email'] ?? '';
    final isPro = _userProfile?['isPro'] == true;
    final joinedAtStr = _userProfile?['joinedAt'] != null
        ? DateFormat('MMMM yyyy').format(DateTime.parse(_userProfile!['joinedAt']))
        : 'January 2026';
    final initials = userName.isNotEmpty
        ? userName.trim().split(' ').map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').take(2).join()
        : '?';

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadData,
          color: context.colors.sage,
          backgroundColor: context.colors.card,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Avatar ───────────────────────────────────────────────────
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7BA87A), Color(0xFFB0A8D0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: context.colors.sage,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.colors.background, width: 2),
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // ── Name + PRO badge ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      userName,
                      style: GoogleFonts.playfairDisplay(
                          color: context.colors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    if (isPro) ...[
                      SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _kGold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _kGold.withOpacity(0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt_rounded, color: _kGold, size: 12),
                            SizedBox(width: 3),
                            Text('PRO',
                                style: GoogleFonts.inter(
                                    color: _kGold,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 6),

                // ── Email ─────────────────────────────────────────────────────
                Text(email,
                    style: GoogleFonts.inter(color: context.colors.textSecondary, fontSize: 14)),
                SizedBox(height: 12),

                // ── Member since pill ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.colors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.eco_outlined, color: context.colors.sage, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Member since $joinedAtStr',
                        style: GoogleFonts.inter(color: context.colors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 28),

                // ── Bento Stat Cards ──────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _BentoStatCard(
                        emoji: '🧘‍♀️',
                        value: '$_totalHabits',
                        label: 'Total Habits',
                        accentColor: context.colors.sage,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _BentoStatCard(
                        emoji: '🔥',
                        value: '${_globalStreak}d',
                        label: 'Current Streak',
                        accentColor: context.colors.terracotta,
                        isHighlighted: true,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AchievementsScreen(
                                unlockedAchievements: _unlockedAchievements),
                          ),
                        ),
                        child: _BentoStatCard(
                          emoji: '🏆',
                          value: '${_unlockedAchievements.length}',
                          label: 'Achieve-\nments',
                          accentColor: _kGold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 28),

                // ── ACCOUNT Section ───────────────────────────────────────────
                _SectionLabel(label: 'ACCOUNT'),
                SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: context.colors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Column(
                    children: [
                      _SettingsRow(
                        icon: Icons.workspace_premium_rounded,
                        iconColor: _kGold,
                        title: 'Flow Pro',
                        trailing: isPro
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: context.colors.sage.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: context.colors.sage.withOpacity(0.3)),
                                ),
                                child: Text('ACTIVE',
                                    style: GoogleFonts.inter(
                                        color: context.colors.sage,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5)),
                              )
                            : null,
                        onTap: !isPro
                            ? () async {
                                final purchased = await Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const PaywallScreen()));
                                if (purchased == true) {
                                  try {
                                    final token = await AuthService.instance.getToken();
                                    if (token != null) {
                                      await ApiService().upgradeToPro(token, 'monthly');
                                    }
                                  } catch (_) {}
                                  loadData(showLoading: false);
                                }
                              }
                            : null,
                      ),
                      _Divider(),
                      _SettingsRow(
                        icon: Icons.tune_rounded,
                        iconColor: context.colors.lavender,
                        title: 'Account Settings',
                        onTap: _showAccountSettings,
                      ),
                      _Divider(),
                      _SettingsRow(
                        icon: Icons.shield_outlined,
                        iconColor: context.colors.textSecondary,
                        title: 'Privacy & Security',
                        onTap: _showPrivacyBottomSheet,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // ── APPEARANCE Section ────────────────────────────────────────
                _SectionLabel(label: 'APPEARANCE'),
                SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: context.colors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: context.colors.lavender.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.palette_outlined, color: context.colors.lavender, size: 18),
                          ),
                          SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Theme',
                              style: GoogleFonts.inter(
                                color: context.colors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      _ThemeSegmentedControl(
                        currentMode: ThemeService.instance.themeMode,
                        onChanged: (mode) {
                          ThemeService.instance.setThemeMode(mode);
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // ── SUPPORT Section ───────────────────────────────────────────
                _SectionLabel(label: 'SUPPORT'),
                SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: context.colors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: Column(
                    children: [
                      _SettingsRow(
                        icon: Icons.notifications_none_rounded,
                        iconColor: context.colors.sage,
                        title: 'Daily Reminders',
                        onTap: _showDailyReminders,
                      ),
                      _Divider(),
                      _SettingsRow(
                        icon: Icons.help_outline_rounded,
                        iconColor: context.colors.terracotta,
                        title: 'Help & FAQ',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Coming soon! 🌿',
                                  style: GoogleFonts.inter(color: context.colors.textPrimary)),
                              backgroundColor: context.colors.card,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: context.colors.border)),
                            ),
                          );
                        },
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),

                // ── Log out ───────────────────────────────────────────────────
                GestureDetector(
                  onTap: _isDeletingAccount
                      ? null
                      : () async {
                          await AuthService.instance.logout();
                          if (mounted) {
                            Navigator.of(context)
                                .pushNamedAndRemoveUntil('/login', (route) => false);
                          }
                        },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      color: context.colors.card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: context.colors.terracotta.withOpacity(0.25)),
                    ),
                    child: _isDeletingAccount
                        ? Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: context.colors.terracotta, strokeWidth: 2),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded, color: context.colors.terracotta, size: 20),
                              SizedBox(width: 10),
                              Text('Log out',
                                  style: GoogleFonts.inter(
                                      color: context.colors.terracotta,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                  ),
                ),
                SizedBox(height: 28),

                // ── Footer ────────────────────────────────────────────────────
                Text(
                  'Flow v$_appVersion · Crafted with calm 🌿',
                  style: GoogleFonts.inter(color: context.colors.textSecondary.withOpacity(0.5), fontSize: 12),
                ),
                SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bento Stat Card ──────────────────────────────────────────────────────────
class _BentoStatCard extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color accentColor;
  final bool isHighlighted;

  const _BentoStatCard({
    required this.emoji,
    required this.value,
    required this.label,
    required this.accentColor,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: isHighlighted ? context.colors.terracotta.withOpacity(0.08) : context.colors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isHighlighted ? context.colors.terracotta.withOpacity(0.3) : context.colors.border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              color: context.colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: context.colors.textSecondary, fontSize: 11, height: 1.3),
          ),
        ],
      ),
    );
  }
}

// ── Section Label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: context.colors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

// ── Divider ───────────────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: context.colors.border,
      indent: 56,
    );
  }
}

// ── Settings Row ─────────────────────────────────────────────────────────────
class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool isLast;

  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.onTap,
    this.trailing,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(0),
          bottom: isLast ? const Radius.circular(20) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: context.colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              trailing ??
                  Icon(Icons.chevron_right_rounded, color: context.colors.textSecondary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Theme Segmented Control ──────────────────────────────────────────────────
class _ThemeSegmentedControl extends StatelessWidget {
  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeSegmentedControl({
    required this.currentMode,
    required this.onChanged,
  });

  static const _modes = [
    (ThemeMode.system, Icons.brightness_auto_rounded, 'System'),
    (ThemeMode.light, Icons.light_mode_rounded, 'Light'),
    (ThemeMode.dark, Icons.dark_mode_rounded, 'Dark'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / _modes.length;
          final selectedIndex = _modes.indexWhere((m) => m.$1 == currentMode);

          return Stack(
            children: [
              // Animated selection pill
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: selectedIndex * segmentWidth + 3,
                top: 3,
                bottom: 3,
                width: segmentWidth - 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: context.colors.sage.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: context.colors.sage.withOpacity(0.35)),
                  ),
                ),
              ),
              // Options
              Positioned.fill(
                child: Row(
                  children: _modes.map((entry) {
                    final isSelected = entry.$1 == currentMode;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onChanged(entry.$1),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          style: GoogleFonts.inter(
                            color: isSelected ? context.colors.sage : context.colors.textSecondary,
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: Icon(
                                  entry.$2,
                                  key: ValueKey('${entry.$3}_$isSelected'),
                                  size: 16,
                                  color: isSelected ? context.colors.sage : context.colors.textSecondary,
                                ),
                              ),
                              SizedBox(width: 6),
                              Text(entry.$3),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

