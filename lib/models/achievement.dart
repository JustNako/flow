class Achievement {
  final String type;
  final String title;
  final String description;
  final String iconAsset; // Or use IconData later
  final bool isUnlocked;
  final DateTime? unlockedAt;

  Achievement({
    required this.type,
    required this.title,
    required this.description,
    required this.iconAsset,
    required this.isUnlocked,
    this.unlockedAt,
  });
}

// A helper list to define all available achievements in the UI
final List<Achievement> allAchievements = [
  Achievement(
    type: 'FirstHabitCreated',
    title: 'First Step',
    description: 'Create your very first habit.',
    iconAsset: 'assets/achievements/first_step.png', // Fallback to icons later
    isUnlocked: false,
  ),
  Achievement(
    type: 'FirstHabitCompleted',
    title: 'Action Taker',
    description: 'Complete a habit for the first time.',
    iconAsset: 'assets/achievements/action_taker.png',
    isUnlocked: false,
  ),
  Achievement(
    type: 'SevenDayStreak',
    title: '7-Day Streak',
    description: 'Maintain a 7-day global streak.',
    iconAsset: 'assets/achievements/streak_7.png',
    isUnlocked: false,
  ),
  Achievement(
    type: 'ThirtyDayStreak',
    title: '30-Day Streak',
    description: 'Maintain a 30-day global streak.',
    iconAsset: 'assets/achievements/streak_30.png',
    isUnlocked: false,
  ),
  Achievement(
    type: 'HundredDayStreak',
    title: 'Centurion',
    description: 'Maintain an incredible 100-day streak.',
    iconAsset: 'assets/achievements/streak_100.png',
    isUnlocked: false,
  ),
  Achievement(
    type: 'FirstPublicHabit',
    title: 'Going Public',
    description: 'Create a public habit to share with friends.',
    iconAsset: 'assets/achievements/public_habit.png',
    isUnlocked: false,
  ),
  Achievement(
    type: 'FirstFriendAdded',
    title: 'Social Butterfly',
    description: 'Add your first friend.',
    iconAsset: 'assets/achievements/friend_1.png',
    isUnlocked: false,
  ),
  Achievement(
    type: 'TenFriendsAdded',
    title: 'Popular',
    description: 'Connect with 10 friends.',
    iconAsset: 'assets/achievements/friend_10.png',
    isUnlocked: false,
  ),
  Achievement(
    type: 'FiftyFriendsAdded',
    title: 'Influencer',
    description: 'Connect with 50 friends.',
    iconAsset: 'assets/achievements/friend_50.png',
    isUnlocked: false,
  ),
  Achievement(
    type: 'HundredFriendsAdded',
    title: 'Leader',
    description: 'Connect with 100 friends.',
    iconAsset: 'assets/achievements/friend_100.png',
    isUnlocked: false,
  ),
];
