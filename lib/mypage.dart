import 'package:flutter/material.dart';
import 'style.dart';

class MyPageView extends StatelessWidget {
  const MyPageView({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            // 1. 프로필 영역 (사진 + 닉네임)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: TColor.buttonGreen, width: 2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFFE0E0E0),
                    child: Icon(Icons.person, color: Colors.white, size: 40),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text("(닉네임)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text("(아이디)", style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 2. 설정 리스트
            _buildMenuItem(context, "닉네임 변경", () {
              // Navigator.push(context, MaterialPageRoute(builder: (context) => const EditNicknamePage()));
            }),
            _buildMenuItem(context, "비밀번호 재설정", () {}),
            _buildMenuItem(context, "앱 권한", () {}),
            
            // 3. 진동 세기 조절 (슬라이더)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("진동", style: TextStyle(fontWeight: FontWeight.w500)),
                  Slider(
                    value: 0.5,
                    activeColor: TColor.buttonGreen,
                    inactiveColor: TColor.lightGreen,
                    onChanged: (value) {},
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            // 4. 로그아웃 / 탈퇴
            _buildSimpleTextButton("로그아웃"),
            _buildSimpleTextButton("탈퇴하기"),
          ],
        ),
      ),
    );
  }

  // 메뉴 아이템 위젯 빌더
  Widget _buildMenuItem(BuildContext context, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }

  // 하단 텍스트 버튼
  Widget _buildSimpleTextButton(String title) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14, decoration: TextDecoration.underline)),
    );
  }
}