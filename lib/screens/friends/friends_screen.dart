import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../api/friends_api_service.dart';

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
      backgroundColor: success ? const Color(0xFF00E676) : const Color(0xFFFF5252),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1017),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFDA22FF)))
          : RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFFDA22FF),
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    backgroundColor: const Color(0xFF0C1017),
                    pinned: true,
                    title: const Text('Friends', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Color(0xFF8A8F9E)),
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
        gradient: LinearGradient(
          colors: [const Color(0xFFDA22FF).withOpacity(0.15), const Color(0xFF9733EE).withOpacity(0.08)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDA22FF).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFDA22FF).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.qr_code, color: Color(0xFFDA22FF), size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Your Invite Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _myCode ?? '—',
                    style: const TextStyle(
                      color: Colors.white,
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
                    color: const Color(0xFFDA22FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.copy, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('Share this code with your friends so they can add you.', style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAddFriendCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Friend', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  style: const TextStyle(color: Colors.white, letterSpacing: 2),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'XXXX-XXXX',
                    hintStyle: const TextStyle(color: Color(0xFF8A8F9E)),
                    filled: true,
                    fillColor: const Color(0xFF0C1017),
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
                    gradient: const LinearGradient(colors: [Color(0xFFDA22FF), Color(0xFF9733EE)]),
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
        Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF262A34),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$count', style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildRequestCard(FriendRequestDto req) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF00E676).withOpacity(0.15),
            child: Text(req.requesterName[0].toUpperCase(), style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(req.requesterName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                Text('Wants to be your friend', style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _remove(req.friendshipId),
            child: const Text('Decline', style: TextStyle(color: Color(0xFF8A8F9E))),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: () => _acceptRequest(req),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
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
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFDA22FF).withOpacity(0.2),
                radius: 24,
                child: Text(
                  friend.userName[0].toUpperCase(),
                  style: const TextStyle(color: Color(0xFFDA22FF), fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(friend.userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        if (friend.isPro) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFFDA22FF), Color(0xFF9733EE)]),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('PRO', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    Text('${friend.totalPublicHabits} public habits • ${friend.globalStreak} day streak',
                        style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 12)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Color(0xFF8A8F9E)),
                color: const Color(0xFF262A34),
                onSelected: (val) {
                  if (val == 'remove') _remove(friend.friendshipId);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'remove', child: Text('Remove Friend', style: TextStyle(color: Colors.redAccent))),
                ],
              ),
            ],
          ),
          if (friend.publicHabits.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: Color(0xFF262A34)),
            const SizedBox(height: 8),
            ...friend.publicHabits.map((h) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.circle, color: Color(0xFF00E676), size: 8),
                  const SizedBox(width: 8),
                  Expanded(child: Text(h.title, style: const TextStyle(color: Colors.white, fontSize: 13))),
                  Text('${h.completedThisWeek}/7 this week', style: const TextStyle(color: Color(0xFF8A8F9E), fontSize: 12)),
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
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline, color: Colors.white.withOpacity(0.2), size: 48),
          const SizedBox(height: 12),
          const Text('No friends yet', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Share your invite code to get started!', style: TextStyle(color: Color(0xFF8A8F9E), fontSize: 13)),
        ],
      ),
    );
  }
}
