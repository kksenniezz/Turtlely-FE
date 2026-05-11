import 'package:flutter/material.dart';
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
  bool _isObscurePw = true;

  // 1. 에러 메시지 표시 여부를 결정하는 변수 추가
  bool _showErrorText = false;

  void _handleLogin() async {
    String id = _idController.text.trim();
    String pw = _pwController.text.trim();

    // 로그인 시도할 때마다 일단 에러 메시지를 숨깁니다.
    setState(() {
      _showErrorText = false;
    });

    bool success = await AuthService().login(id, pw);

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const TurtlelyMainPage()),
      );
    } else {
      // 2. 로그인 실패 시 에러 문구가 보이도록 상태를 업데이트합니다.
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
          crossAxisAlignment: CrossAxisAlignment.start, // 텍스트 왼쪽 정렬을 위해 추가
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

            // 3. 에러 문구 표시 영역 (비밀번호 칸 바로 아래)
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