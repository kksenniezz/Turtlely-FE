import 'package:flutter/material.dart';
import 'style.dart';
import 'login_selection.dart';

class Splash extends StatefulWidget {
  const Splash({super.key});

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {

  @override
  void initState() {
    super.initState();

    // 첫 프레임 렌더링 이후 실행 (안정성 확보)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDelay();
    });
  }

  void _startDelay() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return; // ⭐ context 안전 체크

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginSelection(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColor.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/normal_turtle.png',
              width: 150,
              errorBuilder: (context, error, stackTrace) {
                return const Text("이미지 로드 실패 (assets 경로 확인)");
              },
            ),
            const SizedBox(height: 20),
            const Text(
              "Turtlely",
              style: TText.logo,
            ),
          ],
        ),
      ),
    );
  }
}