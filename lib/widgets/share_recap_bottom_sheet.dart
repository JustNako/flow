import 'package:flutter/material.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';
import 'recap_share_card.dart';

class ShareRecapBottomSheet extends StatefulWidget {
  final String monthName;
  final int totalRate;
  final int totalCompletions;
  final String? bestHabit;
  final String badgeLabel;
  final Map<String, dynamic> recap;
  final int bestStreak;

  const ShareRecapBottomSheet({
    super.key,
    required this.monthName,
    required this.totalRate,
    required this.totalCompletions,
    required this.bestHabit,
    required this.badgeLabel,
    required this.recap,
    this.bestStreak = 0,
  });

  @override
  State<ShareRecapBottomSheet> createState() => _ShareRecapBottomSheetState();
}

class _ShareRecapBottomSheetState extends State<ShareRecapBottomSheet> {
  bool _isSharing = false;

  Future<void> _shareImage() async {
    setState(() => _isSharing = true);
    try {
      // Build the share card with the active colors passed explicitly
      final shareCard = RecapShareCard(
        data: MonthlyRecapData(
          monthName: widget.monthName,
          successRate: widget.totalRate,
          totalCompleted: widget.totalCompletions,
          starHabit: widget.bestHabit ?? 'None',
          bestStreak: widget.bestStreak,
          badgeLabel: widget.badgeLabel,
        ),
      );

      await ShareService.instance.shareWidgetAsImage(
        widget: shareCard,
        fileName: 'Flow_Recap_${widget.monthName.replaceAll(' ', '_')}',
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share image: $e'),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _sharePdf() async {
    setState(() => _isSharing = true);
    try {
      await ShareService.instance.shareMonthlyPdfReport(recap: widget.recap);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share PDF: $e'),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            'Share Monthly Recap',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how you would like to share your monthly progress.',
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          if (_isSharing)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: context.colors.secondary),
                    const SizedBox(height: 16),
                    Text(
                      'Generating document...',
                      style: TextStyle(
                        color: context.colors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            _buildShareOption(
              icon: Icons.image_outlined,
              title: 'Share as Image',
              subtitle: 'A clean summary card for social sharing',
              onTap: _shareImage,
            ),
            const SizedBox(height: 12),
            _buildShareOption(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Share as PDF Report',
              subtitle: 'A detailed report with all habit stats',
              onTap: _sharePdf,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.colors.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colors.iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: context.colors.textPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: context.colors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
