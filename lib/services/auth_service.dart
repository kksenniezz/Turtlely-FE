import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final String baseUrl = "http://54.144.66.35.nip.io:8080";
  final storage = const FlutterSecureStorage();

  Future<Map<String, dynamic>> _postRequest(
    String path,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$baseUrl$path');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      print("통신 주소: $url");
      print("응답 데이터: $data");
      return {
        "success": (response.statusCode == 200 && data['isSuccess'] == true),
        "message": data['message'] ?? "에러가 발생했습니다.",
        "result": data['result'],
      };
    } catch (e) {
      print("통신 에러: $e");
      return {"success": false, "message": "네트워크 연결을 확인해주세요."};
    }
  }

  // 로그인 이후 JWT Authorization (API 테스트)
  Future<Map<String, dynamic>> authorizedPostRequest(
    String path,
    Map<String, dynamic> body,
  ) async {
    final url = Uri.parse('$baseUrl$path');
    // 1. 저장된 토큰 불러오기
    final accessToken = await storage.read(key: 'accessToken');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(body),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        "success": (response.statusCode == 200 && data['isSuccess'] == true),
        "message": data['message'] ?? "에러가 발생했습니다.",
        "result": data['result'],
      };
    } catch (e) {
      return {"success": false, "message": "네트워크 연결을 확인해주세요."};
    }
  }

  // =========================================================
  // 2. 회원가입
  // =========================================================

  Future<Map<String, dynamic>> sendSmsForSignup(String phoneNumber) async {
    return await _postRequest('/auth/sms/send/signup', {
      "phoneNumber": phoneNumber,
    });
  }

  Future<bool> checkIdDuplicate(String loginId) async {
    final url = Uri.parse('$baseUrl/auth/check-id?loginId=$loginId');
    try {
      final response = await http.post(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['isSuccess'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> signupFinal({
    required String nickname,
    String? loginId,
    String? password,
    required String phoneNumber,
    String? socialId,
  }) async {
    final res = await _postRequest('/auth/signup', {
      "nickname": nickname,
      "loginId": loginId,
      "password": password,
      "phoneNumber": phoneNumber,
      "socialId": socialId,
    });
    return res['success'];
  }

  // =========================================================
  // 3. 아이디 찾기
  // =========================================================

  Future<Map<String, dynamic>> sendSmsForFindId(String phoneNumber) async {
    return await _postRequest('/auth/sms/send/find', {
      "phoneNumber": phoneNumber,
    });
  }

  Future<String?> findIdResult(String phoneNumber) async {
    final res = await _postRequest('/api/account/id', {
      "phoneNumber": phoneNumber,
    });
    if (res['success'] && res['result'] != null) {
      try {
        if (res['result'] is Map) {
          return res['result']['loginId'].toString();
        } else {
          return res['result'].toString();
        }
      } catch (e) {
        print("아이디 파싱 에러: $e");
        return null;
      }
    }
    return null;
  }

  // =========================================================
  // 4. 비밀번호 찾기
  // =========================================================

  Future<Map<String, dynamic>> sendSmsForFindPw(String phoneNumber) async {
    return await _postRequest('/auth/sms/send/find', {
      "phoneNumber": phoneNumber,
    });
  }

  Future<bool> resetPasswordFinal(String phoneNumber) async {
    final res = await _postRequest('/api/account/pw', {
      "phoneNumber": phoneNumber,
    });
    return res['success'];
  }

  // =========================================================
  // 5. 인증번호 검증 및 로그인
  // =========================================================

  Future<bool> verifyCode(String phoneNumber, String verifyCode) async {
    final res = await _postRequest('/auth/sms/verify', {
      "phoneNumber": phoneNumber,
      "verifyCode": verifyCode,
    });
    return res['success'];
  }

  Future<bool> login(String id, String pw) async {
    final res = await _postRequest('/auth/login', {
      'loginId': id,
      'password': pw,
    });
    if (res['success']) {
      await storage.write(
        key: 'accessToken',
        value: res['result']['accessToken'],
      );
      await storage.write(
        key: 'refreshToken',
        value: res['result']['refreshToken'],
      );
      // memberId, monthlyId 저장
      if (res['result']['memberId'] != null) {
        await storage.write(
          key: 'memberId',
          value: res['result']['memberId'].toString(),
        );
      }
      if (res['result']['monthlyId'] != null) {
        await storage.write(
          key: 'monthlyId',
          value: res['result']['monthlyId'].toString(),
        );
      }
      return true;
    }
    return false;
  }

  Future<bool> reissueToken() async {
    final refreshToken = await storage.read(key: 'refreshToken');
    if (refreshToken == null) return false;
    final res = await _postRequest('/auth/reissue', {
      "refreshToken": refreshToken,
    });
    if (res['success']) {
      await storage.write(
        key: 'accessToken',
        value: res['result']['accessToken'],
      );
      return true;
    }
    return false;
  }

  // =========================================================
  // 6. 구글 회원가입
  // =========================================================

  Future<Map<String, dynamic>> googleLoginVerify(String accessToken) async {
    return await _postRequest('/auth/login/google', {
      "accessToken": accessToken,
    });
  }

  Future<bool> signupGoogleFinal({
    required String nickname,
    required String socialId,
    required String phoneNumber,
  }) async {
    print("구글 가입 실행 /auth/google");
    final res = await _postRequest('/auth/google', {
      "nickname": nickname,
      "socialId": socialId,
      "phoneNumber": phoneNumber,
    });
    if (res['success'] && res['result'] != null) {
      await storage.write(
        key: 'accessToken',
        value: res['result']['accessToken'],
      );
      await storage.write(
        key: 'refreshToken',
        value: res['result']['refreshToken'],
      );
    }
    return res['success'];
  }
}
