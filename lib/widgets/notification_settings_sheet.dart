import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../api/api_service.dart';
import '../theme/app_theme.dart';

class NotificationSettingsBottomSheet extends StatefulWidget {
  const NotificationSettingsBottomSheet({super.key});

  @override
  State<NotificationSettingsBottomSheet> createState() => _NotificationSettingsBottomSheetState();
}

class _NotificationSettingsBottomSheetState extends State<NotificationSettingsBottomSheet> {
  bool _isLoading = true;
  bool _enabled = false;
  int _frequency = 1;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final token = await AuthService.instance.getToken();
      if (token != null) {
        final settings = await ApiService().getNotificationSettings(token);
        if (mounted) {
          setState(() {
            _enabled = settings['enabled'] ?? false;
            _frequency = settings['frequency'] ?? 1;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to load notification settings: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings(bool enabled, int frequency) async {
    setState(() {
      _enabled = enabled;
      _frequency = frequency;
    });
    try {
      final token = await AuthService.instance.getToken();
      if (token != null) {
        await ApiService().updateNotificationSettings(token, enabled: _enabled, frequency: _frequency);
      }
    } catch (e) {
      debugPrint('Failed to save notification settings: $e');
    }
  }

  Future<void> _sendTestNotification() async {
    setState(() => _isTesting = true);
    try {
      final token = await AuthService.instance.getToken();
      if (token != null) {
        await ApiService().sendTestNotification(token);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Test notification sent! Check your device.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString().replaceFirst('Exception: ', '')}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(28),
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
          Text('Notification Settings',
            style: TextStyle(color: context.colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Color(0xFFE8845C)))
          else ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Daily Habit Reminders', style: TextStyle(color: context.colors.textPrimary, fontSize: 16)),
              subtitle: Text('Remind me to complete my habits', style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
              activeColor: const Color(0xFFE8845C),
              value: _enabled,
              onChanged: (val) => _saveSettings(val, _frequency),
            ),
            if (_enabled) ...[
              const SizedBox(height: 16),
              Text('Frequency', style: TextStyle(color: context.colors.textPrimary, fontSize: 14)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: context.colors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colors.border),
                ),
                child: Column(
                  children: [
                    RadioListTile<int>(
                      title: Text('Once a day (Morning)', style: TextStyle(color: context.colors.textPrimary, fontSize: 14)),
                      value: 1,
                      groupValue: _frequency,
                      activeColor: const Color(0xFFE8845C),
                      onChanged: (val) {
                        if (val != null) _saveSettings(_enabled, val);
                      },
                    ),
                    Divider(height: 1, color: context.colors.border),
                    RadioListTile<int>(
                      title: Text('Twice a day (Morning & Evening)', style: TextStyle(color: context.colors.textPrimary, fontSize: 14)),
                      value: 2,
                      groupValue: _frequency,
                      activeColor: const Color(0xFFE8845C),
                      onChanged: (val) {
                        if (val != null) _saveSettings(_enabled, val);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isTesting ? null : _sendTestNotification,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.colors.border),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isTesting
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.textPrimary))
                : Text('Send Test Notification', style: TextStyle(color: context.colors.textPrimary)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
