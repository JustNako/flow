import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/auth_service.dart';
import '../../api/habit_api_service.dart';
import '../../api/api_service.dart';
import '../../api/achievements_api_service.dart';
import '../../widgets/notification_settings_sheet.dart';
import '../../widgets/account_settings_sheet.dart';
import '../paywall/paywall_screen.dart';
import 'achievements_screen.dart';

const _kBg = Color(0xFF1A1A1A);
const _kCard = Color(0xFF242424);
const _kCardBorder = Color(0xFF2E2E2E);
const _kSage = Color(0xFF8BA888);
const _kLavender = Color(0xFF9F92C6);
const _kTerra = Color(0xFFD68C7A);
const _kGold = Color(0xFFFFD700);
const _kText = Color(0xFFE8E8E8);
const _kTextSub = Color(0xFF888888);

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
    return AlertDialog(
      backgroundColor: _kCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _kTerra, size: 28),
          const SizedBox(width: 12),
          Text('Delete Account',
              style: GoogleFonts.inter(color: _kText, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This action is permanent and cannot be undone. All your habits and data will be deleted.',
            style: GoogleFonts.inter(color: _kTextSub, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 24),
          Text('Enter your password to confirm:',
              style: GoogleFonts.inter(color: _kText, fontSize: 14)),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: _obscureText,
            style: GoogleFonts.inter(color: _kText),
            decoration: InputDecoration(
              hintText: 'Your password',
              hintStyle: GoogleFonts.inter(color: _kTextSub),
              filled: true,
              fillColor: _kBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kTerra, width: 1.5)),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: _kTextSub),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: Text('Cancel', style: GoogleFonts.inter(color: _kTextSub, fontSize: 15))),
        TextButton(
          onPressed: () {
            final password = _passwordController.text.trim();
            if (password.isEmpty) return;
            Navigator.of(context).pop(password);
          },
          child: Text('Delete',
              style: GoogleFonts.inter(color: _kTerra, fontSize: 15, fontWeight: FontWeight.w600)),
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
          backgroundColor: _kTerra,
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
      backgroundColor: _kCard,
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
                    BoxDecoration(color: _kCardBorder, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Text('Privacy & Security',
                style: GoogleFonts.playfairDisplay(
                    color: _kText, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () async {
                await Navigator.of(ctx).maybePop();
                if (mounted) _showDeleteAccountDialog();
              },
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _kTerra.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kTerra.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: _kTerra.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.delete_forever_outlined, color: _kTerra, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Delete Account',
                              style: GoogleFonts.inter(
                                  color: _kTerra, fontSize: 15, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Permanently delete your account and all data',
                              style: GoogleFonts.inter(color: _kTextSub, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: _kTerra, size: 20),
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
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kSage)),
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
      backgroundColor: _kBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: loadData,
          color: _kSage,
          backgroundColor: _kCard,
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
                        color: _kSage,
                        shape: BoxShape.circle,
                        border: Border.all(color: _kBg, width: 2),
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Name + PRO badge ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      userName,
                      style: GoogleFonts.playfairDisplay(
                          color: _kText, fontSize: 22, fontWeight: FontWeight.w700),
                    ),
                    if (isPro) ...[
                      const SizedBox(width: 10),
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
                            const SizedBox(width: 3),
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
                const SizedBox(height: 6),

                // ── Email ─────────────────────────────────────────────────────
                Text(email,
                    style: GoogleFonts.inter(color: _kTextSub, fontSize: 14)),
                const SizedBox(height: 12),

                // ── Member since pill ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kCardBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.eco_outlined, color: _kSage, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Member since $joinedAtStr',
                        style: GoogleFonts.inter(color: _kTextSub, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Bento Stat Cards ──────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _BentoStatCard(
                        emoji: '🧘‍♀️',
                        value: '$_totalHabits',
                        label: 'Total Habits',
                        accentColor: _kSage,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BentoStatCard(
                        emoji: '🔥',
                        value: '${_globalStreak}d',
                        label: 'Current Streak',
                        accentColor: _kTerra,
                        isHighlighted: true,
                      ),
                    ),
                    const SizedBox(width: 12),
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
                const SizedBox(height: 28),

                // ── ACCOUNT Section ───────────────────────────────────────────
                _SectionLabel(label: 'ACCOUNT'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kCardBorder),
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
                                  color: _kSage.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _kSage.withOpacity(0.3)),
                                ),
                                child: Text('ACTIVE',
                                    style: GoogleFonts.inter(
                                        color: _kSage,
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
                        iconColor: _kLavender,
                        title: 'Account Settings',
                        onTap: _showAccountSettings,
                      ),
                      _Divider(),
                      _SettingsRow(
                        icon: Icons.shield_outlined,
                        iconColor: _kTextSub,
                        title: 'Privacy & Security',
                        onTap: _showPrivacyBottomSheet,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ── SUPPORT Section ───────────────────────────────────────────
                _SectionLabel(label: 'SUPPORT'),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kCardBorder),
                  ),
                  child: Column(
                    children: [
                      _SettingsRow(
                        icon: Icons.notifications_none_rounded,
                        iconColor: _kSage,
                        title: 'Daily Reminders',
                        onTap: _showDailyReminders,
                      ),
                      _Divider(),
                      _SettingsRow(
                        icon: Icons.help_outline_rounded,
                        iconColor: _kTerra,
                        title: 'Help & FAQ',
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Coming soon! 🌿',
                                  style: GoogleFonts.inter(color: _kText)),
                              backgroundColor: _kCard,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(color: _kCardBorder)),
                            ),
                          );
                        },
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

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
                      color: _kCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _kTerra.withOpacity(0.25)),
                    ),
                    child: _isDeletingAccount
                        ? const Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: _kTerra, strokeWidth: 2),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.logout_rounded, color: _kTerra, size: 20),
                              const SizedBox(width: 10),
                              Text('Log out',
                                  style: GoogleFonts.inter(
                                      color: _kTerra,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 28),

                // ── Footer ────────────────────────────────────────────────────
                Text(
                  'Flow v1.0 · Crafted with calm 🌿',
                  style: GoogleFonts.inter(color: _kTextSub.withOpacity(0.5), fontSize: 12),
                ),
                const SizedBox(height: 8),
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
        color: isHighlighted ? _kTerra.withOpacity(0.08) : _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isHighlighted ? _kTerra.withOpacity(0.3) : _kCardBorder,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              color: _kText,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: _kTextSub, fontSize: 11, height: 1.3),
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
          color: _kTextSub,
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
    return const Divider(
      height: 1,
      thickness: 1,
      color: _kCardBorder,
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
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: _kText,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              trailing ??
                  const Icon(Icons.chevron_right_rounded, color: _kTextSub, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
