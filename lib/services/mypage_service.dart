import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// 프로필 데이터 모델 (닉네임 + 아이디)
class UserProfileData {
  final String nickname;
  final String loginId;

  UserProfileData({required this.nickname, required this.loginId});
}

class MyPageService {
  static const String _baseUrl = 'http://54.144.66.35.nip.io:8080';
  final _storage = const FlutterSecureStorage();

  // 공통 헤더 생성 (토큰 포함)
  Future<Map<String, String>> _getHeaders() async {
    final accessToken = await _storage.read(key: 'accessToken');
    return {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
  }

  // 1. 닉네임 조회 (GET /api/members/nickname)
  Future<String?> fetchNickname() async {
    try {
      final url = Uri.parse('$_baseUrl/api/members/nickname');
      print("[MyPageService 닉네임 요청]: $url");

      final response = await http.get(url, headers: await _getHeaders());

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        if (decoded['isSuccess'] == true && decoded['result'] != null) {
          final result = decoded['result'];
          if (result is Map) {
            return result['nickname']?.toString() ??
                result['additionalProp1']?.toString();
          }
          return result.toString();
        }
      }
      return null;
    } catch (e) {
      print("[fetchNickname 에러]: $e");
      return null;
    }
  }

  // 2. 아이디 조회 (GET /api/members/id)
  Future<String?> fetchUserId() async {
    try {
      final url = Uri.parse('$_baseUrl/api/members/id');
      print("[MyPageService 아이디 요청]: $url");

      final response = await http.get(url, headers: await _getHeaders());

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        if (decoded['isSuccess'] == true && decoded['result'] != null) {
          final result = decoded['result'];
          if (result is Map) {
            return result['loginId']?.toString() ??
                result['additionalProp1']?.toString();
          }
          return result.toString();
        }
      }
      return null;
    } catch (e) {
      print("[fetchUserId 에러]: $e");
      return null;
    }
  }

  // 3. 프로필 한 번에 불러오기 (닉네임 + 아이디 병렬 조회)
  Future<UserProfileData?> fetchUserProfile() async {
    try {
      final results = await Future.wait([fetchNickname(), fetchUserId()]);

      final nickname = results[0] ?? '(닉네임)';
      final userId = results[1] ?? '(아이디)';

      return UserProfileData(nickname: nickname, loginId: userId);
    } catch (e) {
      print("[fetchUserProfile 에러]: $e");
      return null;
    }
  }

  // 4. 닉네임 변경 (PATCH /api/members/nickname)
  Future<bool> updateNickname(String newNickname) async {
    try {
      final url = Uri.parse('$_baseUrl/api/members/nickname');
      print("[MyPageService 닉네임 변경 요청]: $url");

      final response = await http.patch(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({"nickname": newNickname}),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        return decoded['isSuccess'] == true;
      }
      return false;
    } catch (e) {
      print("[updateNickname 에러]: $e");
      return false;
    }
  }

  // 5. 비밀번호 재설정 (PATCH /api/members/password)
  Future<bool> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final url = Uri.parse('$_baseUrl/api/members/password');
      print("[MyPageService 비밀번호 변경 요청]: $url");

      final response = await http.patch(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          "currentPassword": currentPassword,
          "newPassword": newPassword,
        }),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        return decoded['isSuccess'] == true;
      }
      return false;
    } catch (e) {
      print("[updatePassword 에러]: $e");
      return false;
    }
  }

  // 6. 로그아웃 (POST /api/account) 및 클라이언트 토큰 삭제
  Future<bool> logout() async {
    try {
      final url = Uri.parse('$_baseUrl/api/account');
      print("[MyPageService 로그아웃 요청]: $url");

      final response = await http.post(url, headers: await _getHeaders());

      // AuthService에서 세션 정보 저장할 때 사용된 모든 키 정리
      await _storage.deleteAll();

      if (response.statusCode == 200) {
        print("로그아웃 성공");
        return true;
      }
      return true;
    } catch (e) {
      print("[logout 에러]: $e");
      await _storage.deleteAll();
      return true;
    }
  }

  // 7. 회원탈퇴 (DELETE /api/members/withdraw) 및 클라이언트 토큰 삭제
  Future<bool> withdraw() async {
    try {
      final url = Uri.parse('$_baseUrl/api/members/withdraw');
      print("[MyPageService 회원탈퇴 요청]: $url");

      final response = await http.delete(url, headers: await _getHeaders());

      await _storage.deleteAll();

      if (response.statusCode == 200) {
        print("회원 탈퇴 성공");
        return true;
      }
      return true;
    } catch (e) {
      print("[withdraw 에러]: $e");
      await _storage.deleteAll();
      return true;
    }
  }
}
