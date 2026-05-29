import 'package:flutter/material.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Text('Settings', style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.colors.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionTitle('Appearance'),
          const SizedBox(height: 12),
          _buildThemeSelector(),
          const SizedBox(height: 32),
          _buildSectionTitle('Account'),
          const SizedBox(height: 12),
          // More settings can go here in the future
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: context.colors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildThemeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          _buildThemeOption(
            title: 'System Default',
            icon: Icons.brightness_auto,
            mode: ThemeMode.system,
          ),
          Divider(height: 1, color: context.colors.border),
          _buildThemeOption(
            title: 'Light',
            icon: Icons.light_mode,
            mode: ThemeMode.light,
          ),
          Divider(height: 1, color: context.colors.border),
          _buildThemeOption(
            title: 'Dark',
            icon: Icons.dark_mode,
            mode: ThemeMode.dark,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption({
    required String title,
    required IconData icon,
    required ThemeMode mode,
  }) {
    final isSelected = ThemeService.instance.themeMode == mode;
    return ListTile(
      onTap: () {
        ThemeService.instance.setThemeMode(mode);
        setState(() {}); // refresh the checkmark
      },
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.colors.iconBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: context.colors.textPrimary, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: context.colors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: context.colors.success)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
