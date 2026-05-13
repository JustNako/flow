import 'package:flutter/material.dart';
import '../../models/achievement.dart';
import '../../api/achievements_api_service.dart';

class AchievementsScreen extends StatelessWidget {
  final List<UserAchievementDto> unlockedAchievements;

  const AchievementsScreen({super.key, required this.unlockedAchievements});

  @override
  Widget build(BuildContext context) {
    final unlockedTypes = unlockedAchievements.map((e) => e.type).toSet();

    return Scaffold(
      backgroundColor: const Color(0xFF0C1017),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Achievements', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
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
          return _buildAchievementCard(achievement, isUnlocked);
        },
      ),
    );
  }

  Widget _buildAchievementCard(Achievement achievement, bool isUnlocked) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked ? const Color(0xFFDA22FF).withOpacity(0.5) : const Color(0xFF262A34),
          width: 1.5,
        ),
        boxShadow: isUnlocked ? [
          BoxShadow(color: const Color(0xFFDA22FF).withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 4))
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
              gradient: isUnlocked ? const LinearGradient(
                colors: [Color(0xFFDA22FF), Color(0xFF9733EE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ) : null,
              color: isUnlocked ? null : const Color(0xFF262A34),
            ),
            child: Icon(
              isUnlocked ? Icons.emoji_events : Icons.lock_outline,
              color: isUnlocked ? Colors.white : const Color(0xFF8A8F9E),
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            achievement.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isUnlocked ? Colors.white : const Color(0xFF8A8F9E),
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
            style: const TextStyle(
              color: Color(0xFF8A8F9E),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
