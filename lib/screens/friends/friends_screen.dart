import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api/friends_api_service.dart';
import '../../theme/app_theme.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
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
      setState(() {
        _myCode = results[0] as String;
        _friends = results[1] as List<FriendDto>;
        _requests = results[2] as List<FriendRequestDto>;
      });
    } catch (_) {} finally {
      setState(() => _isLoading = false);
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
      setState(() => _isSending = false);
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
      backgroundColor: success ? context.colors.success : context.colors.danger,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: context.colors.secondary))
          : RefreshIndicator(
              onRefresh: _load,
              color: context.colors.secondary,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    backgroundColor: context.colors.background,
                    pinned: true,
                    title: Text('Friends', style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.bold)),
                    actions: [
                      IconButton(
                        icon: Icon(Icons.refresh, color: context.colors.textSecondary),
                        onPressed: _load,
                      )
                    ],
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(20),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildMyCodeCard(),
                        const SizedBox(height: 20),
                        _buildAddFriendCard(),
                        if (_requests.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          _buildSectionHeader('Pending Requests', _requests.length),
                          const SizedBox(height: 12),
                          ..._requests.map((r) => _buildRequestCard(r)),
                        ],
                        const SizedBox(height: 24),
                        _buildSectionHeader('Friends', _friends.length),
                        const SizedBox(height: 12),
                        if (_friends.isEmpty)
                          _buildEmptyState()
                        else
                          ..._friends.map((f) => _buildFriendCard(f)),
                        const SizedBox(height: 40),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMyCodeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.secondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.secondary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.colors.secondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.qr_code, color: context.colors.secondary, size: 20),
              ),
              const SizedBox(width: 10),
              Text('Your Invite Code', style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.colors.card,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _myCode ?? '—',
                    style: TextStyle(
                      color: context.colors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _myCode ?? ''));
                  _showSnack('Code copied!', success: true);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colors.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.copy, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Share this code with your friends so they can add you.', style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAddFriendCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Friend', style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  style: TextStyle(color: context.colors.textPrimary, letterSpacing: 2),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'XXXX-XXXX',
                    hintStyle: TextStyle(color: context.colors.textSecondary),
                    filled: true,
                    fillColor: context.colors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _isSending ? null : _sendRequest,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.colors.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _isSending
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.person_add, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(title, style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: context.colors.iconBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$count', style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildRequestCard(FriendRequestDto req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.success.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: context.colors.success.withOpacity(0.15),
            child: Text(req.requesterName[0].toUpperCase(), style: TextStyle(color: context.colors.success, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(req.requesterName, style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.w600)),
                Text('Wants to be your friend', style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _remove(req.friendshipId),
            child: Text('Decline', style: TextStyle(color: context.colors.textSecondary)),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () => _acceptRequest(req),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendCard(FriendDto friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: context.colors.secondary.withOpacity(0.2),
                radius: 24,
                child: Text(
                  friend.userName[0].toUpperCase(),
                  style: TextStyle(color: context.colors.secondary, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(friend.userName, style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
                        if (friend.isPro) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.colors.secondary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    Text('${friend.totalPublicHabits} public habits • ${friend.globalStreak} day streak',
                        style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: context.colors.textSecondary),
                color: context.colors.cardSecondary,
                onSelected: (val) {
                  if (val == 'remove') _remove(friend.friendshipId);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'remove', child: Text('Remove Friend', style: TextStyle(color: context.colors.danger))),
                ],
              ),
            ],
          ),
          if (friend.publicHabits.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: context.colors.iconBg),
            const SizedBox(height: 8),
            ...friend.publicHabits.map((h) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.circle, color: context.colors.success, size: 8),
                  const SizedBox(width: 8),
                  Expanded(child: Text(h.title, style: TextStyle(color: context.colors.textPrimary, fontSize: 13))),
                  Text('${h.completedThisWeek}/7 this week', style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
                  if (h.currentStreak > 0) ...[
                    const SizedBox(width: 8),
                    Text('🔥 ${h.currentStreak}', style: const TextStyle(fontSize: 12)),
                  ],
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline, color: context.colors.textPrimary.withOpacity(0.2), size: 48),
          const SizedBox(height: 12),
          Text('No friends yet', style: TextStyle(color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Share your invite code to get started!', style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
