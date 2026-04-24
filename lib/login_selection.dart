import 'package:flutter/material.dart';
import 'style.dart';
import 'login.dart';
import 'signup.dart';

class LoginSelection extends StatelessWidget {
  const LoginSelection({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 배경색 고정
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min, // 위아래로 꽉 채우지 않고 내용물만 가운데로 모음
              children: [
                // 거북이 이미지
                Image.asset('assets/normal_turtle.png', width: 160),
                const SizedBox(height: 20),

                // 로고
                const Text("Turtlely", style: TText.logo),
                const SizedBox(height: 40),

                // 로그인 버튼
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: T_MainButtonStyle, // style.dart의 버튼 스타일 적용
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const Login()));
                    },
                    child: const Text("로그인", style: TText.button), // 텍스트 스타일 통일
                  ),
                ),

                const SizedBox(height: 16),

                // 회원가입 버튼
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: TColor.buttonGreen, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const Signup()));
                    },
                    child: const Text(
                      "회원가입",
                      style: TextStyle(
                        color: TColor.buttonGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}