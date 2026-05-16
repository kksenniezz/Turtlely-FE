import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'style.dart';
import 'main.dart';
import 'services/mediapipe_service.dart';

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

  final MediaPipeService _mediaPipeService = MediaPipeService();

  // 좌표 담을 변수들
  Offset eyePoint = Offset.zero; // 눈
  Offset earPoint = Offset.zero; // 외이도 (Tragus)
  Offset c7Point = Offset.zero; // C7 (경추 7번)

  @override
  void initState() {
    super.initState();
    _bootUp();
  }

  // 서비스의 카메라를 깨우고 좌표 스트림을 구독합니다.
  Future<void> _bootUp() async {
    await _mediaPipeService.initializeCamera();
    if (!mounted) return;
    setState(() {}); // 카메라 켜졌으니 빌드 갱신

    // 📡 서비스가 보내주는 실시간 좌표 신호 캐치하기
    _mediaPipeService.poseStream.listen((poses) {
      if (!mounted) return;
      setState(() {
        // 미디어파이프가 찾은 실시간 좌표를 화면 변수에 매핑
        eyePoint = poses['eye'] ?? Offset.zero;
        earPoint = poses['ear'] ?? Offset.zero;
        c7Point = poses['c7'] ?? Offset.zero;
      });
    });
  }

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
    }); // 측정 시작 단계로 이동

    _mediaPipeService.coordinateBatch.clear(); // 이전 측정 데이터 초기화

    int count = 0;
    _dotTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      setState(() {
        count++;
        loadingDots = "." * (count % 4);
      });

      if (count == 3) {
        timer.cancel();

        bool success = await _mediaPipeService
            .sendVisionData(); // 실제 백엔드 통신 함수 호출

        setState(() {
          if (success) {
            step = 4; // 측정 완료 단계
          } else {
            step = 7; // 예외 발생 단계
          }
        });
      }
    });
  }

  String _getStepText() {
    switch (step) {
      case 0:
        return "안녕하세요 \n월간 거북목 측정에 \n오신 것을 환영합니다!";
      case 1:
        return "머리, 목, 어깨가 \n전부 카메라에 나오도록 \n왼쪽을 바라봐 주세요";
      case 2:
        return "거북목 측정을 위해 \n3초간 자세를 유지해 주세요 \n 버튼을 누르면 바로 시작됩니다!";
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
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => _showExitDialog(context),
        ),
        title: const Text(
          "월간 거북목 측정",
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
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
      body: Stack(
        children: [
          // 1. 카메라 프리뷰 및 가이드라인 (CVA/CRA 선)
          Positioned.fill(
            child:
                _mediaPipeService.isInitialized &&
                    _mediaPipeService.cameraController != null
                ? CameraPreview(_mediaPipeService.cameraController!)
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
          ),
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
              crossAxisAlignment: CrossAxisAlignment.end, // 위치 보고 end로 바꿀 수도
              children: [
                Image.asset(
                  'side_turtle.png',
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
                  size: const Size(20, 15),
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
    // 1. [페인트 세팅] 사람 외형 프로필 선
    final profilePaint = Paint()
      ..color = TColor.darkGreen.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    // 2. [페인트 세팅] 내 포즈 스켈레톤 선
    final skeletonPaint = Paint()
      ..color = TColor.buttonGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    // 3. [페인트 세팅] 랜드마크 점
    final pointPaint = Paint()
      ..color = TColor.buttonGreen
      ..style = PaintingStyle.fill;

    // 파트 A: 사람 외형 프로필 가이드라인 (배경 고정)
    var profilePath = Path();

    // 스마트폰 화면 비율에 절대 찌그러지지 않도록 중심점과 반지름(반응형 방어 크기) 정의
    final double centerX = size.width * 0.5;
    final double centerY = size.height * 0.35; // 화면 위쪽에 예쁘게 안착하도록 세팅

    profilePath.moveTo(centerX + 30, centerY - 170);

    // 1. 뒤통수 -> 목덜미 -> 등으로 떨어지는 선 (우측 라인)
    profilePath.cubicTo(
      centerX + 210,
      centerY - 140, // 뒤통수 볼륨
      centerX + 140,
      centerY + 50, // 목덜미 굴곡
      centerX + 200,
      centerY + 300, // 승모근 타고 내려가는 등 선
    );

    // 2. 정수리 -> 이마 (좌측 라인 시작)
    profilePath.moveTo(centerX + 30, centerY - 170);
    profilePath.quadraticBezierTo(
      centerX - 60,
      centerY - 170,
      centerX - 110,
      centerY - 100,
    ); // 정수리 앞쪽 둥글림

    // 3. 이마 -> 코 -> 입 -> 턱 (이미지 속 얼굴 상세 굴곡 복사)
    profilePath.lineTo(centerX - 130, centerY - 45); // 이마 라인
    profilePath.quadraticBezierTo(
      centerX - 180,
      centerY - 15,
      centerX - 175,
      centerY + 5,
    ); // 둥근 코
    profilePath.lineTo(centerX - 150, centerY + 25); // 코 밑
    profilePath.quadraticBezierTo(
      centerX - 150,
      centerY + 45,
      centerX - 145,
      centerY + 65,
    ); // 입술과 턱 구역
    profilePath.quadraticBezierTo(
      centerX - 150,
      centerY + 95,
      centerX - 115,
      centerY + 115,
    ); // 턱끝 둥글림

    // 4. 턱밑 -> 앞목 -> 앞가슴으로 툭 떨어지는 선
    profilePath.quadraticBezierTo(
      centerX - 80,
      centerY + 120,
      centerX - 90,
      centerY + 170,
    ); // 목 라인
    profilePath.cubicTo(
      centerX - 110,
      centerY + 220,
      centerX - 170,
      centerY + 270,
      centerX - 200,
      centerY + 320, // 화면 왼쪽 아래로 자연스럽게 나가는 앞가슴 선
    );

    canvas.drawPath(profilePath, profilePaint);

    // 파트 B: 실시간 포즈 스켈레톤 (미디어파이프 좌표 연동)
    if (eye != Offset.zero && ear != Offset.zero && c7 != Offset.zero) {
      // 1. [스켈레톤 선] 눈-귀, 귀-C7 연결 (CRA, CVA 각도 모양 생성)
      canvas.drawLine(eye, ear, skeletonPaint);
      canvas.drawLine(ear, c7, skeletonPaint);

      // 2. [CVA 수직 기준선] CVA 연산을 위한 C7 중심의 수직 지지선 드로잉 (흰색)
      // C7에서 위쪽으로 수직으로 뻗는 선 (수직 기준)
      canvas.drawLine(
        c7,
        Offset(c7.dx, c7.dy - 80), // C7 위쪽으로 80px 뻗음
        skeletonPaint
          ..color = Colors.white
          ..strokeWidth = 3.0,
      );

      // 3. [랜드마크 점] 눈, 귀, C7 위치에 노란색 점 찍기
      canvas.drawCircle(eye, 6, pointPaint);
      canvas.drawCircle(ear, 6, pointPaint);
      canvas.drawCircle(
        c7,
        6,
        pointPaint..color = const Color(0xFFFFD700),
      ); // C7 점

      // 4. [각도 라벨] 측정 단계 이상 진입했을 때 각 랜드마크 각도 식별 태그 부착
      if (step >= 3) {
        _drawAngleLabel(canvas, "CRA", ear.dx + 10, ear.dy - 25);
        _drawAngleLabel(canvas, "CVA", c7.dx + 15, c7.dy - 35);
      }
    }
  }

  // 각도 라벨 드로잉 도우미 함수
  void _drawAngleLabel(Canvas canvas, String text, double x, double y) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.yellow, // 선명한 노란색
          fontSize: 14,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black38, // 글씨 가독성을 위한 약간의 배경색
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

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
                    fontWeight: FontWeight.bold,
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
        style: const TextStyle(
          color: Colors.black,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
