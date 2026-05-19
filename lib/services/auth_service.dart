import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'mediapipe_service.dart';

class AuthService {
  // 서버 주소
  final String baseUrl = "http://54.144.66.35.nip.io:8080";
  final storage = const FlutterSecureStorage();

  // ---------------------------------------------------------
  // 1. 공통 응답 처리 로직 (생략 없이 풀버전)
  // ---------------------------------------------------------
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

      // UTF-8 디코딩으로 한글 깨짐 방지
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

  // ---------------------------------------------------------
  // 2. 회원가입 관련 함수들 (Signup)
  // ---------------------------------------------------------

  // [회원가입용] 인증번호 발송
  Future<Map<String, dynamic>> sendSmsForSignup(String phoneNumber) async {
    return await _postRequest('/auth/sms/send/signup', {
      "phoneNumber": phoneNumber,
    });
  }

  // 아이디 중복 확인 (POST /auth/check-id)
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

  // 최종 회원가입 완료 (POST /auth/signup)
  Future<bool> signupFinal({
    required String nickname,
    String? loginId,
    String? password,
    required String phoneNumber,
    String? socialId, // 소셜 로그인용 socialId 추가
  }) async {
    final res = await _postRequest('/auth/signup', {
      "nickname": nickname,
      "loginId": loginId,
      "password": password,
      "phoneNumber": phoneNumber,
      "socialId": socialId,
    });
    if (res['success']) {
      // 일반 가입이든 구글 가입이든 세은님이 넘겨준 loginId(이메일)를 그대로 활용!
      if (loginId != null && loginId.isNotEmpty) {
        MediaPipeService.loginId = loginId;

        await storage.write(key: 'savedLoginId', value: loginId);

        print(
          "🔑 [회원가입 성공] MediaPipeService 보관함 ID 연동 완료: ${MediaPipeService.loginId}",
        );
      }
    }

    return res['success'];
  }

  // ---------------------------------------------------------
  // 3. 아이디 찾기 관련 함수들 (FindId)
  // ---------------------------------------------------------

  // [아이디 찾기용] 인증번호 발송 (POST /auth/sms/send/find)
  Future<Map<String, dynamic>> sendSmsForFindId(String phoneNumber) async {
    return await _postRequest('/auth/sms/send/find', {
      "phoneNumber": phoneNumber,
    });
  }

  // 최종 아이디 결과 가져오기 (POST /api/account/id)
  Future<String?> findIdResult(String phoneNumber) async {
    final res = await _postRequest('/api/account/id', {
      "phoneNumber": phoneNumber,
    });

    // 💡 수정 포인트: res['result']가 { "loginId": "..." } 형태이므로 값을 한 번 더 꺼내야 함
    if (res['success'] && res['result'] != null) {
      try {
        // 만약 result가 Map 형태라면 내부의 loginId를 꺼내고, 아니면 그대로 둡니다.
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

  // ---------------------------------------------------------
  // 4. 비밀번호 찾기 관련 함수들 (FindPw)
  // ---------------------------------------------------------

  // [비밀번호 찾기용] 인증번호 발송 (POST /auth/sms/send/find)
  Future<Map<String, dynamic>> sendSmsForFindPw(String phoneNumber) async {
    return await _postRequest('/auth/sms/send/find', {
      "phoneNumber": phoneNumber,
    });
  }

  // 최종 임시 비밀번호 발급 요청 (POST /api/account/pw)
  Future<bool> resetPasswordFinal(String phoneNumber) async {
    final res = await _postRequest('/api/account/pw', {
      "phoneNumber": phoneNumber,
    });
    return res['success'];
  }

  // ---------------------------------------------------------
  // 5. 공통 인증번호 검증 및 로그인
  // ---------------------------------------------------------

  // 인증번호 4자리 검증 (POST /auth/sms/verify)
  Future<bool> verifyCode(String phoneNumber, String verifyCode) async {
    final res = await _postRequest('/auth/sms/verify', {
      "phoneNumber": phoneNumber,
      "verifyCode": verifyCode,
    });
    return res['success'];
  }

  // 일반 로그인 (POST /auth/login)
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

      MediaPipeService.loginId = res['result']['loginId'];
      print(
        "🔑 [일반 로그인 성공] :8080 인증 성공 ID를 :8000방 연동 완료: ${MediaPipeService.loginId}",
      );

      return true;
    }
    return false;
  }

  // 토큰 재발급 (POST /auth/reissue)
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

  // ---------------------------------------------------------
  // 6. 구글 회원가입
  // ---------------------------------------------------------

  // [1] 구글 로그인 검증 및 회원 여부 확인 (POST /auth/login/google)
  Future<Map<String, dynamic>> googleLoginVerify(String accessToken) async {
    return await _postRequest('/auth/login/google', {
      "accessToken": accessToken,
    });
  }

  // [2] 구글 최종 회원가입 완료 (POST /auth/google)
  // 닉네임 설정 페이지에서 마지막에 호출함
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

    // 가입 성공 시 토큰 저장 (기존 팀원 로직과 일관성 유지)
    if (res['success'] && res['result'] != null) {
      await storage.write(
        key: 'accessToken',
        value: res['result']['accessToken'],
      );
      await storage.write(
        key: 'refreshToken',
        value: res['result']['refreshToken'],
      );
      MediaPipeService.loginId = res['result']['loginId'];
      print(
        "🔑 [구글 로그인 성공] :8080 인증 성공 ID를 :8000방 연동 완료: ${MediaPipeService.loginId}",
      );
    }
    return res['success'];
  }
}
