import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../services/auth_service.dart';

class FriendDto {
  final String friendshipId;
  final String id;
  final String userName;
  final bool isPro;
  final int globalStreak;
  final int totalPublicHabits;
  final List<PublicHabitDto> publicHabits;

  FriendDto({
    required this.friendshipId,
    required this.id,
    required this.userName,
    required this.isPro,
    required this.globalStreak,
    required this.totalPublicHabits,
    required this.publicHabits,
  });

  factory FriendDto.fromJson(Map<String, dynamic> j) => FriendDto(
    friendshipId: j['friendshipId'] as String,
    id: j['id'] as String,
    userName: j['userName'] as String,
    isPro: j['isPro'] as bool? ?? false,
    globalStreak: j['globalStreak'] as int? ?? 0,
    totalPublicHabits: j['totalPublicHabits'] as int? ?? 0,
    publicHabits: (j['publicHabits'] as List<dynamic>? ?? [])
        .map((e) => PublicHabitDto.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class PublicHabitDto {
  final String title;
  final int completedThisWeek;
  final int currentStreak;

  PublicHabitDto({required this.title, required this.completedThisWeek, required this.currentStreak});

  factory PublicHabitDto.fromJson(Map<String, dynamic> j) => PublicHabitDto(
    title: j['title'] as String,
    completedThisWeek: j['completedThisWeek'] as int? ?? 0,
    currentStreak: j['currentStreak'] as int? ?? 0,
  );
}

class FriendRequestDto {
  final String friendshipId;
  final String requesterId;
  final String requesterName;
  final DateTime sentAt;

  FriendRequestDto({required this.friendshipId, required this.requesterId, required this.requesterName, required this.sentAt});

  factory FriendRequestDto.fromJson(Map<String, dynamic> j) => FriendRequestDto(
    friendshipId: j['friendshipId'] as String,
    requesterId: j['requesterId'] as String,
    requesterName: j['requesterName'] as String,
    sentAt: DateTime.parse(j['sentAt'] as String),
  );
}

class SuggestedUserDto {
  final String id;
  final String userName;
  final bool isPro;

  SuggestedUserDto({required this.id, required this.userName, required this.isPro});

  factory SuggestedUserDto.fromJson(Map<String, dynamic> j) => SuggestedUserDto(
    id: j['id'] as String,
    userName: j['userName'] as String,
    isPro: j['isPro'] as bool? ?? false,
  );
}

class FriendsApiService {
  static final FriendsApiService _instance = FriendsApiService._internal();
  factory FriendsApiService() => _instance;
  FriendsApiService._internal();

  final _auth = AuthService.instance;
  final _baseUrl = ApiService.baseUrl;

  Future<Map<String, String>> _headers() async {
    final token = await _auth.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Хелпер для обработки сетевых ошибок
  String _parseError(dynamic e) {
    final errStr = e.toString().toLowerCase();
    if (errStr.contains('socketexception') || errStr.contains('host lookup') || errStr.contains('failed host lookup')) {
      return 'Network error. Please check your internet connection.';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }

  Future<String> getMyCode() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/friends/my-code'), headers: await _headers());
      if (res.statusCode == 200) {
        return jsonDecode(res.body)['inviteCode'] as String;
      }
      throw Exception('Failed to get invite code');
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  Future<void> sendRequest(String code) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/friends/add/$code'), headers: await _headers());
      if (res.statusCode != 200) {
        final body = jsonDecode(res.body);
        throw Exception(body['message'] ?? 'Failed to send request');
      }
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  Future<void> acceptRequest(String friendshipId) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/friends/accept/$friendshipId'), headers: await _headers());
      if (res.statusCode != 200) throw Exception('Failed to accept request');
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  Future<void> removeFriend(String friendshipId) async {
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/friends/$friendshipId'), headers: await _headers());
      if (res.statusCode != 200) throw Exception('Failed to remove');
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  Future<List<FriendDto>> getFriends() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/friends'), headers: await _headers());
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((e) => FriendDto.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to load friends');
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  Future<List<FriendRequestDto>> getPendingRequests() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/friends/requests'), headers: await _headers());
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((e) => FriendRequestDto.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to load requests');
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  Future<List<SuggestedUserDto>> getSuggestions() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/friends/suggestions'), headers: await _headers());
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List<dynamic>;
        return list.map((e) => SuggestedUserDto.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw Exception('Failed to load suggestions');
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }

  Future<void> sendRequestById(String userId) async {
    try {
      final res = await http.post(Uri.parse('$_baseUrl/friends/request/$userId'), headers: await _headers());
      if (res.statusCode != 200) {
        final body = jsonDecode(res.body);
        throw Exception(body['message'] ?? 'Failed to send request');
      }
    } catch (e) {
      throw Exception(_parseError(e));
    }
  }
}
