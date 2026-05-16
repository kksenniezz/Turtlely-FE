import 'dart:async';
import 'package:flutter/material.dart';
import 'style.dart';
import 'main.dart';
// import 'service/mediapipe_service.dart';

class VisionPage extends StatefulWidget {
  const VisionPage({Key? key}) : super(key: key);

  @override
  _VisionPageState createState() => _VisionPageState();
}

class _VisionPageState extends State<VisionPage> {
  int step =
      0; // 0: 인사, 1: 자세 안내, 2: 측정 안내, 3: 측정 중, 4: 측정 완료, 5: 리포트 안내, 6: 종료 안내, 7: 예외 발생
  String loadingDots = "";
  Timer? _dotTimer;

  // final MediaPipeService _mediaPipeService = MediaPipeService();

  // 좌표 담을 변수들
  Offset eyePoint = Offset.zero; // 눈
  Offset earPoint = Offset.zero; // 외이도 (Tragus)
  Offset c7Point = Offset.zero; // C7 (경추 7번)

  @override
  void dispose() {
    _dotTimer?.cancel();
    super.dispose();
  }

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
    setState(() {
      step = 3;
      eyePoint = Offset.zero;
      earPoint = Offset.zero;
      c7Point = Offset.zero;
    }); // 측정 시작 단계로 이동

    // _mediaPipeService.coordinateBatch.clear(); // 이전 측정 데이터 초기화

    int count = 0;
    _dotTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      setState(() {
        count++;
        loadingDots = "." * (count % 4);
      });

      if (count == 3) {
        timer.cancel();

        // bool success = await _mediaPipeService.sendVisionData(); // 실제 백엔드 통신 함수 호출

        // setState(() {
        //  if (success) {
        //    step = 4; // 측정 완료 단계
        //  } else {
        //    step = 7; // 예외 발생 단계
        //  }
        // });
      }
    });
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
    if ([3, 6, 7].contains(step)) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => _showExitDialog(context),
        ),
        title: Row(
          children: [
            Text("월간 거북목 측정", style: TextStyle(fontWeight: FontWeight.bold)),
            if (step == 6 || step == 7) ...[
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () {
                  if (step == 6) {
                    Navigator.pop(context);
                  } else {
                    setState(() => step = 1);
                  }
                },
                child: Text(
                  step == 6 ? "종료" : "재시도",
                  style: TextStyle(
                    color: TColor.darkGreen,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
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
              crossAxisAlignment: CrossAxisAlignment.start, // 위치 보고 end로 바꿀 수도
              children: [
                Image.asset(
                  'assets/side_turtle.png',
                  width: 120,
                  height: 120,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 120,
                      height: 120,
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                Expanded(
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

  // 말풍선 위젯
  Widget _buildSpeechBubble(
    String text,
    bool showNextButton,
    VoidCallback? onTap,
  ) {
    return Container(
      width: 220,
      constraints: BoxConstraints(minHeight: 110),
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
}

// -------------------------------------------------------------------------
// 🎨 커스텀 그래픽 페인터 모듈 영역
// -------------------------------------------------------------------------

class PosePainter extends CustomPainter {
  final Offset eye;
  final Offset ear;
  final Offset c7;
  final int step;

  PosePainter({
    required this.eye,
    required this.ear,
    required this.c7,
    required this.step,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 가이드 가이드라인 페인트 (초록빛 흐릿한 타원형 점선 대용 세팅)
    final guidePaint = Paint()
      ..color = Colors.green.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final paintPoint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.fill;
    final paintLine = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    // 1단계(안내) 및 3단계(측정) 진행 시 고정 가이드라인 드로잉
    if (step == 1 || step == 2 || step == 3) {
      var path = Path();
      // 머리 폼 뼈대 타원 가이드라인
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.35),
          width: size.width * 0.4,
          height: size.height * 0.25,
        ),
        guidePaint,
      );

      // 후두부에서 견갑골/어깨 라인으로 내려가는 2D 곡선 가이드
      path.moveTo(size.width * 0.4, size.height * 0.45);
      path.quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.6,
        size.width * 0.2,
        size.height * 0.7,
      );
      canvas.drawPath(path, guidePaint);
    }

    // 2. 실시간 추출 랜드마크 스켈레톤 라인 (좌표값이 매핑된 경우만 렌더링)
    if (eye != Offset.zero && ear != Offset.zero && c7 != Offset.zero) {
      canvas.drawCircle(eye, 6, paintPoint);
      canvas.drawCircle(ear, 6, paintPoint);
      canvas.drawCircle(c7, 6, paintPoint);

      canvas.drawLine(eye, ear, paintLine);
      canvas.drawLine(ear, c7, paintLine);

      // CVA 연산용 기준 매칭 수평 지지선 드로잉
      canvas.drawLine(
        c7,
        Offset(c7.dx + 60, c7.dy),
        paintLine..color = Colors.white,
      );

      // 측정 단계 이상 진입했을 때 각 랜드마크 각도 식별 태그 부착
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
        style: const TextStyle(
          color: Colors.yellow,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// 역삼각형 아이콘 버튼 드로잉 페인터
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

// -------------------------------------------------------------------------
// 🚪 모달 및 다이얼로그 도우미 함수 영역
// -------------------------------------------------------------------------

void _showExitDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => Center(
      child: Material(
        color: Colors.transparent,
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
                padding: EdgeInsets.only(top: 50, left: 20, right: 20),
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
                      MaterialPageRoute(
                        builder: (context) => TurtlelyMainPage(),
                      ),
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
