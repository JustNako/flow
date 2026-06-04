import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

const _kBg = Color(0xFF1A1A1A);
const _kCard = Color(0xFF242424);
const _kCardBorder = Color(0xFF2E2E2E);
const _kSage = Color(0xFF8BA888);
const _kLavender = Color(0xFF9F92C6);
const _kText = Color(0xFFE8E8E8);
const _kTextSub = Color(0xFF888888);

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = false;
  Offerings? _offerings;
  Package? _selectedPackage;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
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
      await Purchases.purchasePackage(_selectedPackage!);

      if (mounted) {
        // Show success dialog regardless of entitlement status.
        await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              backgroundColor: _kCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_kLavender, _kSage],
                      ),
                    ),
                    child: const Icon(Icons.workspace_premium, color: Colors.white, size: 48),
                  ),
                  const SizedBox(height: 20),
                  Text('Welcome to PRO! 🎉',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('All premium features are now unlocked.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: _kTextSub, fontSize: 14)),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [_kLavender, _kSage],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _kSage.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.of(context).pop(); // close dialog
                          Navigator.of(context).pop(true); // close paywall, return true = purchased
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Start using PRO',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
      }
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        return;
      }
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
      PurchasesErrorCode.purchaseNotAllowedError => 'Purchases are not allowed on this device.',
      PurchasesErrorCode.networkError => 'No internet connection. Please check your network and try again.',
      PurchasesErrorCode.paymentPendingError => 'Your payment is pending. Please complete it in Google Play.',
      PurchasesErrorCode.productAlreadyPurchasedError => 'You already own this subscription!',
      PurchasesErrorCode.storeProblemError => 'Google Play is unavailable right now. Please try again later.',
      PurchasesErrorCode.purchaseInvalidError => 'The purchase could not be completed. Please try a different payment method.',
      _ => 'Payment failed. Please try again.',
    };

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFFF5252)),
            const SizedBox(width: 8),
            Text('Payment Failed', style: GoogleFonts.inter(color: _kText, fontSize: 18)),
          ],
        ),
        content: Text(message, style: GoogleFonts.inter(color: _kTextSub, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: GoogleFonts.inter(color: _kSage)),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceAll('Exception: ', ''), style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: const Color(0xFFFF5252),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final packages = _offerings?.current?.availablePackages ?? [];

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // Ambient Glow Background
          Positioned(
            top: -150,
            left: 0,
            right: 0,
            child: Container(
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _kLavender.withOpacity(0.12),
                    _kSage.withOpacity(0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Top Action Bar
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: _kCard,
                        shape: BoxShape.circle,
                        border: Border.all(color: _kCardBorder),
                      ),
                      child: const Icon(Icons.close_rounded, color: _kTextSub, size: 18),
                    ),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        
                        // "FLOW PRO" Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _kLavender.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _kLavender.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, color: _kLavender, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'FLOW PRO',
                                style: GoogleFonts.inter(
                                  color: _kLavender,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Title
                        Text(
                          'Deepen Your\nPractice',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.playfairDisplay(
                            color: _kText,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Subtitle
                        Text(
                          'Everything you need to build habits\nthat actually last.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: _kTextSub,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Bento Grid Features
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Feature 1: Unlimited Habits
                            Expanded(
                              child: _buildBentoFeature(
                                icon: Icons.all_inclusive_rounded,
                                iconColor: _kSage,
                                title: 'Unlimited Habits',
                                subtitle: 'Track as many habits as you want, no limits.',
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Feature 2: AI Habit Generator
                            Expanded(
                              child: _buildBentoFeature(
                                icon: Icons.auto_awesome_rounded,
                                iconColor: _kLavender,
                                title: 'AI Habit Generator',
                                subtitle: '5 personalized sparks every day.',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Feature 3: AI Habit Coach
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _kCard,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: _kLavender.withOpacity(0.15)),
                            boxShadow: [
                              BoxShadow(
                                color: _kLavender.withOpacity(0.03),
                                blurRadius: 20,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _kLavender.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: _kLavender.withOpacity(0.2)),
                                    ),
                                    child: const Icon(Icons.psychology_rounded, color: _kLavender, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Text(
                                          'AI Habit Coach',
                                          style: GoogleFonts.inter(
                                            color: _kText,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _kLavender.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'NEW',
                                            style: GoogleFonts.inter(
                                              color: _kLavender,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'A mindful AI that understands your patterns, offers gentle nudges, and celebrates your wins — like a coach who truly knows you.',
                                style: GoogleFonts.inter(
                                  color: _kTextSub,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildCoachListItem('Daily personalized check-ins'),
                              const SizedBox(height: 12),
                              _buildCoachListItem('Pattern recognition & insights'),
                              const SizedBox(height: 12),
                              _buildCoachListItem('Adaptive streaks & gentle reminders'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Subscription Tiers
                        if (_isLoading && packages.isEmpty)
                          const Center(child: CircularProgressIndicator(color: _kSage))
                        else if (packages.isEmpty)
                          Text('Plans unavailable. Please try again.', style: GoogleFonts.inter(color: _kTextSub))
                        else
                          Column(
                            children: packages.map((pkg) => _buildPlanOption(pkg, packages)).toList(),
                          ),

                        const SizedBox(height: 24),

                        // Main Subscribe Button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: const LinearGradient(
                              colors: [_kLavender, _kSage],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _kSage.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: (_isLoading || _selectedPackage == null) ? null : _purchaseSelectedPackage,
                              borderRadius: BorderRadius.circular(24),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Center(
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24, height: 24,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Unlock Flow Pro',
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontSize: 17,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Cancel anytime. No commitment.',
                          style: GoogleFonts.inter(
                            color: _kTextSub.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBentoFeature({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: iconColor.withOpacity(0.2)),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.inter(
              color: _kText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              color: _kTextSub,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachListItem(String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _kLavender.withOpacity(0.15),
          ),
          child: const Icon(Icons.check_rounded, color: _kLavender, size: 12),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: _kTextSub,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanOption(Package pkg, List<Package> allPackages) {
    final isSelected = _selectedPackage?.identifier == pkg.identifier;
    final product = pkg.storeProduct;

    String period;
    String? subtitle;
    String? badge;

    switch (pkg.packageType) {
      case PackageType.monthly:
        period = 'Monthly';
        subtitle = 'per month';
        break;
      case PackageType.annual:
        period = 'Annual';
        subtitle = 'billed ${product.priceString}/yr';
        
        // Dynamically calculate savings compared to monthly plan
        final monthlyPkg = allPackages.where((p) => p.packageType == PackageType.monthly).firstOrNull;
        if (monthlyPkg != null && monthlyPkg.storeProduct.price > 0) {
          final annualPrice = product.price;
          final monthlyPrice = monthlyPkg.storeProduct.price;
          final yearlyCostWithMonthly = monthlyPrice * 12;
          if (annualPrice < yearlyCostWithMonthly) {
            final savings = ((1 - (annualPrice / yearlyCostWithMonthly)) * 100).round();
            badge = 'Save $savings%';
          }
        }
        break;
      case PackageType.weekly:
        period = 'Weekly';
        subtitle = 'per week';
        break;
      default:
        period = product.title;
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedPackage = pkg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected ? _kCard : _kBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? _kLavender : _kCardBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Radio Button
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _kLavender : _kTextSub.withOpacity(0.3),
                  width: isSelected ? 6 : 1.5,
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Plan Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      Text(
                        period,
                        style: GoogleFonts.inter(
                          color: _kText,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _kLavender.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge,
                            style: GoogleFonts.inter(
                              color: _kLavender,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: _kTextSub,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Price
            Text(
              product.priceString,
              style: GoogleFonts.inter(
                color: _kText,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
