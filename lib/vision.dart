import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'style.dart';
import 'main.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class VisionPage extends StatefulWidget {
  @override
  _VisionPageState createState() => _VisionPageState();
}

class _VisionPageState extends State<VisionPage> {
  int step =
      0; // 0: 인사, 1: 자세 안내, 2: 측정 안내, 3: 측정 중, 4: 측정 완료, 5: 리포트 안내, 6: 종료 안내, 7: 예외 발생
  String loadingDots = "";
  Timer? _dotTimer;
  // bool isFinished = false; // 이따 주석 제거 (왜 없어졌는지 찾아보기)
  // bool isError = false; // 이따 주석 제거 (왜 없어졌는지 찾아보기)
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream, // 실시간 스트림 모드
      modelConfig: PoseDetectionModel.base,
    ),
  );

  // 좌표 담을 변수들
  Offset eyePoint = Offset.zero; // 눈
  Offset earPoint = Offset.zero; // 외이도 (Tragus)
  Offset c7Point = Offset.zero; // C7 (경추 7번)

  void nextStep() {
    setState(() {
      if (step == 2) {
        _startMeasurement();
      } else if (step < 6) {
        step++;
      }
    });
  }

  void _startMeasurement() {
    setState(() => step = 3); // 측정 시작 단계로 이동
    int count = 0;

    _dotTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        count++;
        loadingDots = "." * (count % 4);

        if (count == 3) {
          timer.cancel();
          _sendToDataToService(); // 백엔드 통신 시뮬레이션
        }
      });
    });
  }

  // 실제 카메라 프레임 분석 함수 (MediaPipe/ML Kit 연동부)
  void processImage(InputImage inputImage) async {
    final List<Pose> poses = await poseDetector.processImage(inputImage);

    for (Pose pose in poses) {
      // 1. 필요한 랜드마크 데이터 가져오기

      if (step == 3) {
        // 3단계: 측정 중일 때만 실행
        final rightEye = pose.landmarks[PoseLandmarkType.rightEye];
        final rightEar = pose.landmarks[PoseLandmarkType.rightEar];
        final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];

        setState(() {
          // 2. 여기서 x, y 좌표가 변수에 담깁니다!
          eyePoint = Offset(eye?.x ?? 0, eye?.y ?? 0);
          earPoint = Offset(ear?.x ?? 0, ear?.y ?? 0);
          c7Point = Offset(shoulder?.x ?? 0, shoulder?.y ?? 0);

          // 3. 백엔드 전송용 리스트(Batch)에 저장
          _coordinateBatch.add({
            'eyeX': eyePoint.dx,
            'eyeY': eyePoint.dy,
            'earX': earPoint.dx,
            'earY': earPoint.dy,
            'c7X': c7Point.dx,
            'c7Y': c7Point.dy,
          });
        });
      }
      @override
      void dispose() {
        _poseDetector.close(); // 카메라와 디텍터를 꼭 닫아줘야 성능 저하가 없어요.
        super.dispose();
      }
    }
  }

  void _sendToDataToService() async {
    // 실제로는 여기서 3초간의 좌표 중 최적값을 전송
    // 지금은 시뮬레이션, 나중에 AuthService.sendVisionData(_coordinateBatch) 연동
    await Future.delayed(const Duration(seconds: 1));
    bool success = true; // 예외 처리 테스트 시 false로 변경 가능 -> 이건 연동 아닌가?

    setState(() {
      if (success) {
        step = 4; // 완료 단계
      } else {
        step = 7; // 예외 단계
        // isError = true;
      }
    });
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
            if (step == 6 || step == 7) ...[
              SizedBox(width: 20),
              GestureDetector(
                onTap: () => step == 6
                    ? Navigator.pop(context)
                    : setState(() => step = 1),
                child: Text(
                  step == 6 ? "종료" : "재시도",
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
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _buildSpeechBubble(
                      _getStepText(),
                      _shouldShowButton(),
                      nextStep,
                    ),
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
      case 0:
        return "안녕하세요 \n월간 거북목 측정에 \n오신 것을 환영합니다!";
      case 1:
        return "머리, 목, 어깨가 \n전부 카메라에 나오도록 \n옆을 바라봐 주세요";
      case 2:
        return "거북목 측정을 위해 \n3초간 자세를 유지해 주세요";
      case 3:
        return "거북목 측정중 $loadingDots";
      case 4:
        return "월간 거북목 측정이 \n완료되었습니다!";
      case 5:
        return "월간 거북목 측정 결과는 \n월간 리포트에서 확인해 주세요";
      case 6:
        return "종료 버튼을 누르면 \n월간 거북목 측정이 종료됩니다 \n다음 달에 다시 만나요!";
      case 7:
        return "거북목 측정이 어렵습니다 \n다시 시도해 주세요";
      default:
        return "";
    }
  }

  bool _shouldShowButton() {
    // 3단계(측정중), 6단계(종료 안내), 7단계(재시도)는 역삼각형 버튼 숨김
    if ([3, 6, 7].contains(step)) return false; // 수정 필요?
    return true;
  }
}

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
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            text,
            style: TextStyle(color: TColor.darkGreen, fontSize: 16),
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

var path = Path();
      // [오른쪽 옆모습 가이드 예시 좌표]
      // 머리 위치 (타원)
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.35),
          width: size.width * 0.4,
          height: size.height * 0.25,
        ),
        guidePaint,
      );

      // 목에서 어깨로 내려오는 라인
      path.moveTo(size.width * 0.4, size.height * 0.45); // 뒤통수 아래
      path.quadraticBezierTo(
        size.width * 0.4, size.height * 0.6, // 굴곡점
        size.width * 0.2, size.height * 0.7, // 어깨 끝
      );
      canvas.drawPath(path, guidePaint);
    }

    // 2. 실시간 추출 좌표 및 각도 선 (추출되었을 때만)
    if (eye != Offset.zero) {
      canvas.drawCircle(eye, 6, paintPoint);
      canvas.drawCircle(ear, 6, paintPoint);
      canvas.drawCircle(c7, 6, paintPoint);
      
      canvas.drawLine(eye, ear, paintLine);
      canvas.drawLine(ear, c7, paintLine);

      // 수평선 (CVA 기준선)
      canvas.drawLine(c7, Offset(c7.dx + 60, c7.dy), paintLine..color = Colors.black);

      // 측정 중/완료 시 텍스트만 표시 (CRA, CVA 라벨)
      if (step >= 3) {
        _drawAngleLabel(canvas, "CRA", ear.dx + 10, ear.dy - 20);
        _drawAngleLabel(canvas, "CVA", c7.dx + 20, c7.dy - 20);
      }
    }
  }

void _drawAngleLabel(Canvas canvas, String text, double x, double y) {
    final tp = TextPainter(
      text: TextSpan(
        text: text, 
        style: const TextStyle(color: Colors.yellow, fontSize: 12, fontWeight: FontWeight.bold)
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
