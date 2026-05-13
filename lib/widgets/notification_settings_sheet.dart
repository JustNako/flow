import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../api/api_service.dart';

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
      decoration: const BoxDecoration(
        color: Color(0xFF161A22),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFF262A34), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Notification Settings',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: Color(0xFFDA22FF)))
          else ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Daily Habit Reminders', style: TextStyle(color: Colors.white, fontSize: 16)),
              subtitle: const Text('Remind me to complete my habits', style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 13)),
              activeColor: const Color(0xFFDA22FF),
              value: _enabled,
              onChanged: (val) => _saveSettings(val, _frequency),
            ),
            if (_enabled) ...[
              const SizedBox(height: 16),
              const Text('Frequency', style: TextStyle(color: Colors.white, fontSize: 14)),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1017),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: Column(
                  children: [
                    RadioListTile<int>(
                      title: const Text('Once a day (Morning)', style: TextStyle(color: Colors.white, fontSize: 14)),
                      value: 1,
                      groupValue: _frequency,
                      activeColor: const Color(0xFFDA22FF),
                      onChanged: (val) {
                        if (val != null) _saveSettings(_enabled, val);
                      },
                    ),
                    Divider(height: 1, color: Colors.white.withOpacity(0.05)),
                    RadioListTile<int>(
                      title: const Text('Twice a day (Morning & Evening)', style: TextStyle(color: Colors.white, fontSize: 14)),
                      value: 2,
                      groupValue: _frequency,
                      activeColor: const Color(0xFFDA22FF),
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
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isTesting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Send Test Notification', style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
