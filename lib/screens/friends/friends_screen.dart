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
  final _codeController = TextEditingController();

  String? _myCode;
  List<FriendDto> _friends = [];
  List<FriendRequestDto> _requests = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _api.getMyCode(),
        _api.getFriends(),
        _api.getPendingRequests(),
      ]);
      if (mounted) {
        setState(() {
          _myCode = results[0] as String;
          _friends = results[1] as List<FriendDto>;
          _requests = results[2] as List<FriendRequestDto>;
        });
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sendRequest() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _isSending = true);
    try {
      await _api.sendRequest(code);
      _codeController.clear();
      _showSnack('Friend request sent! 🎉', success: true);
      await _load();
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isSending = false);
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
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kCardBorder,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person_add_alt_1_rounded, color: _kTextSub, size: 20),
          ),
          const SizedBox(height: 20),
          Text('Add Friend', style: GoogleFonts.playfairDisplay(color: _kText, fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('by code', style: TextStyle(color: _kTextSub, fontSize: 13)),
          const SizedBox(height: 24),
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _kCardBorder),
            ),
            child: TextField(
              controller: _codeController,
              style: TextStyle(color: _kText, fontSize: 13),
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _sendRequest(),
              decoration: InputDecoration(
                hintText: 'Enter invite code',
                hintStyle: TextStyle(color: _kTextSub, fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                suffixIcon: _isSending
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: CircularProgressIndicator(color: _kSage, strokeWidth: 2),
                      )
                    : null,
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

  Widget _buildFriendCard(FriendDto friend) {
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
