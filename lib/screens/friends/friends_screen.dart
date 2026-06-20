import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../api/friends_api_service.dart';
import '../../theme/app_theme.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  Color get _kBg => context.colors.background;
  Color get _kCard => context.colors.card;
  Color get _kCardBorder => context.colors.border;
  Color get _kSage => context.colors.sage;
  Color get _kLavender => context.colors.lavender;
  Color get _kTerra => context.colors.terracotta;
  Color get _kText => context.colors.textPrimary;
  Color get _kTextSub => context.colors.textSecondary;
  final _api = FriendsApiService();

  String? _myCode;
  List<FriendDto> _friends = [];
  List<FriendRequestDto> _requests = [];
  List<SuggestedUserDto> _suggestions = [];
  final Set<String> _sentSuggestionRequestIds = {};
  final Set<String> _sendingSuggestionRequestIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getMyCode(),
        _api.getFriends(),
        _api.getPendingRequests(),
        _api.getSuggestions(),
      ]);
      if (mounted) {
        setState(() {
          _myCode = results[0] as String;
          _friends = results[1] as List<FriendDto>;
          _requests = results[2] as List<FriendRequestDto>;
          _suggestions = results[3] as List<SuggestedUserDto>;
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  Future<void> _acceptRequest(FriendRequestDto req) async {
    try {
      await _api.acceptRequest(req.friendshipId);
      _showSnack('Now friends with ${req.requesterName}! 🤝', success: true);
      await _load();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _remove(String friendshipId) async {
    try {
      await _api.removeFriend(friendshipId);
      await _load();
    } catch (_) {}
  }

  void _showSnack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: success ? _kSage : _kTerra,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _getStatus(int streak) {
    if (streak == 0) return 'Taking it slow today';
    if (streak < 3) return 'Starting fresh';
    if (streak < 7) return 'Staying consistent';
    return 'On a roll!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: _isLoading
            ? Center(child: CircularProgressIndicator(color: _kSage))
            : RefreshIndicator(
                onRefresh: _load,
                color: _kSage,
                backgroundColor: _kCard,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Text(
                        'YOUR CIRCLE',
                        style: GoogleFonts.inter(
                          color: _kTextSub,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Community',
                            style: GoogleFonts.playfairDisplay(
                              color: _kText,
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _kCardBorder.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _kCardBorder),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: _kSage,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_friends.length} friends',
                                  style: TextStyle(color: _kTextSub, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Bento Grid Top
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _buildInviteCard(),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildAddFriendCard(),
                            ),
                          ],
                        ),
                      ),

                      // Friend Suggestions (People You May Know)
                      if (_suggestions.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        Text(
                          'PEOPLE YOU MAY KNOW',
                          style: GoogleFonts.inter(
                            color: _kTextSub,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: _suggestions.length,
                            itemBuilder: (context, index) {
                              final user = _suggestions[index];
                              return _buildSuggestionCard(user);
                            },
                          ),
                        ),
                      ],

                      // Pending Requests
                      if (_requests.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _kLavender.withOpacity(0.7),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_requests.length} PERSON WANTS TO JOIN YOUR FLOW',
                              style: TextStyle(
                                color: _kLavender,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ..._requests.map((r) => _buildRequestCard(r)),
                      ],

                      const SizedBox(height: 32),
                      
                      // Network Header
                      Text(
                        'Your flow network',
                        style: GoogleFonts.playfairDisplay(
                          color: _kText,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Friends List
                      if (_friends.isEmpty)
                        _buildEmptyState()
                      else
                        ..._friends.map((f) => _buildFriendCard(f)),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildInviteCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: _kSage, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text('YOUR INVITE', style: TextStyle(color: _kSage, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            _myCode?.replaceFirst('-', '-\n') ?? '—',
            style: GoogleFonts.robotoMono(
              color: _kText,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Share with someone you\ncare about',
            style: TextStyle(color: _kTextSub, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          Divider(color: _kCardBorder),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _myCode ?? ''));
              _showSnack('Code copied!', success: true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kCardBorder),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.copy_rounded, color: _kTextSub, size: 14),
                    const SizedBox(width: 8),
                    Text('Copy code', style: TextStyle(color: _kTextSub, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddFriendCard() {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: _kBg,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          builder: (_) => _AddFriendSheet(onAdd: (code) => _api.sendRequest(code).then((_) => _load())),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _kCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kCardBorder,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_add_alt_1_rounded, color: _kSage, size: 22),
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Add Friend', style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Connect using their unique code', style: TextStyle(color: _kTextSub, fontSize: 12, height: 1.3)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: _kCardBorder.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kCardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Enter code', style: TextStyle(color: _kTextSub, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, color: _kTextSub, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendSuggestionRequest(SuggestedUserDto user) async {
    if (_sendingSuggestionRequestIds.contains(user.id) || _sentSuggestionRequestIds.contains(user.id)) return;
    setState(() {
      _sendingSuggestionRequestIds.add(user.id);
    });
    try {
      await _api.sendRequestById(user.id);
      if (mounted) {
        setState(() {
          _sentSuggestionRequestIds.add(user.id);
        });
        _showSnack('Friend request sent to ${user.userName}! 🎉', success: true);
      }
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _sendingSuggestionRequestIds.remove(user.id);
        });
      }
    }
  }

  Widget _buildSuggestionCard(SuggestedUserDto user) {
    final isSent = _sentSuggestionRequestIds.contains(user.id);
    final isSending = _sendingSuggestionRequestIds.contains(user.id);

    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF16161A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar wrapped in muted gradient border
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  _kSage.withOpacity(0.4),
                  _kLavender.withOpacity(0.4),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFF222227),
              child: Text(
                user.userName.isNotEmpty ? user.userName.substring(0, 1).toUpperCase() : '?',
                style: GoogleFonts.inter(
                  color: const Color(0xFFF5F5F5),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Name
          Text(
            user.userName,
            style: GoogleFonts.inter(
              color: const Color(0xFFF5F5F5),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),
          // Add/Sent circular button
          GestureDetector(
            onTap: (isSent || isSending) ? null : () => _sendSuggestionRequest(user),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSent ? const Color(0xFF222227) : const Color(0xFF1B261F),
                border: Border.all(
                  color: isSent ? Colors.white.withOpacity(0.05) : const Color(0xFF2E3E34).withOpacity(0.4),
                ),
              ),
              child: Center(
                child: isSending
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: Color(0xFF81C784),
                          strokeWidth: 1.5,
                        ),
                      )
                    : Icon(
                        isSent ? Icons.check_rounded : Icons.person_add_rounded,
                        color: isSent ? const Color(0xFF9CA3AF) : const Color(0xFF81C784),
                        size: 16,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(FriendRequestDto req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kCardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_kLavender.withOpacity(0.3), _kTerra.withOpacity(0.3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: _kLavender.withOpacity(0.2)),
            ),
            child: Center(
              child: Text(
                req.requesterName.isNotEmpty ? req.requesterName[0].toUpperCase() : '?',
                style: TextStyle(color: _kText, fontSize: 20, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(text: req.requesterName, style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 16, fontWeight: FontWeight.bold)),
                      TextSpan(text: ' wants to join your flow', style: TextStyle(color: _kTextSub, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text('They heard Flow brings calm', style: TextStyle(color: _kTextSub, fontSize: 12)),
                const SizedBox(height: 16),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _acceptRequest(req),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: _kSage.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _kSage.withOpacity(0.3)),
                        ),
                        child: Text('Accept', style: TextStyle(color: _kSage, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _remove(req.friendshipId),
                      child: Text('Maybe later', style: TextStyle(color: _kTextSub, fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFriendDetails(FriendDto friend) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (_) => _FriendDetailsSheet(friend: friend),
    );
  }

  Widget _buildFriendCard(FriendDto friend) {
    return GestureDetector(
      onTap: () => _showFriendDetails(friend),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _kCardBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          Stack(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_kSage.withOpacity(0.3), context.colors.blue.withOpacity(0.3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    friend.userName.isNotEmpty ? friend.userName.substring(0, 2).toUpperCase() : '?',
                    style: TextStyle(color: _kText, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.0),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _kBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: _kCard, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(friend.userName, style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(_getStatus(friend.globalStreak), style: TextStyle(color: _kTextSub, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _kCardBorder.withOpacity(0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kCardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.whatshot_rounded, color: _kTerra, size: 14),
                const SizedBox(width: 4),
                Text('${friend.globalStreak}', style: TextStyle(color: _kTextSub, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: _kTextSub, size: 20),
            color: _kCardBorder,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (val) {
              if (val == 'remove') _remove(friend.friendshipId);
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'remove', child: Text('Remove Friend', style: TextStyle(color: _kTerra, fontSize: 13))),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.spa_rounded, color: _kSage.withOpacity(0.5), size: 48),
          const SizedBox(height: 16),
          Text('No flow network yet', style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Share your invite code to invite friends and grow together.', textAlign: TextAlign.center, style: TextStyle(color: _kTextSub, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}

// ── Friend Details Preview Sheet ─────────────────────────────────────────────

class _FriendDetailsSheet extends StatelessWidget {
  final FriendDto friend;
  const _FriendDetailsSheet({super.key, required this.friend});

  IconData _getDynamicIcon(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('water') || lower.contains('drink')) return Icons.water_drop_rounded;
    if (lower.contains('read') || lower.contains('book')) return Icons.menu_book_rounded;
    if (lower.contains('meditat') || lower.contains('breath')) return Icons.self_improvement_rounded;
    if (lower.contains('journal') || lower.contains('write')) return Icons.book_rounded;
    if (lower.contains('walk') || lower.contains('step')) return Icons.directions_walk_rounded;
    if (lower.contains('run') || lower.contains('jog')) return Icons.directions_run_rounded;
    if (lower.contains('sleep') || lower.contains('bed')) return Icons.nights_stay_rounded;
    if (lower.contains('workout') || lower.contains('gym')) return Icons.fitness_center_rounded;
    if (lower.contains('code') || lower.contains('program')) return Icons.code_rounded;
    return Icons.spa_rounded;
  }

  Color _getDynamicColor(BuildContext context, String title) {
    final lower = title.toLowerCase();
    if (lower.contains('water') || lower.contains('read')) return const Color(0xFF64B5F6);
    if (lower.contains('meditat') || lower.contains('walk')) return context.colors.sage;
    if (lower.contains('journal') || lower.contains('sleep')) return context.colors.lavender;
    if (lower.contains('workout') || lower.contains('run')) return context.colors.terracotta;
    return const Color(0xFFFFB74D);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final habits = friend.publicHabits;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          
          // Profile Header
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [colors.sage.withOpacity(0.3), colors.lavender.withOpacity(0.3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: colors.border, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    friend.userName.isNotEmpty ? friend.userName.substring(0, 2).toUpperCase() : '?',
                    style: TextStyle(color: colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      friend.userName,
                      style: GoogleFonts.playfairDisplay(color: colors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Streakz Community Member',
                      style: TextStyle(color: colors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Streak Counter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.terracotta.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.terracotta.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.whatshot_rounded, color: colors.terracotta, size: 24),
                const SizedBox(width: 12),
                Text(
                  '${friend.globalStreak} day streak',
                  style: TextStyle(color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  friend.globalStreak > 0 ? 'Flowing strong!' : 'Taking it slow',
                  style: TextStyle(color: colors.textSecondary, fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Public Habits Title
          Text(
            'PUBLIC HABITS',
            style: GoogleFonts.inter(
              color: colors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Habits List
          if (habits.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: colors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                children: [
                  Icon(Icons.spa_outlined, color: colors.textSecondary.withOpacity(0.5), size: 36),
                  const SizedBox(height: 12),
                  Text(
                    'No public habits shared yet',
                    style: TextStyle(color: colors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: habits.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final h = habits[index];
                  final icon = _getDynamicIcon(h.title);
                  final color = _getDynamicColor(context, h.title);
                  final progress = (h.completedThisWeek / 7.0).clamp(0.0, 1.0);

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: color, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                h.title,
                                style: TextStyle(color: colors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (h.currentStreak > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: colors.terracotta.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.whatshot_rounded, color: colors.terracotta, size: 12),
                                    const SizedBox(width: 4),
                                    Text('${h.currentStreak}', style: TextStyle(color: colors.terracotta, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: colors.border,
                                  valueColor: AlwaysStoppedAnimation<Color>(colors.sage),
                                  minHeight: 5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '${h.completedThisWeek}/7 done',
                              style: TextStyle(color: colors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

// ── Add Friend Modal Sheet ───────────────────────────────────────────────────

class _AddFriendSheet extends StatefulWidget {
  final Future<void> Function(String) onAdd;
  const _AddFriendSheet({required this.onAdd});

  @override
  State<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends State<_AddFriendSheet> {
  final _controller = TextEditingController();
  bool _isSending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      await widget.onAdd(code);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        top: 16,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Add Friend',
            style: GoogleFonts.playfairDisplay(color: colors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Enter your friend's invite code to join their flow.",
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: colors.card,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _error != null ? colors.terracotta : colors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    style: TextStyle(color: colors.textPrimary, fontSize: 15),
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: [
                      _InviteCodeFormatter(),
                    ],
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: 'Enter invite code (e.g. USER-XXXX)',
                      hintStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isSending ? null : _submit,
                  child: Container(
                    height: 40,
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: colors.sage.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.sage.withOpacity(0.3)),
                    ),
                    child: Center(
                      child: _isSending
                          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: colors.sage, strokeWidth: 2))
                          : Text('Send', style: TextStyle(color: colors.sage, fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                _error!,
                style: TextStyle(color: colors.terracotta, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Invite Code Text Formatter ───────────────────────────────────────────────

class _InviteCodeFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length < oldValue.text.length) {
      if (oldValue.text.endsWith('-') && newValue.text.length == oldValue.text.length - 1) {
        final newText = newValue.text.substring(0, newValue.text.length - 1);
        return TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newText.length),
        );
      }
    }

    final text = newValue.text.replaceAll('-', '').toUpperCase();
    if (text.length > 8) {
      return oldValue;
    }

    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i == 3 && i != text.length - 1) {
        buffer.write('-');
      }
    }

    final formattedText = buffer.toString();
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}
