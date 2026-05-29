import 'package:flutter/material.dart';
import '../../models/achievement.dart';
import '../../api/achievements_api_service.dart';
import '../../theme/app_theme.dart';

class AchievementsScreen extends StatelessWidget {
  final List<UserAchievementDto> unlockedAchievements;

  const AchievementsScreen({super.key, required this.unlockedAchievements});

  @override
  Widget build(BuildContext context) {
    final unlockedTypes = unlockedAchievements.map((e) => e.type).toSet();

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Achievements', style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.colors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        itemCount: allAchievements.length,
        itemBuilder: (context, index) {
          final achievement = allAchievements[index];
          final isUnlocked = unlockedTypes.contains(achievement.type);
          return _buildAchievementCard(context, achievement, isUnlocked);
        },
      ),
    );
  }

  Widget _buildAchievementCard(BuildContext context, Achievement achievement, bool isUnlocked) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked ? context.colors.secondary.withOpacity(0.5) : context.colors.border,
          width: 1.5,
        ),
        boxShadow: isUnlocked ? [
          BoxShadow(color: context.colors.secondary.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 4))
        ] : null,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isUnlocked ? LinearGradient(
                colors: [context.colors.secondary, context.colors.secondary.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ) : null,
              color: isUnlocked ? null : context.colors.iconBg,
            ),
            child: Icon(
              isUnlocked ? Icons.emoji_events : Icons.lock_outline,
              color: isUnlocked ? Colors.white : context.colors.textSecondary,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isUnlocked ? context.colors.textPrimary : context.colors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            achievement.description,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.colors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
