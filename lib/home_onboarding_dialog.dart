import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// home_view_content.dart의 Key 선언 임포트
import 'home.dart';

class HomeOnboardingDialog extends StatefulWidget {
  final String userName;
  final VoidCallback onComplete;

  const HomeOnboardingDialog({
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
    bool hasSeenOnboarding = prefs.getBool('has_seen_home_onboarding') ?? false;

    if (!hasSeenOnboarding && context.mounted) {
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.65),
        pageBuilder: (context, anim1, anim2) {
          return HomeOnboardingDialog(
            userName: userName,
            onComplete: () async {
              await prefs.setBool('has_seen_home_onboarding', true);
              if (onComplete != null) onComplete();
            },
          );
        },
      );
    }
  }

  @override
  State<HomeOnboardingDialog> createState() => _HomeOnboardingDialogState();
}

class _HomeOnboardingDialogState extends State<HomeOnboardingDialog> {
  int _currentStep = 0; // 0: Intro, 1: Step1, 2: Step2, 3: Step3, 4: Step4

  Rect? _getWidgetRect(GlobalKey key) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is RenderBox) {
      final translation = renderObject.getTransformTo(null).getTranslation();
      final size = renderObject.size;
      return Rect.fromLTWH(translation.x, translation.y, size.width, size.height);
    }
    return null;
  }

  void _nextStep() {
    if (_currentStep < 4) {
      setState(() => _currentStep++);
    } else {
      _finishOnboarding();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _finishOnboarding() {
    widget.onComplete();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    Rect? step3Rect = _currentStep == 3 ? _getWidgetRect(difficultyBtnKey) : null;
    Rect? step4Rect = _currentStep == 4 ? _getWidgetRect(monthlyBtnKey) : null;

    final targetRect = step3Rect ?? step4Rect;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ----------------------------------------------------------------
          // 1. 하이라이트 박스 (STEP 3: 3개 구분된 칩 버튼 / STEP 4: 월간 측정 버튼)
          // ----------------------------------------------------------------
          if (_currentStep == 3 && targetRect != null)
            Positioned(
              left: targetRect.left - 4,
              top: targetRect.top - 4,
              width: targetRect.width + 8,
              height: targetRect.height + 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildDifficultyChip("낮음", isSelected: false),
                  const SizedBox(width: 8),
                  _buildDifficultyChip("보통", isSelected: true),
                  const SizedBox(width: 8),
                  _buildDifficultyChip("높음", isSelected: false),
                ],
              ),
            )
          else if (_currentStep == 4 && targetRect != null)
            Positioned(
              left: targetRect.left - 4,
              top: targetRect.top - 4,
              width: targetRect.width + 8,
              height: targetRect.height + 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.95),
                      blurRadius: 12,
                      spreadRadius: 4,
                    )
                  ],
                ),
                child: const Center(
                  child: Text(
                    "월간 측정하러 가기 >",
                    style: TextStyle(
                      color: Color(0xFF2E532B),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),

          // ----------------------------------------------------------------
          // 2. 메인 온보딩 팝업 카드 & 말풍선 꼬리
          // ----------------------------------------------------------------
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (_currentStep == 3)
                    Positioned(
                      top: -10,
                      right: 40,
                      child: ClipPath(
                        clipper: TriangleClipper(),
                        child: Container(
                          width: 18,
                          height: 12,
                          color: const Color(0xFFF1F3EE),
                        ),
                      ),
                    ),
                  if (_currentStep == 4)
                    Positioned(
                      top: -10,
                      right: 40,
                      child: ClipPath(
                        clipper: TriangleClipper(),
                        child: Container(
                          width: 18,
                          height: 12,
                          color: const Color(0xFFF1F3EE),
                        ),
                      ),
                    ),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F3EE),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_currentStep > 0)
                              GestureDetector(
                                onTap: _prevStep,
                                child: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black87),
                              )
                            else
                              const SizedBox(width: 24, height: 24),

                            const Spacer(),

                            if (_currentStep == 4)
                              GestureDetector(
                                onTap: _finishOnboarding,
                                child: const Icon(Icons.close, size: 24, color: Colors.black87),
                              )
                            else
                              const SizedBox(width: 24, height: 24),
                          ],
                        ),
                        const SizedBox(height: 12),

                        _buildStepContent(),

                        const SizedBox(height: 24),

                        if (_currentStep < 4)
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E532B),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              onPressed: _nextStep,
                              child: const Text(
                                "다음",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 홈 화면 스타일 그대로 재현한 난이도 칩 위젯
  Widget _buildDifficultyChip(String label, {required bool isSelected}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF2E532B) : const Color(0xFFE8F1DE),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.9),
            blurRadius: 10,
            spreadRadius: 3,
          )
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF616161),
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return Column(
          children: [
            const Text(
              "시작하기 전, 잠시만요!",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            Image.asset(
              'assets/turtle_character.png',
              height: 100,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            const Text(
              "터틀리를 100% 활용할 수 있도록\n핵심 팁을 바로 알려드릴게요!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
            ),
          ],
        );

      case 1:
        return Column(
          children: [
            const Text(
              "STEP 1",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Image.asset(
              'assets/turtle_hook.png',
              height: 90,
              errorBuilder: (_, __, ___) => Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F1DE),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.hearing,
                    size: 44,
                    color: Color(0xFF2E532B),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "거북목 교정 센서인 터틀훅을 착용해 주세요!\n자세가 무너질 때, 실시간 알림을 보낼드릴게요",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
            ),
          ],
        );

      case 2:
        return Column(
          children: [
            const Text(
              "STEP 2",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            const Text(
              "원활한 서비스를 위해\n앱 권한을 허용해 주세요",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 20),
            _permissionItem(Icons.notifications_none, "알림", "터틀리로부터 소식을 받을 수 있습니다"),
            const SizedBox(height: 12),
            _permissionItem(Icons.bluetooth, "블루투스", "터틀훅을 통해 고개 각도를 측정합니다"),
            const SizedBox(height: 12),
            _permissionItem(Icons.camera_alt_outlined, "카메라", "매월 거북목 상태를 측정합니다"),
          ],
        );

      case 3:
        return Column(
          children: [
            const Text(
              "STEP 3",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Text(
              "${widget.userName}님의 거북목 유형에 맞춰\n거북목 알림 난이도를 설정할 수 있어요",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Text("낮음 ➔ 여유로운 관리", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2E532B))),
                  SizedBox(height: 6),
                  Text("높음 ➔ 완벽한 관리", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2E532B))),
                ],
              ),
            ),
          ],
        );

      case 4:
        return Column(
          children: [
            const Text(
              "STEP 4",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            const Text(
              "거북목 알림 난이도를 설정하기 위해\n한 달에 한 번, 월간 거북목 측정을 해야 해요",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
            ),
            const SizedBox(height: 20),
            const Text(
              "[월간 측정하러 가기 >] 버튼을 눌러 주세요!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF2E532B)),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _permissionItem(IconData icon, String title, String desc) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Colors.black87),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
              Text(desc, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ],
          ),
        ),
      ],
    );
  }
}

class TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}