import 'package:flutter/material.dart';

class AppColors extends ThemeExtension<AppColors> {
  final Color background;
  final Color card;
  final Color cardSecondary;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color iconBg;
  final Color danger;
  final Color success;
  final Color warning;
  final Color primary;
  final Color secondary;
  final Color sage;
  final Color lavender;
  final Color terracotta;
  final Color blue;
  final Color gold;
  final List<List<Color>> habitGradients;

  const AppColors({
    required this.background,
    required this.card,
    required this.cardSecondary,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.iconBg,
    required this.danger,
    required this.success,
    required this.warning,
    required this.primary,
    required this.secondary,
    required this.sage,
    required this.lavender,
    required this.terracotta,
    required this.blue,
    required this.gold,
    required this.habitGradients,
  });

  @override
  ThemeExtension<AppColors> copyWith({
    Color? background,
    Color? card,
    Color? cardSecondary,
    Color? textPrimary,
    Color? textSecondary,
    Color? border,
    Color? iconBg,
    Color? danger,
    Color? success,
    Color? warning,
    Color? primary,
    Color? secondary,
    Color? sage,
    Color? lavender,
    Color? terracotta,
    Color? blue,
    Color? gold,
    List<List<Color>>? habitGradients,
  }) {
    return AppColors(
      background: background ?? this.background,
      card: card ?? this.card,
      cardSecondary: cardSecondary ?? this.cardSecondary,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      border: border ?? this.border,
      iconBg: iconBg ?? this.iconBg,
      danger: danger ?? this.danger,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      sage: sage ?? this.sage,
      lavender: lavender ?? this.lavender,
      terracotta: terracotta ?? this.terracotta,
      blue: blue ?? this.blue,
      gold: gold ?? this.gold,
      habitGradients: habitGradients ?? this.habitGradients,
    );
  }

  @override
  ThemeExtension<AppColors> lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardSecondary: Color.lerp(cardSecondary, other.cardSecondary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      border: Color.lerp(border, other.border, t)!,
      iconBg: Color.lerp(iconBg, other.iconBg, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      sage: Color.lerp(sage, other.sage, t)!,
      lavender: Color.lerp(lavender, other.lavender, t)!,
      terracotta: Color.lerp(terracotta, other.terracotta, t)!,
      blue: Color.lerp(blue, other.blue, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      habitGradients: t < 0.5 ? habitGradients : other.habitGradients,
    );
  }
}

class AppTheme {
  // ─── Dark Theme Colors (Premium Matte Charcoal) ───────────────────────────
  static const _darkBackground     = Color(0xFF1A1A1A); // Matte charcoal
  static const _darkCard           = Color(0xFF242424); // Elevated card surface
  static const _darkCardSecondary  = Color(0xFF1E1E1E); // Slightly recessed surface
  static const _darkTextPrimary    = Color(0xFFE8E8E8); // Soft white — easier on eyes
  static const _darkTextSecondary  = Color(0xFF888888); // Muted label
  static const _darkBorder         = Color(0xFF2E2E2E); // Subtle dividers
  static const _darkIconBg         = Color(0xFF2A2A2A); // Icon container bg

  // ─── Light Theme Colors (Warm Cream / Paper Premium) ──────────────────────
  static const _lightBackground    = Color(0xFFF9F9F6); // Soft off-white cream
  static const _lightCard          = Color(0xFFFFFFFF); // Clean white for cards
  static const _lightCardSecondary = Color(0xFFF0F0ED); // Slightly deeper cream
  static const _lightTextPrimary   = Color(0xFF1E2230); // Very dark navy/charcoal
  static const _lightTextSecondary = Color(0xFF7A7E8D); // Muted label
  static const _lightBorder        = Color(0xFFE5E5E0); // Subtle warm dividers
  static const _lightIconBg        = Color(0xFFF0F0ED); // Icon container bg

  // ─── Accent Colors (shared across both themes) ────────────────────────────
  static const _darkSage       = Color(0xFF8BA888); // Calming sage green (dark)
  static const _darkLavender   = Color(0xFF9F92C6); // Soft lavender (dark)
  static const _darkTerracotta = Color(0xFFE8845C); // Earthy terracotta (dark)

  static const _lightSage       = Color(0xFF5E8A5A); // Deeper sage for light bg contrast
  static const _lightLavender   = Color(0xFF7B6FB8); // Deeper lavender for light bg
  static const _lightTerracotta = Color(0xFFD0693C); // Slightly deeper for light bg

  // ─── Status Colors ────────────────────────────────────────────────────────
  static const _danger  = Color(0xFFFF5252);
  static const _success = Color(0xFF00E676);
  static const _warning = Color(0xFFFFB75E);

  // ─── Gradients ────────────────────────────────────────────────────────────
  static const List<List<Color>> _darkGradients = [
    [Color(0xFF00B4DB), Color(0xFF0083B0)], // Ocean blue
    [Color(0xFFFF512F), Color(0xFFDD2476)], // Coral/rose
    [Color(0xFFE8845C), Color(0xFFC96B42)], // Terracotta
    [Color(0xFF4776E6), Color(0xFF2A5298)], // Deep blue
    [Color(0xFF11998E), Color(0xFF38EF7D)], // Teal/green
    [Color(0xFFFFB75E), Color(0xFFED8F03)], // Amber
  ];

  static const List<List<Color>> _lightGradients = [
    [Color(0xFF4ACEEB), Color(0xFF42A5C9)], // Soft blue
    [Color(0xFFFF8A75), Color(0xFFE85B93)], // Soft coral/pink
    [Color(0xFFE8845C), Color(0xFFC96B42)], // Terracotta
    [Color(0xFF7B9DF0), Color(0xFF4776E6)], // Soft steel blue
    [Color(0xFF43C6B9), Color(0xFF5DF2A6)], // Soft teal/green
    [Color(0xFFFFC985), Color(0xFFF2A433)], // Soft amber
  ];

  // ─── ThemeData ─────────────────────────────────────────────────────────────
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _darkBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: _darkTextPrimary),
    ),
    colorScheme: const ColorScheme.dark(
      surface: _darkBackground,
      primary: _darkTerracotta,
      secondary: _darkSage,
    ),
    useMaterial3: true,
    extensions: const <ThemeExtension<dynamic>>[
      AppColors(
        background:    _darkBackground,
        card:          _darkCard,
        cardSecondary: _darkCardSecondary,
        textPrimary:   _darkTextPrimary,
        textSecondary: _darkTextSecondary,
        border:        _darkBorder,
        iconBg:        _darkIconBg,
        danger:        _danger,
        success:       _success,
        warning:       _warning,
        primary:       _darkTerracotta,
        secondary:     _darkSage,
        sage:          _darkSage,
        lavender:      _darkLavender,
        terracotta:    _darkTerracotta,
        blue:          const Color(0xFF64B5F6),
        gold:          const Color(0xFFFFD700),
        habitGradients: _darkGradients,
      ),
    ],
  );

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: _lightBackground,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: _lightTextPrimary),
    ),
    colorScheme: const ColorScheme.light(
      surface: _lightBackground,
      primary: _lightTerracotta,
      secondary: _lightSage,
    ),
    useMaterial3: true,
    extensions: const <ThemeExtension<dynamic>>[
      AppColors(
        background:    _lightBackground,
        card:          _lightCard,
        cardSecondary: _lightCardSecondary,
        textPrimary:   _lightTextPrimary,
        textSecondary: _lightTextSecondary,
        border:        _lightBorder,
        iconBg:        _lightIconBg,
        danger:        _danger,
        success:       _success,
        warning:       _warning,
        primary:       _lightTerracotta,
        secondary:     _lightSage,
        sage:          _lightSage,
        lavender:      _lightLavender,
        terracotta:    _lightTerracotta,
        blue:          const Color(0xFF2196F3),
        gold:          const Color(0xFFFFC107),
        habitGradients: _lightGradients,
      ),
    ],
  );
}

extension AppThemeExtension on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
