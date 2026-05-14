import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'style.dart';
// import 'package:camera/camera.dart'; // 카메라 제어
// 구글 ML Kit 사용 시 (혹은 프로젝트에서 쓰는 포즈 인식 라이브러리)
// import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class VisionPage extends StatefulWidget {
  @override
  _VisionPageState createState() => _VisionPageState();
}

class _VisionPageState extends State<VisionPage> {
  int step = 0; // 수정 
  String loadingDots = "";
  Timer? _dotTimer;
  // bool isFinished = false; // 이따 주석 제거 (왜 없어졌는지 찾아보고)
  // bool isError = false; // 이따 주석 제거

  // 가상의 좌표 (실제 구현 시 ML Kit의 Pose 데이터를 이곳에 매핑하세요)
  Offset eyePoint = const Offset(200, 250); // 눈
  Offset earPoint = const Offset(240, 280); // 외이도 (Tragus)
  Offset c7Point = const Offset(250, 400); // C7 (경추 7번)

  void nextStep() {
    setState(() {
      if (step == 3) {
        startLoading(); // 4단계로 진입
      } else if (step < 7) {
        step++;
      }
    });
  }

  void _startMeasurement() {
    setState(() => step = 3; // 측정 시작 단계로 이동
    int count =  0;

    int dotCount = 0;
    _dotTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        dotCount++;
        loadingDots = "." * (dotCount % 4);

        if (dotCount == 3) {
          timer.cancel();
          _sendToDataToService(); // 백엔드 통신 시뮬레이션
        }
      });
    });
  }
}

void _sendToDataToService() async {
  // 실제로는 여기서 3초간의 좌표 중 최적값을 전송
  await Future.delayed(Duration(seconds: 1));
    bool success = true; // 예외 처리 테스트 시 false로 변경 가능

    setState(() {
      if (success) {
        step = 5; // 5-1 단계
      } else {
        step = 8; // 6-1 예외 발생
        // isError = true;
      }
    });
}

// 여기서부터 //

// 말풍선 위젯
Widget _buildSpeechBubble(
  String text,
  bool showNextButton,
  VoidCallback? onTap,
) {
  return Container(
    width: 220,
    constraints: BoxConstraints(minHeight: 100),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: TColor.lightGreen,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
        bottomRight: Radius.circular(24),
        bottomLeft: Radius.circular(0),
      ),
    ),
    child: Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            text,
            style: TextStyle(
              color: TColor.darkGreen,
              fontSize: 16,
              fontFamily: 'Pretendard',
            ),
          ),
        ),
        if (showNextButton)
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: onTap,
              child: CustomPaint(
                size: const Size(20, 20),
                painter: TrianglePainter(color: TColor.darkGreen),
              ),
            ),
          ),
      ],
    ),
  );
}

// 역삼각형 버튼 Painter
class TrianglePainter extends CustomPainter {
  final Color color;
  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()..color = color;
    var path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

  // 각도 계산 로직
  double get cvaAngle {
    // 외이도와 C7 사이의 수직선 기준 각도
    return (math.atan2(earPoint.dy - c7Point.dy, earPoint.dx - c7Point.dx) *
            180 /
            math.pi)
        .abs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => _showExitDialog(context),
        ),
        title: Row(
          children: [
            Text("월간 거북목 측정"),
            if (step == 53 || step == 61) ...[
              SizedBox(width: 20),
              GestureDetector(
                onTap: () => step == 53
                    ? Navigator.pop(context)
                    : setState(() => step = 3),
                child: Text(
                  step == 53 ? "종료" : "재시도",
                  style: TextStyle(color: TColor.darkGreen, fontSize: 18),
                ),
              ),
            ],
          ],
        ),
      ),
      body: Stack(
        children: [
          // 1. 카메라 프리뷰 및 가이드라인 (CVA/CRA 선)
          Positioned.fill(
            child: CustomPaint(
              painter: PosePainter(
                eye: eyePoint,
                ear: earPoint,
                c7: c7Point,
                step: step,
              ),
            ),
          ),

          // 2. 거북이와 말풍선 배치
          Positioned(
            bottom: 50,
            left: 20,
            right: 20,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/side_turtle.png', width: 120, height: 120),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 10), // 가이드라인 안 가리게 살짝 아래로
                  child: _buildSpeechBubble(
                    _getStepText(),
                    _shouldShowButton(),
                    nextStep,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStepText() {
    switch (step) {
      case 1:
        return "안녕하세요 \n월간 거북목 측정에 \n오신 것을 환영합니다!";
      case 2:
        return "머리, 목, 어깨가 \n전부 카메라에 나오도록 \n옆을 바라봐 주세요";
      case 3:
        return "거북목 측정을 위해 \n3초간 자세를 유지해 주세요";
      case 4:
        return "거북목 측정중 $loadingDots";
      case 51:
        return "월간 거북목 측정이 \n완료되었습니다!";
      case 52:
        return "월간 거북목 측정 결과는 \n월간 리포트에서 확인해 주세요";
      case 53:
        return "종료 버튼을 누르면 \n월간 거북목 측정이 종료됩니다 \n다음 달에 다시 만나요!";
      case 61:
        return "거북목 측정이 어렵습니다 \n다시 시도해 주세요";
      default:
        return "";
    }
  }

  bool _shouldShowButton() {
    // 4단계(측정중), 5-3단계(종료 안내), 6-1단계(재시도)는 역삼각형 버튼 없음
    if ([4, 53, 61].contains(step)) return false;
    return true;
  }
}

void _showExitDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => Center(
      child: Container(
        width: 336,
        height: 224,
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 67),
              child: Text(
                '월간 거북목 측정을 종료하시겠습니까?\n\n현재 측정은 저장되지 않습니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _dialogButton(
                  "취소",
                  const Color(0xFFD9D9D9),
                  () => Navigator.pop(context),
                ),
                _dialogButton("확인", const Color(0x7F235E26), () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => TurtlelyMainPage()),
                    (route) => false,
                  );
                }),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

Widget _dialogButton(String label, Color color, VoidCallback onPressed) {
  return GestureDetector(
    onTap: onPressed,
    child: Container(
      width: 135,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.black, fontSize: 16),
      ),
    ),
  );
}
