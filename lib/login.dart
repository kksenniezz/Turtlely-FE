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

  // 비밀번호 가리기 상태 변수
  bool _isObscurePw = true;

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
          children: [
            const SizedBox(height: 40), // 상단 여백 추가
            // 아이디 입력칸
            TextField(
              controller: _idController,
              decoration: InputDecoration(
                hintText: "아이디",
                hintStyle: const TextStyle(color: TColor.gray),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                // 테두리를 사방으로 감싸고 모서리를 14로 설정
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFE0E0E0),
                  ), // 사진과 유사한 연한 회색
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.black),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 비밀번호 입력칸
            TextField(
              controller: _pwController,
              obscureText: _isObscurePw,
              decoration: InputDecoration(
                hintText: "비밀번호",
                hintStyle: const TextStyle(color: TColor.gray),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                // 눈 모양 아이콘 추가
                suffixIcon: IconButton(
                  icon: Icon(
                    _isObscurePw
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
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

            const SizedBox(height: 32),

            // 로그인 버튼
            SizedBox(
              width: double.infinity,
              height: 56, // 버튼 높이 명시
              child: ElevatedButton(
                style: T_MainButtonStyle,
                onPressed: _handleLogin,
                child: const Text("로그인", style: TText.button),
              ),
            ),

            const SizedBox(height: 16),

            // 아이디/비밀번호 찾기
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FindId()),
                  ),
                  child: const Text(
                    "아이디 찾기",
                    style: TextStyle(color: TColor.gray),
                  ),
                ),
                const Text("|", style: TextStyle(color: TColor.gray)),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FindPassword()),
                  ),
                  child: const Text(
                    "비밀번호 찾기",
                    style: TextStyle(color: TColor.gray),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
