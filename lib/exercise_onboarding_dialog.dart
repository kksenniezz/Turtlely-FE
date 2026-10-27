import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'exercise.dart'; // exerciseBookmarkKey, exerciseFabKey 참조

class ExerciseOnboardingDialog extends StatefulWidget {
  final String userName;
  final VoidCallback onComplete;

  const ExerciseOnboardingDialog({
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
    bool hasSeenOnboarding = prefs.getBool('has_seen_exercise_onboarding') ?? false;

    if (!hasSeenOnboarding && context.mounted) {
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withOpacity(0.6),
        pageBuilder: (context, anim1, anim2) {
          return ExerciseOnboardingDialog(
            userName: userName,
            onComplete: () async {
              await prefs.setBool('has_seen_exercise_onboarding', true);
              if (onComplete != null) onComplete();
            },
          );
        },
      );
    }
  }

  @override
  State<ExerciseOnboardingDialog> createState() => _ExerciseOnboardingDialogState();
}

class _ExerciseOnboardingDialogState extends State<ExerciseOnboardingDialog> {
  int _currentStep = 1; // 1: Step1, 2: Step2, 3: Step3

  // 실제 위젯의 위치(Offset)와 크기(Size)를 추적하는 함수
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
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _finishOnboarding();
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() => _currentStep--);
    }
  }

  void _finishOnboarding() {
    widget.onComplete();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // 실시간 위치 추적
    Rect? bookmarkRect = _currentStep == 2 ? _getWidgetRect(exerciseBookmarkKey) : null;
    Rect? fabRect = _currentStep == 3 ? _getWidgetRect(exerciseFabKey) : null;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ----------------------------------------------------------------
          // 1. 스팟라이트 (실제 버튼 위치 정밀 조준)
          // ----------------------------------------------------------------
          if (_currentStep == 2 && bookmarkRect != null) ...[
            // Step 2: 상단 우측 북마크 버튼
            Positioned(
              left: bookmarkRect.left,
              top: bookmarkRect.top,
              width: bookmarkRect.width,
              height: bookmarkRect.height,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.95),
                      blurRadius: 14,
                      spreadRadius: 4,
                    )
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.bookmark,
                    color: Color(0xFF3B5524),
                    size: 28,
                  ),
                ),
              ),
            ),
          ] else if (_currentStep == 3 && fabRect != null) ...[
            // Step 3: 하단 우측 거북목 가이드 플로팅 버튼
            Positioned(
              left: fabRect.left,
              top: fabRect.top,
              width: fabRect.width,
              height: fabRect.height,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1DE),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.95),
                      blurRadius: 16,
                      spreadRadius: 6,
                    )
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.accessibility_new,
                    color: Color(0xFF3B5524),
                    size: 30,
                  ),
                ),
              ),
            ),
          ],

          // ----------------------------------------------------------------
          // 2. 메인 온보딩 팝업 카드 & 말풍선 Pointer
          // ----------------------------------------------------------------
          Align(
            alignment: _currentStep == 3 ? Alignment.bottomCenter : Alignment.center,
            child: Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: _currentStep == 3 ? 160 : 0, // Step 3은 플로팅 버튼 바로 위쪽 배치
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Step 2: 상단 우측 북마크 포인터 (위쪽 가리킴)
                  if (_currentStep == 2)
                    Positioned(
                      top: -10,
                      right: 18,
                      child: ClipPath(
                        clipper: TriangleClipper(isUpward: true),
                        child: Container(width: 18, height: 12, color: const Color(0xFFF1F3EE)),
                      ),
                    ),

                  // Step 3: 하단 우측 플로팅 버튼 포인터 (아래쪽 가리킴)
                  if (_currentStep == 3)
                    Positioned(
                      bottom: -10,
                      right: 20,
                      child: ClipPath(
                        clipper: TriangleClipper(isUpward: false),
                        child: Container(width: 18, height: 12, color: const Color(0xFFF1F3EE)),
                      ),
                    ),

                  // 팝업 본체
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
                        // 상단 영역 (뒤로가기 버튼)
                        Row(
                          children: [
                            if (_currentStep > 1)
                              GestureDetector(
                                onTap: _prevStep,
                                child: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black87),
                              )
                            else
                              const SizedBox(height: 24),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 단계별 컨텐츠
                        _buildStepContent(),

                        const SizedBox(height: 24),

                        // 다음 / 확인 버튼
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E532B),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: _nextStep,
                            child: Text(
                              _currentStep == 3 ? "확인" : "다음",
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
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

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 1:
        return Column(
          children: [
            const Text(
              "EXERCISE ZONE은",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Text(
              "${widget.userName}님의 거북목 유형",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2E532B)),
            ),
            const SizedBox(height: 6),
            const Text(
              "맞춤 운동 가이드를 제공합니다",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        );

      case 2:
        return const Column(
          children: [
            Text(
              "북마크 버튼을 누르면\n저장한 영상을 다시 볼 수 있어요",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2E532B), height: 1.4),
            ),
          ],
        );

      case 3:
        return const Column(
          children: [
            Text(
              "[거북목 교정 가이드] 버튼을 눌러\n정확한 자세로 운동을 배워보세요!",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2E532B), height: 1.4),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// 삼각 꼬리 Clipper
class TriangleClipper extends CustomClipper<Path> {
  final bool isUpward;
  TriangleClipper({this.isUpward = true});

  @override
  Path getClip(Size size) {
    final path = Path();
    if (isUpward) {
      path.moveTo(size.width / 2, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    }
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}