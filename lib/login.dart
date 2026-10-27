import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'style.dart';
import 'find_id.dart';
import 'find_password.dart';
import 'main.dart';
import 'services/auth_service.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _isObscurePw = true;
  bool _showErrorText = false;

  // 서버에 FCM 토큰을 전송하는 함수 (보완됨)
  Future<void> _sendFcmTokenToServer() async {
    try {
      // 1. 알림 권한 요청 상태 확인
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      debugPrint("🔔 Notification Permission: ${settings.authorizationStatus}");

      // 2. 저장된 accessToken 가져오기
      String? accessToken = await _storage.read(key: 'accessToken');
      // 3. Firebase에서 FCM 토큰 가져오기
      String? fcmToken = await messaging.getToken();

      debugPrint("🔑 AccessToken: $accessToken");
      debugPrint("📱 FCM Token: $fcmToken");

      if (accessToken != null && fcmToken != null && fcmToken.isNotEmpty) {
        final response = await http.post(
          Uri.parse("http://54.144.66.35.nip.io:8080/api/fcm-token"),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $accessToken",
          },
          body: jsonEncode({"fcmToken": fcmToken}),
        );

        if (response.statusCode == 200) {
          debugPrint("✅ [성공] FCM 토큰 서버 전송 완료!");
          debugPrint("응답 내용: ${response.body}");
        } else {
          debugPrint("❌ [실패] FCM 토큰 전송 상태 코드: ${response.statusCode}");
          debugPrint("에러 내용: ${response.body}");
        }
      } else {
        debugPrint("⚠️ AccessToken 또는 FCM Token이 null이거나 비어있습니다.");
      }
    } catch (e) {
      debugPrint("❌ FCM 토큰 전송 중 예외 발생: $e");
    }
  }

  void _handleLogin() async {
    String id = _idController.text.trim();
    String pw = _pwController.text.trim();

    setState(() {
      _showErrorText = false;
    });

    // 1. 로그인 API 실행
    bool success = await AuthService().login(id, pw);

    if (success) {
      // 2. 로그인 성공 시 FCM 토큰 서버로 전송 실행
      await _sendFcmTokenToServer();

      // 3. 메인 페이지로 이동
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TurtlelyMainPage()),
      );
    } else {
      // 로그인 실패 처리
      setState(() {
        _showErrorText = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColor.white,
      appBar: AppBar(
        backgroundColor: TColor.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "로그인",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            TextField(
              controller: _idController,
              decoration: InputDecoration(
                hintText: "아이디",
                hintStyle: const TextStyle(color: TColor.gray),
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.black),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pwController,
              obscureText: _isObscurePw,
              decoration: InputDecoration(
                hintText: "비밀번호",
                hintStyle: const TextStyle(color: TColor.gray),
                contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isObscurePw ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: TColor.gray,
                  ),
                  onPressed: () {
                    setState(() {
                      _isObscurePw = !_isObscurePw;
                    });
                  },
                ),
              ),
            ),
            if (_showErrorText)
              const Padding(
                padding: EdgeInsets.only(top: 8.0, left: 4.0),
                child: Text(
                  "아이디 또는 비밀번호를 다시 확인해 주세요",
                  style: TextStyle(color: Colors.red, fontSize: 13),
                ),
              ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: T_MainButtonStyle,
                onPressed: _handleLogin,
                child: const Text("로그인", style: TText.button),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FindId()),
                  ),
                  child: const Text("아이디 찾기", style: TextStyle(color: TColor.gray)),
                ),
                const Text("|", style: TextStyle(color: TColor.gray)),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FindPassword()),
                  ),
                  child: const Text("비밀번호 찾기", style: TextStyle(color: TColor.gray)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}