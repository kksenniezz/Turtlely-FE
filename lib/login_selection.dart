import 'package:flutter/material.dart';
import 'style.dart';
import 'login.dart';
import 'signup.dart';

class LoginSelection extends StatelessWidget {
  const LoginSelection({super.key});

  void _showSelectionModal(BuildContext context, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      useSafeArea: false,
      backgroundColor: const Color(0xFFE9F1E6), // 연두색 배경
      barrierColor: Colors.black.withOpacity(0.7),
      enableDrag: true, // 드래그로 닫기 활성화
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          width: MediaQuery.of(context).size.width,
          decoration: const BoxDecoration(
            color: Color(0xFFE9F1E6),
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            // 여기서 stretch를 써야 내부 버튼들도 부모인 모달 너비를 따라갑니다.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              Center(
                // 타이틀 가운데 정렬
                child: Text(
                  type,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFD9D9D9), thickness: 1, height: 1),
              const SizedBox(height: 32),

              _buildResponsiveModalButton(
                context: context,
                label: '일반 $type',
                assetPath: 'assets/mail.png',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          type == '로그인' ? const Login() : const Signup(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              _buildResponsiveModalButton(
                context: context,
                label: '구글 $type',
                assetPath: 'assets/google_icon.png',
                onTap: () => print("구글 $type 클릭됨"),
              ),

              // 하단 여백 (홈바 영역)
              SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResponsiveModalButton({
    required BuildContext context,
    required String label,
    required String assetPath,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0), // 양옆 여백만 남기고 늘어남
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD9D9D9), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.1),
                offset: Offset(0, 4),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // 텍스트와 아이콘 중앙 정렬
            children: [
              Image.asset(
                assetPath,
                width: 20,
                height: 20,
                // 💡 이미지가 안 뜨면 원인을 보여주도록 텍스트 출력
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 거북이 이미지
                Image.asset(
                  'assets/normal_turtle.png',
                  width: 160,
                  errorBuilder: (context, error, stackTrace) {
                    return const Text("거북이 이미지 경로 확인");
                  },
                ),
                const SizedBox(height: 20),

                // 로고
                const Text("Turtlely", style: TText.logo),
                const SizedBox(height: 40),

                // 로그인 버튼
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: T_MainButtonStyle,
                    onPressed: () => _showSelectionModal(context, '로그인'),
                    child: const Text("로그인", style: TText.button),
                  ),
                ),

                const SizedBox(height: 16),

                // 회원가입 버튼
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: TColor.buttonGreen,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _showSelectionModal(context, '회원가입'),
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
