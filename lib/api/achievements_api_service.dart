import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../services/auth_service.dart';

class UserAchievementDto {
  final String type;
  final DateTime unlockedAt;

  UserAchievementDto({required this.type, required this.unlockedAt});

  factory UserAchievementDto.fromJson(Map<String, dynamic> json) {
    return UserAchievementDto(
      type: json['type'] as String,
      unlockedAt: DateTime.parse(json['unlockedAt'] as String),
    );
  }
}

class AchievementsApiService {
  static final AchievementsApiService instance = AchievementsApiService._internal();
  AchievementsApiService._internal();

  final _auth = AuthService.instance;
  final _baseUrl = ApiService.baseUrl;

  Future<List<UserAchievementDto>> getAchievements() async {
    final token = await _auth.getToken();
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('$_baseUrl/auth/achievements'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List<dynamic>;
      return list.map((e) => UserAchievementDto.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw Exception('Failed to load achievements');
  }
}
