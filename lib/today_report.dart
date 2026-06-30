import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'style.dart';
import 'daily_report_storage.dart';
import 'posture_api_service.dart';

class TodayReportView extends StatefulWidget {
  final DateTime date;
  final int? dailyId;
  const TodayReportView({super.key, required this.date, this.dailyId});

  @override
  State<TodayReportView> createState() => _TodayReportViewState();
}

class _TodayReportViewState extends State<TodayReportView> {
  bool isLoading = true;

  List<double> cvaHistory     = [];
  List<String> timeHistory    = [];
  List<String> postureHistory = [];
  double avgCva        = 0.0;
  int    warningCount  = 0;
  int    cautionCount  = 0;
  
  // 💡 고정 하드코딩 탈출을 위한 서버 실시간 연동 스코어 변수
  int    _serverScore  = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final dateKey = "${widget.date.year}-${widget.date.month.toString().padLeft(2,'0')}-${widget.date.day.toString().padLeft(2,'0')}";
    
    // 1. Hive에서 그래프/히트맵용 로컬 데이터 먼저 땡겨오기
    final localData = await DailyReportStorage.loadHistory(dateKey);
    if (localData != null) {
      setState(() {
        cvaHistory     = List<double>.from(localData['cvaHistory'] ?? []);
        timeHistory    = List<String>.from(localData['timeHistory'] ?? []);
        postureHistory = List<String>.from(localData['postureHistory'] ?? []);
      });
    }

    // 2. 서버에서 점수/평균CVA/횟수 조회하기 통합 파이프라인
    final api = ApiService();
    Map<String, dynamic>? serverData;

    if (widget.dailyId != null) {
      // 🟢 Case A: 달력에서 id를 받아 들고 들어왔을 때
      serverData = await api.getDailyReport(widget.dailyId!);
    } else {
      // 🟢 Case B: 그냥 리포트 탭으로 들어와서 id가 없을 때 ➡️ 오늘 날짜 데이터 매핑 시도
      final reports = await api.getCalendarReports();
      if (reports.isNotEmpty) {
        final targetDateStr = "${widget.date.year}-${widget.date.month.toString().padLeft(2,'0')}-${widget.date.day.toString().padLeft(2,'0')}";
        int? foundId;
        for (final report in reports) {
          if (report['reportDate'] == targetDateStr) {
            foundId = report['dailyId'] as int?;
            break;
          }
        }
        if (foundId != null) {
          serverData = await api.getDailyReport(foundId);
        }
      }
    }

    // 3. 최종 매핑 상태 업데이트
    if (serverData != null) {
      setState(() {
        // 💡 0점 방지 방어막: 서버가 준 점수를 즉시 변수에 직접 저장!
        _serverScore   = serverData!['postureScore'] ?? 0;
        avgCva         = (serverData!['averageCva'] ?? 0.0).toDouble();
        warningCount   = serverData!['warningCount'] ?? 0;
        cautionCount   = serverData!['cautionCount'] ?? 0;
        isLoading      = false;
      });
    } else {
      // 만약 오늘 아직 측정 전이라 서버 데이터가 아예 없다면 로컬 기본값 상태로 로딩 해제
      setState(() => isLoading = false);
    }
  }

  // 💡 기존 로컬 계산식 제거 ➡️ 서버 진짜 점수와 100% 동기화 매핑!
  int get postureScore => _serverScore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "${widget.date.year}년 ${widget.date.month}월 ${widget.date.day}일 리포트",
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (avgCva == 0.0 && cvaHistory.isEmpty)
              ? const Center(child: Text("해당 날짜의 데이터가 없어요", style: TextStyle(color: Colors.grey)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. 자세 점수 카드
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F8E9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFC8E6C9)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("자세 유지 점수", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text("측정 시간 대비 바른 자세 비율", style: TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            Text(
                              "$postureScore점",
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF33691E)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // 2. 평균 고개 각도 분석
                      const Text("평균 고개 각도 분석", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F8E9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  const Text("평균 CVA 각도", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${avgCva.toStringAsFixed(1)}°",
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1D9E75)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFCEBEB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  const Text("경고 횟수", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${warningCount + cautionCount}회",
                                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFE24B4A)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 일러스트 + 그래프
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 150,
                            height: 200,
                            child: CustomPaint(
                              painter: NeckAnglePainter(cvaAngle: avgCva),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: SizedBox(
                              height: 200,
                              child: NeckAngleChart(
                                angles: cvaHistory,
                                times: timeHistory,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // 3. 타임라인 히트맵
                      const Text("타임라인 히트맵", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      PostureHeatmap(postureHistory: postureHistory, timeHistory: timeHistory),
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
    );
  }
}

// ========================
// 목 각도 CustomPainter
// ========================
class NeckAnglePainter extends CustomPainter {
  final double cvaAngle;
  NeckAnglePainter({required this.cvaAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.5;

    final bodyPaint  = Paint()..color = const Color(0xFFE8D5C4)..style = PaintingStyle.fill;
    final bodyStroke = Paint()..color = const Color(0xFFC4A882)..style = PaintingStyle.stroke..strokeWidth = 1;

    canvas.drawOval(Rect.fromCenter(center: Offset(cx, size.height * 0.88), width: 60, height: 36), bodyPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, size.height * 0.88), width: 60, height: 36), bodyStroke);

    final neckPath = Path()
      ..moveTo(cx - 12, size.height * 0.76)
      ..quadraticBezierTo(cx - 14, size.height * 0.65, cx - 12, size.height * 0.57)
      ..lineTo(cx + 12, size.height * 0.57)
      ..quadraticBezierTo(cx + 14, size.height * 0.65, cx + 12, size.height * 0.76)
      ..close();
    canvas.drawPath(neckPath, bodyPaint);
    canvas.drawPath(neckPath, bodyStroke);

    canvas.drawOval(Rect.fromCenter(center: Offset(cx, size.height * 0.42), width: 48, height: 54), bodyPaint);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, size.height * 0.42), width: 48, height: 54), bodyStroke);

    final hairPaint = Paint()..color = const Color(0xFF5C3D2E)..style = PaintingStyle.fill;
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, size.height * 0.32), width: 50, height: 46), hairPaint);

    canvas.drawCircle(Offset(cx - 6, size.height * 0.40), 3, Paint()..color = const Color(0xFF5C3D2E));

    final c7Y = size.height * 0.65;
    canvas.drawCircle(Offset(cx, c7Y), 5, Paint()..color = const Color(0xFFE24B4A));

    canvas.drawLine(
      Offset(cx, size.height * 0.1),
      Offset(cx, size.height * 0.9),
      Paint()..color = Colors.grey.withOpacity(0.25)..strokeWidth = 1,
    );

    final angleRad = (90 - cvaAngle) * math.pi / 180;
    final endX = cx - math.cos(angleRad) * 60.0;
    final endY = c7Y - math.sin(angleRad) * 60.0;
    canvas.drawLine(
      Offset(cx, c7Y),
      Offset(endX, endY),
      Paint()..color = const Color(0xFF378ADD)..strokeWidth = 2..strokeCap = StrokeCap.round,
    );

    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, c7Y), width: 40, height: 40),
      -math.pi / 2,
      -angleRad,
      false,
      Paint()..color = const Color(0xFF378ADD).withOpacity(0.6)..strokeWidth = 1.5..style = PaintingStyle.stroke,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: "${cvaAngle.toStringAsFixed(1)}°",
        style: const TextStyle(color: Color(0xFF378ADD), fontSize: 13, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(cx + 14, c7Y - 28));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ========================
// 시간대별 그래프
// ========================
class NeckAngleChart extends StatelessWidget {
  final List<double> angles;
  final List<String> times;

  const NeckAngleChart({super.key, required this.angles, required this.times});

  @override
  Widget build(BuildContext context) {
    if (angles.isEmpty) return const SizedBox();

    const double warningLine = 50.0;
    final double minVal = (angles.reduce(math.min) - 5).clamp(20.0, 40.0);
    final double maxVal = (angles.reduce(math.max) + 5).clamp(60.0, 90.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFF1D9E75), borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 4),
            const Text("CVA 각도", style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(width: 12),
            Container(width: 10, height: 3, color: const Color(0xFFE24B4A)),
            const SizedBox(width: 4),
            const Text("경고 기준선", style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: CustomPaint(
            painter: _ChartPainter(
              angles: angles,
              times: times,
              warningLine: warningLine,
              minVal: minVal,
              maxVal: maxVal,
            ),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> angles;
  final List<String> times;
  final double warningLine, minVal, maxVal;

  _ChartPainter({required this.angles, required this.times, required this.warningLine, required this.minVal, required this.maxVal});

  @override
  void paint(Canvas canvas, Size size) {
    if (angles.isEmpty) return;
    const double padL = 32, padR = 8, padT = 8, padB = 28;
    final double chartW = size.width - padL - padR;
    final double chartH = size.height - padT - padB;

    double toX(int i) => padL + i * chartW / (angles.length - 1);
    double toY(double v) => padT + (1 - (v - minVal) / (maxVal - minVal)) * chartH;

    final gridPaint = Paint()..color = Colors.grey.withOpacity(0.1)..strokeWidth = 0.5;
    for (double v in [minVal, (minVal + maxVal) / 2, maxVal]) {
      canvas.drawLine(Offset(padL, toY(v)), Offset(padL + chartW, toY(v)), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: "${v.toInt()}°", style: const TextStyle(color: Colors.grey, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, toY(v) - 5));
    }

    final warnY = toY(warningLine);
    final warnPaint = Paint()..color = const Color(0xFFE24B4A)..strokeWidth = 1.5;
    double x = padL;
    while (x < padL + chartW) {
      canvas.drawLine(Offset(x, warnY), Offset(math.min(x + 6, padL + chartW), warnY), warnPaint);
      x += 10;
    }

    final fillPath = Path()..moveTo(toX(0), toY(angles[0]));
    for (int i = 1; i < angles.length; i++) {
      final cpx = (toX(i - 1) + toX(i)) / 2;
      fillPath.cubicTo(cpx, toY(angles[i - 1]), cpx, toY(angles[i]), toX(i), toY(angles[i]));
    }
    fillPath.lineTo(toX(angles.length - 1), toY(minVal));
    fillPath.lineTo(toX(0), toY(minVal));
    fillPath.close();
    canvas.drawPath(fillPath, Paint()..color = const Color(0xFF1D9E75).withOpacity(0.08));

    final linePath = Path()..moveTo(toX(0), toY(angles[0]));
    for (int i = 1; i < angles.length; i++) {
      final cpx = (toX(i - 1) + toX(i)) / 2;
      linePath.cubicTo(cpx, toY(angles[i - 1]), cpx, toY(angles[i]), toX(i), toY(angles[i]));
    }
    canvas.drawPath(linePath, Paint()..color = const Color(0xFF1D9E75)..strokeWidth = 2..style = PaintingStyle.stroke);

    for (int i = 0; i < angles.length; i++) {
      final isWarning = angles[i] < warningLine;
      canvas.drawCircle(Offset(toX(i), toY(angles[i])), 3.5, Paint()..color = isWarning ? const Color(0xFFE24B4A) : const Color(0xFF1D9E75));
      canvas.drawCircle(Offset(toX(i), toY(angles[i])), 3.5, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }

    final step = (times.length / 5).ceil();
    for (int i = 0; i < times.length; i += step) {
      final tp = TextPainter(
        text: TextSpan(text: times[i], style: const TextStyle(color: Colors.grey, fontSize: 8)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(toX(i) - tp.width / 2, size.height - padB + 4));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ========================
// 타임라인 히트맵
// ========================
class PostureHeatmap extends StatelessWidget {
  final List<String> postureHistory;
  final List<String> timeHistory;

  const PostureHeatmap({super.key, required this.postureHistory, required this.timeHistory});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("시간대별 자세 상태", style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 3,
            runSpacing: 3,
            children: postureHistory.map((posture) {
              Color color;
              if (posture == "warning") {
                color = const Color(0xFFE24B4A);
              } else if (posture == "caution") {
                color = const Color(0xFFFF9800);
              } else {
                color = const Color(0xFF1D9E75);
              }
              return Container(
                width: 10,
                height: 24,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          if (timeHistory.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(timeHistory.first, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(timeHistory.last, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFF1D9E75), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              const Text("정상", style: TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(width: 12),
              Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFFFF9800), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              const Text("주의", style: TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(width: 12),
              Container(width: 8, height: 8, decoration: BoxDecoration(color: const Color(0xFFE24B4A), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4),
              const Text("경고", style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}