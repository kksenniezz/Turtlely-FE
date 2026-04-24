import 'package:flutter/material.dart';
import 'style.dart';
import 'find_id.dart';
import 'find_password.dart';
import 'main.dart'; // TurtlelyMainPage를 호출하기 위해 필요합니다.

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  // 사용자가 입력한 아이디와 비밀번호를 담을 컨트롤러
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();

  // 로그인 시도 로직
  void _handleLogin() {
    // [참고] 나중에 여기에 서버와 통신하는 코드를 넣으시면 됩니다.
    
    // 로그인이 성공했다고 가정하고 메인 화면으로 이동
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const TurtlelyMainPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColor.white,
      appBar: AppBar(
        backgroundColor: TColor.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("로그인", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _idController,
              decoration: const InputDecoration(hintText: "아이디"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pwController,
              decoration: const InputDecoration(hintText: "비밀번호"),
              obscureText: true, // 비밀번호 글자 숨김 처리
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: T_MainButtonStyle,
              onPressed: _handleLogin, // 버튼 클릭 시 _handleLogin 함수 실행
              child: const Text("로그인", style: TText.button),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FindId())),
                  child: const Text("아이디 찾기", style: TextStyle(color: TColor.gray)),
                ),
                const Text("|", style: TextStyle(color: TColor.gray)),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FindPassword())),
                  child: const Text("비밀번호 찾기", style: TextStyle(color: TColor.gray)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}