import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  // 서버 주소 (Swagger 상단 주소)
  final String baseUrl = "http://54.144.66.35.nip.io:8080";
  final storage = const FlutterSecureStorage();

  //로그인 함수
  Future<bool> login(String id, String pw) async {
  final url = Uri.parse('$baseUrl/auth/login');
  final body = jsonEncode({
    'loginId': id, 
    'password': pw,
  });

  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    print('상태 코드: ${response.statusCode}');
    print('응답 내용: ${response.body}');

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        
        // 1. 입장권(AccessToken) 저장
        await storage.write(key: 'accessToken', value: data['accessToken']);
        
        // 2. 재발급권(RefreshToken) 저장 (이게 있어야 나중에 재발급이 돼요!)
        if (data['refreshToken'] != null) {
          await storage.write(key: 'refreshToken', value: data['refreshToken']);
        }
        
      } catch (e) {
        // 만약 서버가 JSON이 아니라 그냥 글자 하나만 띡 보내준다면?
        // 일단 입장권으로만 저장합니다. (보통은 JSON으로 올 거예요!)
        await storage.write(key: 'accessToken', value: response.body);
      }
      return true;
    }
    return false;
  } catch (e) {
    print('통신 중 진짜 에러: $e');
    return false;
  }
}

  // 아이디 찾기 함수
  Future<String?> findId(String phoneNumber) async {
    final url = Uri.parse('$baseUrl/account/id'); // Swagger 주소 확인 필요

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phoneNumber': phoneNumber}),
      );
      print("아이디 찾기 상태 코드: ${response.statusCode}");
      print("아이디 찾기 응답 내용: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['result'];
      } else {
        return null; // 실패 시 null 반환
      }
    } catch (e) {
      return null;
    }
  }

  // SMS 인증번호 검증 함수
  Future<bool> verifySmsCode(String phoneNumber, String verifyCode) async {
    final url = Uri.parse('$baseUrl/auth/sms/verify'); 

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "phoneNumber": phoneNumber,
          "verifyCode": verifyCode, // 명세서 변수명 맞춤
        }),
      );

      print("인증 확인 상태 코드: ${response.statusCode}");
      print("인증 확인 응답 내용: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // 서버에서 성공 여부를 'isSuccess' 필드로 주는지 확인하세요!
        return data['isSuccess'] == true;
      }
      return false;
    } catch (e) {
      print("인증 통신 에러: $e");
      return false;
    }
  }

// SMS 인증번호 발송 함수
  Future<bool> sendSmsCode(String phoneNumber) async {
  final url = Uri.parse('$baseUrl/auth/sms/send');

  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "phoneNumber": phoneNumber, // 명세서 변수명 그대로!
      }),
    );

    print("문자 발송 상태 코드: ${response.statusCode}");
    
    if (response.statusCode == 200) {
      return true; // 발송 성공
    }
    return false;
  } catch (e) {
    print("문자 발송 통신 에러: $e");
    return false;
  }
}
  // 아이디 중복 확인 함수
  Future<bool> checkId(String loginId) async {
    final url = Uri.parse('$baseUrl/auth/check-id?loginId=$loginId'); // Query Parameter 방식

    try {
      final response = await http.post(url); // 명세서에 POST라고 되어 있네요!
      print("중복확인 상태 코드: ${response.statusCode}");
      
      // 200이면 사용 가능, 아니면 중복 혹은 에러
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

// 일반 회원가입 함수
  Future<bool> signup({
    required String nickname,
    required String loginId,
    required String password,
    required String phoneNumber,
  }) async {
    final url = Uri.parse('$baseUrl/auth/signup');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "nickname": nickname,
          "loginId": loginId,
          "password": password,
          "phoneNumber": phoneNumber,
        }),
      );

      print("회원가입 상태 코드: ${response.statusCode}");
      return response.statusCode == 200; // MEMBER200_4 응답 시 성공
    } catch (e) {
      return false;
    }
  }
// 비밀번호 찾기 함수
  Future<bool> findPassword(String phoneNumber) async {
  final url = Uri.parse('$baseUrl/api/account/pw'); 

  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "phoneNumber": phoneNumber, // 명세서에 있는 key 이름
      }),
    );

    // 로그 찍어서 확인하기 (범인 검거용!)
    print("비밀번호 찾기 상태 코드: ${response.statusCode}");
    print("비밀번호 찾기 응답 내용: ${response.body}");

    // 성공하면 보통 200이 옵니다.
    if (response.statusCode == 200) {
      return true;
    } else {
      return false;
    }
  } catch (e) {
    print("비밀번호 찾기 통신 에러: $e");
    return false;
  }
}
// 토큰 재발급 함수
  Future<bool> reissueToken() async {
    // 1. 금고에서 리프레시 토큰 꺼내기
    final refreshToken = await storage.read(key: 'refreshToken');
    if (refreshToken == null) return false;

    final url = Uri.parse('$baseUrl/auth/reissue');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "refreshToken": refreshToken, // 승연님 명세서 Key값
        }),
      );

      print("토큰 재발급 상태 코드: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // 2. 서버가 준 새 입장권(accessToken)을 다시 금고에 저장!
        await storage.write(key: 'accessToken', value: data['accessToken']);
        return true;
      }
      return false;
    } catch (e) {
      print("토큰 재발급 에러: $e");
      return false;
    }
  }
}