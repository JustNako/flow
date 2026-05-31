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
      habitGradients: t < 0.5 ? habitGradients : other.habitGradients,
    );
  }
}

class AppTheme {
  // Original Dark Theme Colors
  static const _darkBackground = Color(0xFF0C1017);
  static const _darkCard = Color(0xFF161A22);
  static const _darkCardSecondary = Color(0xFF0F1218); // for 'other' habits
  static const _darkTextPrimary = Colors.white;
  static const _darkTextSecondary = Color(0xFF8A8F9E);
  static const _darkBorder = Color(0xFF2A2E3A); // Slightly lighter than background for visibility
  static const _darkIconBg = Color(0xFF1E2230);
  
  // New Light Theme Colors (Off-white / cream premium paper style)
  static const _lightBackground = Color(0xFFF9F9F6); // Soft off-white cream
  static const _lightCard = Color(0xFFFFFFFF); // Clean white for cards
  static const _lightCardSecondary = Color(0xFFF0F0ED); // Slightly darker cream for 'other' habits
  static const _lightTextPrimary = Color(0xFF1E2230); // Very dark gray/navy, softer than black
  static const _lightTextSecondary = Color(0xFF7A7E8D);
  static const _lightBorder = Color(0xFFE5E5E0);
  static const _lightIconBg = Color(0xFFF0F0ED);

  // Status colors
  static const _danger = Color(0xFFFF5252);
  static const _success = Color(0xFF00E676);
  static const _warning = Color(0xFFFFB75E);

  // Zen-aligned gradients for Dark Mode
  static const List<List<Color>> _darkGradients = [
    [Color(0xFF00B4DB), Color(0xFF0083B0)], // Ocean blue
    [Color(0xFFFF512F), Color(0xFFDD2476)], // Coral/rose
    [Color(0xFFE8845C), Color(0xFFC96B42)], // Terracotta
    [Color(0xFF4776E6), Color(0xFF2A5298)], // Deep blue
    [Color(0xFF11998E), Color(0xFF38EF7D)], // Teal/green
    [Color(0xFFFFB75E), Color(0xFFED8F03)], // Amber
  ];

  // Softer pastel gradients for Light Mode
  static const List<List<Color>> _lightGradients = [
    [Color(0xFF4ACEEB), Color(0xFF42A5C9)], // Soft blue
    [Color(0xFFFF8A75), Color(0xFFE85B93)], // Soft coral/pink
    [Color(0xFFE8845C), Color(0xFFC96B42)], // Terracotta
    [Color(0xFF7B9DF0), Color(0xFF4776E6)], // Soft steel blue
    [Color(0xFF43C6B9), Color(0xFF5DF2A6)], // Soft teal/green
    [Color(0xFFFFC985), Color(0xFFF2A433)], // Soft amber
  ];

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
      primary: Color(0xFFFF512F),
      secondary: Color(0xFFE8845C),
    ),
    useMaterial3: true,
    extensions: const <ThemeExtension<dynamic>>[
      AppColors(
        background: _darkBackground,
        card: _darkCard,
        cardSecondary: _darkCardSecondary,
        textPrimary: _darkTextPrimary,
        textSecondary: _darkTextSecondary,
        border: _darkBorder,
        iconBg: _darkIconBg,
        danger: _danger,
        success: _success,
        warning: _warning,
        primary: const Color(0xFFFF512F),
        secondary: const Color(0xFFE8845C),
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
      primary: Color(0xFFFF512F),
      secondary: Color(0xFFE8845C),
    ),
    useMaterial3: true,
    extensions: const <ThemeExtension<dynamic>>[
      AppColors(
        background: _lightBackground,
        card: _lightCard,
        cardSecondary: _lightCardSecondary,
        textPrimary: _lightTextPrimary,
        textSecondary: _lightTextSecondary,
        border: _lightBorder,
        iconBg: _lightIconBg,
        danger: _danger,
        success: _success,
        warning: _warning,
        primary: const Color(0xFFFF512F),
        secondary: const Color(0xFFE8845C),
        habitGradients: _lightGradients,
      ),
    ],
  );
}

extension AppThemeExtension on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
