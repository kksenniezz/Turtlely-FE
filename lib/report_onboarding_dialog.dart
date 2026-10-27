import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReportOnboardingDialog extends StatefulWidget {
  final String userName;
  final VoidCallback onComplete;

  const ReportOnboardingDialog({
    super.key,
    required this.userName,
    required this.onComplete,
  });

  static Future<void> checkAndShow(
    BuildContext context, {
    required String userName,
    VoidCallback? onComplete,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    bool hasSeenOnboarding = prefs.getBool('has_seen_report_onboarding') ?? false;

    if (!hasSeenOnboarding && context.mounted) {
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.7), // 어두운 배경 오버레이
        pageBuilder: (context, anim1, anim2) {
          return ReportOnboardingDialog(
            userName: userName,
            onComplete: () async {
              await prefs.setBool('has_seen_report_onboarding', true);
              if (onComplete != null) onComplete();
            },
          );
        },
      );
    }
  }

  @override
  State<ReportOnboardingDialog> createState() => _ReportOnboardingDialogState();
}

class _ReportOnboardingDialogState extends State<ReportOnboardingDialog> {
  int _currentStep = 1; // 1: 일일 리포트, 2: 월간 리포트

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() {
    widget.onComplete();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // 1. 상단 안내 타이틀 텍스트
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildTitleText(),
            ),

            const SizedBox(height: 16),

            // 2. 중앙 핸드폰 프레임 예시 이미지 영역
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Image.asset(
                  _currentStep == 1
                      ? 'assets/report_onboarding_1.png'
                      : 'assets/report_onboarding_2.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(
                      child: Text(
                        "assets/report_onboarding_1.png\n이미지를 넣어주세요!",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 3. 하단 컨트롤 영역 (버튼 & 점 인디케이터)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.5),
                  ],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // [다음] / [확인] 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E532B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _nextStep,
                      child: Text(
                        _currentStep == 1 ? "다음" : "확인",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 하단 페이지 위치 점(Dot) 인디케이터
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(2, (index) {
                      bool isActive = (index + 1) == _currentStep;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 8 : 6,
                        height: isActive ? 8 : 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive
                              ? const Color(0xFF2E532B)
                              : Colors.grey.shade400,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 상단 텍스트 위젯 (단계별 라벨 및 색상 반영)
  Widget _buildTitleText() {
    if (_currentStep == 1) {
      return RichText(
        textAlign: TextAlign.center,
        text: const TextSpan(
          style: TextStyle(fontSize: 16, color: Colors.white, height: 1.4),
          children: [
            TextSpan(text: "매일 차곡차곡 쌓인 "),
            TextSpan(
              text: "일일 리포트",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF81C784), // 연한 녹색 강조
              ),
            ),
            TextSpan(text: "로\n한 달 후, 눈에 띄게 달라진 변화를 확인하세요"),
          ],
        ),
      );
    } else {
      return RichText(
        textAlign: TextAlign.center,
        text: const TextSpan(
          style: TextStyle(fontSize: 16, color: Colors.white, height: 1.4),
          children: [
            TextSpan(text: "우측 하단의 리포트 버튼을 눌러\n"),
            TextSpan(
              text: "월간 리포트",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF81C784), // 연한 녹색 강조
              ),
            ),
            TextSpan(text: "를 확인하세요"),
          ],
        ),
      );
    }
  }
}