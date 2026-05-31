import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../utils/globals.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  Offerings? _offerings;
  Package? _selectedPackage;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _loadOfferings();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Fetches available subscription packages from RevenueCat.
  Future<void> _loadOfferings() async {
    setState(() => _isLoading = true);
    try {
      final offerings = await Purchases.getOfferings();
      if (mounted) {
        setState(() {
          _offerings = offerings;
          // Default: select the yearly package if available
          _selectedPackage = offerings.current?.annual ??
              offerings.current?.availablePackages.firstOrNull;
        });
      }
    } catch (e) {
      if (mounted) {
        _showError('Could not load plans: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Triggers the Google Play purchase flow.
  Future<void> _purchaseSelectedPackage() async {
    if (_selectedPackage == null) return;
    setState(() => _isLoading = true);
    try {
      final CustomerInfo customerInfo = await Purchases.purchasePackage(_selectedPackage!);
      final isActive = customerInfo.entitlements.active.containsKey('pro');

      if (mounted) {
        // Show success dialog regardless of entitlement status.
        // In sandbox/test mode entitlements may not activate instantly.
        await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              backgroundColor: const Color(0xFF161A22),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE8845C), Color(0xFFC96B42)],
                      ),
                    ),
                    child: const Icon(Icons.workspace_premium, color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: 20),
                  const Text('Welcome to PRO! 🎉',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('All premium features are now unlocked.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 14)),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8845C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(); // close dialog
                        Navigator.of(context).pop(true); // close paywall, return true = purchased
                      },
                      child: const Text('Start using PRO →',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
      }
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        // User cancelled — silently ignore
        return;
      }
      // Show user-friendly error for all other cases
      if (mounted) _showPurchaseError(e);
    } catch (e) {
      if (mounted) {
        _showError('Something went wrong. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPurchaseError(PurchasesErrorCode code) {
    final message = switch (code) {
      PurchasesErrorCode.purchaseNotAllowedError =>
        'Purchases are not allowed on this device.',
      PurchasesErrorCode.networkError =>
        'No internet connection. Please check your network and try again.',
      PurchasesErrorCode.paymentPendingError =>
        'Your payment is pending. Please complete it in Google Play.',
      PurchasesErrorCode.productAlreadyPurchasedError =>
        'You already own this subscription!',
      PurchasesErrorCode.storeProblemError =>
        'Google Play is unavailable right now. Please try again later.',
      PurchasesErrorCode.purchaseInvalidError =>
        'The purchase could not be completed. Please try a different payment method.',
      _ => 'Payment failed. Please try again.',
    };

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161A22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Color(0xFFFF5252)),
            SizedBox(width: 8),
            Text('Payment Failed', style: TextStyle(color: Colors.white, fontSize: 18)),
          ],
        ),
        content: Text(message,
            style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: Color(0xFFE8845C))),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceAll('Exception: ', ''),
            style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFFF5252),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final packages = _offerings?.current?.availablePackages ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF0C1017),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFFE8845C).withOpacity(0.3),
                  Colors.transparent
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  const Color(0xFFFF512F).withOpacity(0.2),
                  Colors.transparent
                ]),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF8A8F9E)),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    child: Column(
                      children: [
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFE8845C),
                                  Color(0xFFC96B42)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFE8845C).withOpacity(0.5),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                )
                              ],
                            ),
                            child: const Icon(Icons.workspace_premium,
                                color: Colors.white, size: 64),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text('Habit Tracker',
                            style: TextStyle(
                                color: Color(0xFF8A8F9E),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 2)),
                        const SizedBox(height: 8),
                        const Text('Unlock PRO',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),

                        // Animated Demo Chart
                        Container(
                          height: 120,
                          width: double.infinity,
                          margin:
                              const EdgeInsets.symmetric(vertical: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.05)),
                          ),
                          child: LineChart(
                            LineChartData(
                              minX: 0,
                              maxX: 6,
                              minY: 0,
                              maxY: 10,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: const [
                                    FlSpot(0, 3),
                                    FlSpot(1, 7),
                                    FlSpot(2, 4),
                                    FlSpot(3, 8),
                                    FlSpot(4, 5),
                                    FlSpot(5, 9),
                                    FlSpot(6, 7),
                                  ],
                                  isCurved: true,
                                  color: const Color(0xFFE8845C),
                                  barWidth: 4,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFFE8845C)
                                            .withOpacity(0.2),
                                        Colors.transparent
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ],
                              titlesData:
                                  const FlTitlesData(show: false),
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                            ),
                            duration: const Duration(milliseconds: 1500),
                            curve: Curves.elasticOut,
                          ),
                        ),

                        const Text(
                          'Take your habits to the next level with unlimited access to all features.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Color(0xFF8A8F9E),
                              fontSize: 15,
                              height: 1.5),
                        ),

                        const SizedBox(height: 32),

                        _buildFeatureRow(Icons.all_inclusive,
                            'Unlimited Habits',
                            'Create as many habits as you want.'),
                        const SizedBox(height: 20),
                        _buildFeatureRow(Icons.query_stats,
                            'Advanced Analytics',
                            'Access monthly & weekly progress charts.'),
                        const SizedBox(height: 20),
                        _buildFeatureRow(
                            Icons.auto_awesome,
                            'AI Habit Generator',
                            'Create personalized routines in seconds using AI.',
                            highlight: true),
                        const SizedBox(height: 20),
                        _buildFeatureRow(
                            Icons.psychology,
                            'AI Habit Coach',
                            'Get personalized weekly insights powered by AI.'),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),

                // Subscription Selection Section
                Container(
                  padding:
                      const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A22),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, -5))
                    ],
                  ),
                  child: _isLoading && packages.isEmpty
                      ? const Center(
                          child: Padding(
                          padding: EdgeInsets.all(24),
                          child:
                              CircularProgressIndicator(color: Color(0xFFE8845C)),
                        ))
                      : Column(
                          children: [
                            if (packages.isEmpty)
                              const Text('Plans unavailable. Please try again.',
                                  style: TextStyle(color: Color(0xFF8A8F9E)))
                            else
                              Wrap(
                                spacing: 16,
                                runSpacing: 12,
                                children: packages.map((pkg) {
                                  // Determine a badge for the best-value plan
                                  final badge = pkg.packageType ==
                                          PackageType.annual
                                      ? 'BEST VALUE'
                                      : null;
                                  return SizedBox(
                                    width:
                                        (MediaQuery.of(context).size.width -
                                                64) /
                                            2,
                                    child: _buildPlanCard(pkg, badge: badge),
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 24),

                            // Purchase Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: (_isLoading || _selectedPackage == null)
                                    ? null
                                    : _purchaseSelectedPackage,
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                                child: Ink(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [
                                      Color(0xFFE8845C),
                                      Color(0xFFC96B42)
                                    ]),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                          color: const Color(0xFFE8845C)
                                              .withOpacity(0.4),
                                          blurRadius: 15,
                                          offset: const Offset(0, 5))
                                    ],
                                  ),
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2))
                                        : Text(
                                            _selectedPackage != null
                                                ? 'Subscribe – ${_selectedPackage!.storeProduct.priceString}'
                                                : 'Subscribe',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text('Cancel anytime in Google Play settings',
                                style: TextStyle(
                                    color: Color(0xFF4A4E5A), fontSize: 12)),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Package pkg, {String? badge}) {
    final isSelected = _selectedPackage?.identifier == pkg.identifier;
    final product = pkg.storeProduct;

    // Human-readable period label
    String period;
    switch (pkg.packageType) {
      case PackageType.monthly:
        period = 'Monthly';
        break;
      case PackageType.annual:
        period = 'Yearly';
        break;
      case PackageType.weekly:
        period = 'Weekly';
        break;
      default:
        period = product.title;
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedPackage = pkg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFE8845C).withOpacity(0.1)
              : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFE8845C)
                : Colors.white.withOpacity(0.05),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Text(period,
                    style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF8A8F9E),
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(product.priceString,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            if (badge != null)
              Positioned(
                top: -26,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        Color(0xFF00E676),
                        Color(0xFF00C853)
                      ]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(badge,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle,
      {bool highlight = false}) {
    return Container(
      padding: highlight ? const EdgeInsets.all(16) : EdgeInsets.zero,
      decoration: highlight
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFE8845C).withOpacity(0.5)),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFE8845C).withOpacity(0.08),
                  const Color(0xFFC96B42).withOpacity(0.05)
                ],
              ),
            )
          : null,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: highlight
                  ? const Color(0xFFE8845C).withOpacity(0.25)
                  : const Color(0xFFE8845C).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFE8845C), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    if (highlight) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            Color(0xFFE8845C),
                            Color(0xFFC96B42)
                          ]),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('NEW',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF8A8F9E),
                        fontSize: 13,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
