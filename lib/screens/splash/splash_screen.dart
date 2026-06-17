import 'dart:io';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../api/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/local_database.dart';
import '../../services/offline_manager.dart';
import '../../services/notification_service.dart';
import '../../services/time_tracking_service.dart';
import '../../services/update_service.dart';
import '../../services/widget_service.dart';
import '../onboarding/onboarding_screen.dart';
import '../auth/login_screen.dart';
import '../main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  String _statusText = 'Starting Flow...';
  double _progress = 0.0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _forceUpdateRequired = false;
  String _updateUrl = '';

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initialize();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    // 1. Initialize DB
    _updateStatus('Initializing database...', 0.15);
    await LocalDatabase.instance.init();
    
    // 2. Initialize OfflineManager
    _updateStatus('Connecting local services...', 0.3);
    await OfflineManager.instance.init();
    
    // 3. Initialize Firebase Notifications
    _updateStatus('Securing notification bridge...', 0.45);
    try {
      await NotificationService.instance.initialize();
    } catch (e) {
      debugPrint('Firebase init error (skipped): $e');
    }
    
    // 4. Checking Version & Fetching API Keys
    _updateStatus('Checking for updates...', 0.65);
    final String defaultFallback = Platform.isAndroid 
        ? 'goog_KHTlxqdaYEYzpbpWLuwosZpuDbK' 
        : 'appl_placeholder_ios_api_key';
    
    // Always load cached key first to ensure offline-first safety
    String rcApiKey = await UpdateService.getCachedRevenueCatKey(defaultFallback);
    
    try {
      final remoteConfig = await ApiService().checkAppVersion().timeout(const Duration(seconds: 3));
      if (remoteConfig.isNotEmpty) {
        // Save RevenueCat keys to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final rcAndroid = remoteConfig['revenueCatApiKeyAndroid'] as String?;
        final rcIOS     = remoteConfig['revenueCatApiKeyIOS'] as String?;
        if (rcAndroid != null && rcAndroid.isNotEmpty) {
          await prefs.setString('rc_api_key_android', rcAndroid);
        }
        if (rcIOS != null && rcIOS.isNotEmpty) {
          await prefs.setString('rc_api_key_ios', rcIOS);
        }
        rcApiKey = await UpdateService.getCachedRevenueCatKey(defaultFallback);

        // Perform dynamic startup version check (for force updates)
        final appInfo = await PackageInfo.fromPlatform();
        final currentVersion = _parseVersion(appInfo.version);
        final minRequiredVersion = _parseVersion(remoteConfig['minRequiredVersion'] ?? "1.0.0");
        
        if (currentVersion < minRequiredVersion) {
          setState(() {
            _forceUpdateRequired = true;
            _updateUrl = Platform.isAndroid 
                ? (remoteConfig['updateUrlAndroid'] ?? '') 
                : (remoteConfig['updateUrlIOS'] ?? '');
          });
          return; // Stop initialization flow and show force update screen
        }
      }
    } catch (e) {
      debugPrint('Version check failed (proceeding): $e');
    }

    // 5. Config Billing
    _updateStatus('Configuring premium features...', 0.8);
    try {
      await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.configure(PurchasesConfiguration(rcApiKey));
    } catch (e) {
      debugPrint('RevenueCat configuration error (skipped): $e');
    }
    
    // 6. Time tracker
    _updateStatus('Securing habit logs...', 0.95);
    await TimeTrackingService.instance.initialize();
    
    // 7. Complete & Route
    _updateStatus('Welcome to Flow', 1.0);
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final onboarded = prefs.getBool('onboarded') ?? false;
    final token = await AuthService.instance.getToken();
    
    // If logged in, sync widget data in background (don't await ? fire and forget)
    if (token != null) {
      WidgetService.updateWidget();
    }
    
    Widget destination;
    if (token != null) {
      destination = const MainScreen();
    } else if (!onboarded) {
      destination = const OnboardingScreen();
    } else {
      destination = const LoginScreen();
    }
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _updateStatus(String text, double progress) {
    if (mounted) {
      setState(() {
        _statusText = text;
        _progress = progress;
      });
    }
  }

  int _parseVersion(String version) {
    final parts = version.split('.');
    if (parts.length != 3) return 0;
    try {
      final major = int.parse(parts[0]) * 10000;
      final minor = int.parse(parts[1]) * 100;
      final patch = int.parse(parts[2]);
      return major + minor + patch;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          // Premium subtle background gradients
          Positioned(
            top: -150,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.terracotta.withOpacity(0.08),
                backgroundBlendMode: BlendMode.screen,
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            right: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.colors.terracotta.withOpacity(0.08),
                backgroundBlendMode: BlendMode.screen,
              ),
            ),
          ),
          
          if (_forceUpdateRequired)
            _buildForceUpdateScreen()
          else
            _buildSplashLoader(),
        ],
      ),
    );
  }

  Widget _buildSplashLoader() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            
            // Glowing Premium Logo Animation
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: context.colors.terracotta.withOpacity(0.15),
                      blurRadius: 35,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(70),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // App Name
            Text(
              'FLOW',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: context.colors.textPrimary,
              ),
            ),
            
            const Spacer(flex: 2),
            
            // Dynamic premium linear progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 4,
                width: 160,
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: context.colors.card,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE8845C)),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Dynamic status text
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _statusText,
                key: ValueKey<String>(_statusText),
                style: const TextStyle(
                  color: Color(0xFF8A8F9E),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildForceUpdateScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF3366).withOpacity(0.15),
              ),
              child: const Icon(
                Icons.system_update_rounded,
                size: 64,
                color: Color(0xFFFF3366),
              ),
            ),
            
            const SizedBox(height: 32),
            
            Text(
              'Update Required',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: context.colors.textPrimary,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Your version of Flow is no longer supported.\nPlease update to continue building premium habits.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF8A8F9E),
                fontSize: 15,
                height: 1.5,
              ),
            ),
            
            const SizedBox(height: 40),
            
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.terracotta,
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 5,
                shadowColor: context.colors.terracotta.withOpacity(0.4),
              ),
              onPressed: () async {
                final fallbackUrl = Platform.isAndroid 
                    ? 'https://play.google.com/store/apps/details?id=com.codex.flow'
                    : 'https://apps.apple.com/app/id1234567890';
                final urlStr = _updateUrl.isNotEmpty ? _updateUrl : fallbackUrl;
                final uri = Uri.parse(urlStr);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Text(
                'Update Now',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
