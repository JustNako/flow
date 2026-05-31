import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_service.dart';

class UpdateService {
  static const _keyAndroid = 'rc_api_key_android';
  static const _keyIOS    = 'rc_api_key_ios';

  /// Returns the cached RevenueCat key for the current platform,
  /// falling back to [fallback] when no key has been fetched yet.
  static Future<String> getCachedRevenueCatKey(String fallback) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = Platform.isAndroid
        ? prefs.getString(_keyAndroid)
        : prefs.getString(_keyIOS);
    return (cached != null && cached.isNotEmpty) ? cached : fallback;
  }

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final appInfo = await PackageInfo.fromPlatform();
      final currentVersion = _parseVersion(appInfo.version);
      
      final remoteConfig = await ApiService().checkAppVersion();
      if (remoteConfig.isEmpty) return;

      // Persist the RevenueCat keys for use on the next app launch
      final prefs = await SharedPreferences.getInstance();
      final rcAndroid = remoteConfig['revenueCatApiKeyAndroid'] as String?;
      final rcIOS     = remoteConfig['revenueCatApiKeyIOS'] as String?;
      if (rcAndroid != null && rcAndroid.isNotEmpty) {
        await prefs.setString(_keyAndroid, rcAndroid);
      }
      if (rcIOS != null && rcIOS.isNotEmpty) {
        await prefs.setString(_keyIOS, rcIOS);
      }

      final latestVersion     = _parseVersion(remoteConfig['latestVersion']     ?? "1.0.0");
      final minRequiredVersion = _parseVersion(remoteConfig['minRequiredVersion'] ?? "1.0.0");
      
      final url = Platform.isAndroid 
          ? remoteConfig['updateUrlAndroid'] 
          : remoteConfig['updateUrlIOS'];

      if (currentVersion < minRequiredVersion) {
        if (!context.mounted) return;
        _showUpdateDialog(context, url, isForceUpdate: true);
      } else if (currentVersion < latestVersion) {
        if (!context.mounted) return;
        _showUpdateDialog(context, url, isForceUpdate: false);
      }
    } catch (e) {
      debugPrint("Update check failed: $e");
    }
  }

  static int _parseVersion(String version) {
    // Converts "1.0.5" to 10005 for easy comparison
    final parts = version.split('.');
    if (parts.length != 3) return 0;
    try {
      final major = int.parse(parts[0]) * 10000;
      final minor = int.parse(parts[1]) * 100;
      final patch = int.parse(parts[2]);
      return major + minor + patch;
    } catch (e) {
      return 0;
    }
  }

  static void _showUpdateDialog(BuildContext context, String? url, {required bool isForceUpdate}) {
    showDialog(
      context: context,
      barrierDismissible: !isForceUpdate,
      builder: (context) => PopScope(
        canPop: !isForceUpdate,
        child: AlertDialog(
          backgroundColor: const Color(0xFF161A22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isForceUpdate ? 'Critical Update Required' : 'Update Available',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            isForceUpdate 
                ? 'Your version of Flow is no longer supported. Please update to continue building habits.'
                : 'A new version of Flow is available with new features and bug fixes. Would you like to update?',
            style: const TextStyle(color: Color(0xFF8A8F9E)),
          ),
          actions: [
            if (!isForceUpdate)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later', style: TextStyle(color: Colors.white54)),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE8845C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (url != null && await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Update Now', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
