import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'style.dart';
import 'monthly_report.dart';
import 'today_report.dart';
import 'daily_report_storage.dart';
import 'posture_api_service.dart';

class ReportView extends StatefulWidget {
  const ReportView({super.key});

  @override
  _ReportViewState createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  int _viewIndex = 0;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  PageController? _calendarPageController;
  final ScrollController _scrollController = ScrollController();

  final List<DateTime> _recordedDays = [];
  List<dynamic> _calendarReports = [];

  int?    _selectedScore;
  double  _avgCva        = 0.0;
  int     _warningCount  = 0;
  int     _cautionCount  = 0;
  List<double> _cvaHistory     = [];
  List<String> _timeHistory    = [];
  List<String> _postureHistory = [];
  bool    _isLoadingReport = false;

  @override
  void initState() {
    super.initState();
    _loadRecordedDays();
    _scrollController.addListener(() {
      if (_viewIndex == 1 && _scrollController.hasClients) {
        double screenHeight = MediaQuery.of(context).size.height;
        double centerOffset = _scrollController.offset + (screenHeight / 2);
        double itemHeight = 400.0;
        int monthOffset = (centerOffset / itemHeight).floor();
        DateTime now = DateTime.now();
        DateTime newDate = DateTime(now.year, now.month - monthOffset);
        if (newDate.month != _focusedDay.month || newDate.year != _focusedDay.year) {
          setState(() { _focusedDay = newDate; });
        }
      }
    });
  }

  Future<void> _loadRecordedDays() async {
    final api = ApiService();
    final reports = await api.getCalendarReports();

    final serverDates = <DateTime>[];
    for (final report in reports) {
      if (report['hasReport'] == true) {
        final dateStr = report['reportDate'] as String;
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          serverDates.add(DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])));
        }
      }
    }

    final hiveDates = await DailyReportStorage.getSavedDates();

    setState(() {
      _calendarReports = reports;
      _recordedDays.clear();
      _recordedDays.addAll(serverDates);

      for (final dateStr in hiveDates) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          try {
            final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
            if (!_recordedDays.any((d) => isSameDay(d, date))) {
              _recordedDays.add(date);
            }
          } catch (e) {
            debugPrint("날짜 파싱 오류: $dateStr");
          }
        }
      }
    });

    if (_hasRecord(_selectedDay!)) {
      final id = _getDailyId(_selectedDay!);
      await _loadFullData(_selectedDay!, id);
    }
  }

  Future<void> _loadFullData(DateTime date, int? dailyId) async {
    setState(() { _isLoadingReport = true; });

    final dateKey = "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";

    final localData = await DailyReportStorage.loadHistory(dateKey);
    if (localData != null) {
      setState(() {
        _cvaHistory     = List<double>.from(localData['cvaHistory'] ?? []);
        _timeHistory    = List<String>.from(localData['timeHistory'] ?? []);
        _postureHistory = List<String>.from(localData['postureHistory'] ?? []);
        _avgCva         = (localData['avgCva'] ?? 0.0).toDouble();
        _warningCount   = localData['warningCount'] ?? 0;
        _cautionCount   = localData['cautionCount'] ?? 0;
      });
    }

    if (dailyId != null) {
      final api = ApiService();
      final serverData = await api.getDailyReport(dailyId);
      if (serverData != null && mounted) {
        setState(() {
          _selectedScore = serverData['postureScore'];
          _avgCva        = (serverData['averageCva'] ?? _avgCva).toDouble();
          _warningCount  = serverData['warningCount'] ?? _warningCount;
          _cautionCount  = serverData['cautionCount'] ?? _cautionCount;
        });
      }
    }

    if (mounted) setState(() { _isLoadingReport = false; });
  }

  // ✅ 주간뷰 날짜 클릭 → 인라인 리포트
  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {
    setState(() {
      _selectedDay    = selectedDay;
      _focusedDay     = focusedDay;
      _selectedScore  = null;
      _avgCva         = 0.0;
      _cvaHistory     = [];
      _postureHistory = [];
      _timeHistory    = [];
      _warningCount   = 0;
      _cautionCount   = 0;
    });

    if (_hasRecord(selectedDay)) {
      final id = _getDailyId(selectedDay);
      await _loadFullData(selectedDay, id);
    }
  }

  // ✅ 월간뷰 날짜 클릭 → TodayReportView로 이동
  void _onMonthlyDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay  = focusedDay;
    });

    if (_hasRecord(selectedDay)) {
      final id = _getDailyId(selectedDay);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TodayReportView(date: selectedDay, dailyId: id),
        ),
      );
    }
  }

  int? _getDailyId(DateTime date) {
    final dateStr = "${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
    for (final dynamic report in _calendarReports) {
      if (report['reportDate'] == dateStr) return report['dailyId'] as int?;
    }
    return null;
  }

  Future<void> _exportCsv() async {
    if (_selectedDay == null) return;
    final dateKey = "${_selectedDay!.year}-${_selectedDay!.month.toString().padLeft(2,'0')}-${_selectedDay!.day.toString().padLeft(2,'0')}";
    final data = await DailyReportStorage.loadHistory(dateKey);
    if (data == null) {
      _showSnackBar("저장된 데이터가 없어요");
      return;
    }

    final List<double> accXHistory       = List<double>.from(data['accXHistory']       ?? []);
    final List<double> accYHistory       = List<double>.from(data['accYHistory']       ?? []);
    final List<double> accZHistory       = List<double>.from(data['accZHistory']       ?? []);
    final List<String> rawTimeHistory    = List<String>.from(data['rawTimeHistory']    ?? []);
    final List<double> cvaRawHistory     = List<double>.from(data['cvaRawHistory']     ?? []);
    final List<String> postureRawHistory = List<String>.from(data['postureRawHistory'] ?? []);

    StringBuffer csv = StringBuffer();
    csv.writeln('날짜,시간,accX,accY,accZ,CVA각도,자세상태');
    for (int i = 0; i < accXHistory.length; i++) {
      final timeStr = i < rawTimeHistory.length ? rawTimeHistory[i] : '';
      csv.writeln(
        '$dateKey,'
        '\t$timeStr,'
        '${accXHistory[i].toStringAsFixed(4)},'
        '${accYHistory.length > i ? accYHistory[i].toStringAsFixed(4) : ""},'
        '${accZHistory.length > i ? accZHistory[i].toStringAsFixed(4) : ""},'
        '${cvaRawHistory.length > i ? cvaRawHistory[i].toStringAsFixed(2) : ""},'
        '${postureRawHistory.length > i ? postureRawHistory[i] : ""}'
      );
    }

    try {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/turtlely_$dateKey.csv');
      await file.writeAsString(csv.toString());
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Turtlely 자세 측정 데이터 ($dateKey)',
      );
    } catch (e) {
      _showSnackBar("공유 실패");
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _hasRecord(DateTime day) => _recordedDays.any((d) => isSameDay(d, day));

  bool _canGoNext() {
    DateTime now = DateTime.now();
    int daysUntilSaturday = DateTime.saturday - _focusedDay.weekday;
    DateTime endOfCurrentWeek = _focusedDay.add(Duration(days: daysUntilSaturday));
    return endOfCurrentWeek.isBefore(DateTime(now.year, now.month, now.day));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: _viewIndex == 0
          ? FloatingActionButton(
              elevation: 3,
              backgroundColor: TColor.lightGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: Color(0xFFC8E6C9))),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MonthlyReportView())),
              child: const Icon(Icons.description, color: TColor.darkGreen),
            )
          : null,
      body: SafeArea(child: _viewIndex == 1 ? _buildMonthlyView() : _buildWeeklyView()),
    );
  }

  Widget _buildWeeklyView() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40),
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_left, size: 28), onPressed: () => _calendarPageController?.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut)),
                    Text("${_focusedDay.year}년 ${_focusedDay.month}월", style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: TColor.darkGreen)),
                    IconButton(icon: Icon(Icons.arrow_right, size: 28, color: _canGoNext() ? Colors.black : Colors.grey.shade300), onPressed: _canGoNext() ? () => _calendarPageController?.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut) : null),
                  ],
                ),
                IconButton(icon: const Icon(Icons.calendar_month_outlined, size: 24), onPressed: () => setState(() { _viewIndex = 1; _focusedDay = DateTime.now(); })),
              ],
            ),
          ),
          TableCalendar(
            locale: 'ko_KR', firstDay: DateTime.utc(2024, 1, 1), lastDay: DateTime.now(), focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.week, headerVisible: false,
            onCalendarCreated: (controller) => _calendarPageController = controller,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: _onDaySelected,
            onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
            calendarBuilders: _customBuilders(),
          ),
          const Divider(thickness: 1, color: Color(0xFFEEEEEE), height: 40),
          if (_hasRecord(_selectedDay!)) _buildActiveContent() else _buildEmptyContent(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildActiveContent() {
    if (_isLoadingReport) return const Center(child: Padding(padding: EdgeInsets.only(top: 50), child: CircularProgressIndicator()));

    final double screenHeight = MediaQuery.of(context).size.height;
    final double imageHeight  = screenHeight * 0.25;
    final double chartHeight  = screenHeight * 0.25;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 타이틀 + CSV
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${_selectedDay?.month}월 ${_selectedDay?.day}일 측정 결과",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.share, color: Colors.grey),
                tooltip: 'CSV 공유',
                onPressed: _exportCsv,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 자세 점수
          Container(
            width: double.infinity, padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFC8E6C9))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("자세 유지 점수", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text("${_selectedScore ?? 0}점", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF33691E))),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 경고/주의 횟수
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFFCEBEB), borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    const Text("경고 횟수", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text("${_warningCount}회", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFE24B4A))),
                  ]),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    const Text("주의 횟수", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text("${_cautionCount}회", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFF9800))),
                  ]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // 평균 CVA 목 각도 + 사람 사진
          const Text("평균 CVA 목 각도", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 150,
                height: imageHeight,
                child: Stack(
                  children: [
                    Image.asset(
                      'assets/neck_side.jpg',
                      fit: BoxFit.contain,
                      width: 150,
                      height: imageHeight,
                      errorBuilder: (_, __, ___) => CustomPaint(
                        painter: NeckAnglePainter(cvaAngle: _avgCva),
                        size: Size(150, imageHeight),
                      ),
                    ),
                    Positioned.fill(
                      child: CustomPaint(painter: NeckAngleLinePainter(cvaAngle: _avgCva)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("${_avgCva.toStringAsFixed(1)}°",
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFF1D9E75))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _avgCva >= 53 ? const Color(0xFFE8F5E9) : _avgCva >= 45 ? const Color(0xFFFFF3E0) : const Color(0xFFFCEBEB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _avgCva >= 53 ? "정상" : _avgCva >= 45 ? "주의" : "경고",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                          color: _avgCva >= 53 ? const Color(0xFF1D9E75) : _avgCva >= 45 ? const Color(0xFFFF9800) : const Color(0xFFE24B4A)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _avgCva >= 53 ? "바른 자세를 유지하고 있어요!" : _avgCva >= 45 ? "목 각도에 주의가 필요해요" : "거북목 위험 구간이에요",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // CVA 각도 변화 그래프
          const Text("CVA 각도 변화 그래프", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFF1D9E75), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4), const Text("정상", style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(width: 12),
              Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFFFF9800), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4), const Text("주의", style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(width: 12),
              Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFFE24B4A), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 4), const Text("경고", style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(width: 12),
              Container(width: 16, height: 2, color: const Color(0xFFE24B4A)),
              const SizedBox(width: 4), const Text("경고선", style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: chartHeight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: math.max(MediaQuery.of(context).size.width - 48, _cvaHistory.length * 20.0),
                child: CustomPaint(
                  painter: _ColoredChartPainter(angles: _cvaHistory, times: _timeHistory, postureHistory: _postureHistory),
                ),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildEmptyContent() {
    return Padding(padding: const EdgeInsets.only(top: 80), child: Center(child: Column(children: [const Icon(Icons.assignment_late_outlined, size: 64, color: Colors.grey), const SizedBox(height: 16), Text("${_selectedDay?.month}월 ${_selectedDay?.day}일\n기록이 없습니다.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16))])));
  }

  Widget _buildDayOfWeekHeader() {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 12.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: ['일', '월', '화', '수', '목', '금', '토'].map((d) => Text(d, style: const TextStyle(color: Colors.grey, fontSize: 13))).toList()));
  }

  Widget _buildMonthlyView() {
    return Column(
      children: [
        Padding(padding: const EdgeInsets.all(8.0), child: Row(children: [IconButton(icon: const Icon(Icons.arrow_back_ios, size: 18), onPressed: () => setState(() => _viewIndex = 0)), const Spacer()])),
        _buildDayOfWeekHeader(),
        Expanded(child: ListView.builder(controller: _scrollController, reverse: true, itemCount: 24, itemBuilder: (context, index) {
          final DateTime monthToShow = DateTime(DateTime.now().year, DateTime.now().month - index);
          return Container(padding: const EdgeInsets.only(bottom: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(left: 24, top: 24, bottom: 8), child: Text("${monthToShow.year}년 ${monthToShow.month}월", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            // ✅ 월간뷰 날짜 클릭 → TodayReportView
            TableCalendar(locale: 'ko_KR', firstDay: DateTime(monthToShow.year, monthToShow.month, 1), lastDay: DateTime(monthToShow.year, monthToShow.month + 1, 0), focusedDay: monthToShow, calendarFormat: CalendarFormat.month, headerVisible: false, daysOfWeekVisible: false, selectedDayPredicate: (day) => isSameDay(_selectedDay, day), onDaySelected: _onMonthlyDaySelected, calendarBuilders: _customBuilders()),
          ]));
        })),
      ],
    );
  }

  CalendarBuilders _customBuilders() {
    return CalendarBuilders(
      defaultBuilder: (context, day, focusedDay) => _dateBox(day, _hasRecord(day) ? TColor.lightGreen : Colors.transparent, Colors.black),
      selectedBuilder: (context, day, focusedDay) => _dateBox(day, TColor.buttonGreen, Colors.white, isBold: true),
      todayBuilder: (context, day, focusedDay) => _dateBox(day, _hasRecord(day) ? TColor.lightGreen : Colors.transparent, TColor.buttonGreen, isBold: true, isExtraBold: true),
    );
  }

  Widget _dateBox(DateTime day, Color bg, Color text, {bool isBold = false, bool isExtraBold = false}) {
    return Center(child: Container(width: 38, height: 38, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Center(child: Text('${day.day}', style: TextStyle(color: text, fontSize: 14, fontWeight: isExtraBold ? FontWeight.w900 : (isBold ? FontWeight.bold : FontWeight.normal))))));
  }
}

class _ColoredChartPainter extends CustomPainter {
  final List<double> angles;
  final List<String> times;
  final List<String> postureHistory;

  _ColoredChartPainter({required this.angles, required this.times, required this.postureHistory});

  Color _postureColor(String posture) {
    if (posture == 'warning') return const Color(0xFFE24B4A);
    if (posture == 'caution') return const Color(0xFFFF9800);
    return const Color(0xFF1D9E75);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (angles.isEmpty) return;
    const double padL = 36, padR = 16, padT = 8, padB = 28;
    final double chartW = size.width - padL - padR;
    final double chartH = size.height - padT - padB;
    const double warningLine = 50.0;
    final double minVal = (angles.reduce(math.min) - 5).clamp(0.0, 40.0);
    final double maxVal = (angles.reduce(math.max) + 5).clamp(60.0, 120.0);

    double toX(int i) => padL + i * chartW / math.max(angles.length - 1, 1);
    double toY(double v) => padT + (1 - (v - minVal) / (maxVal - minVal)) * chartH;

    for (double v in [minVal, (minVal + maxVal) / 2, maxVal]) {
      canvas.drawLine(Offset(padL, toY(v)), Offset(padL + chartW, toY(v)), Paint()..color = Colors.grey.withOpacity(0.1)..strokeWidth = 0.5);
      final tp = TextPainter(text: TextSpan(text: "${v.toInt()}°", style: const TextStyle(color: Colors.grey, fontSize: 9)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(0, toY(v) - 5));
    }

    double x = padL;
    while (x < padL + chartW) {
      canvas.drawLine(Offset(x, toY(warningLine)), Offset(math.min(x + 6, padL + chartW), toY(warningLine)), Paint()..color = const Color(0xFFE24B4A)..strokeWidth = 1.5);
      x += 10;
    }

    for (int i = 0; i < angles.length - 1; i++) {
      final posture = i < postureHistory.length ? postureHistory[i] : 'normal';
      canvas.drawLine(Offset(toX(i), toY(angles[i])), Offset(toX(i + 1), toY(angles[i + 1])),
          Paint()..color = _postureColor(posture)..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    }

    for (int i = 0; i < angles.length; i++) {
      final posture = i < postureHistory.length ? postureHistory[i] : 'normal';
      canvas.drawCircle(Offset(toX(i), toY(angles[i])), 4, Paint()..color = _postureColor(posture));
      canvas.drawCircle(Offset(toX(i), toY(angles[i])), 4, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
    }

    if (times.isNotEmpty) {
      final step = math.max((times.length / 5).ceil(), 1);
      for (int i = 0; i < times.length; i += step) {
        final tp = TextPainter(text: TextSpan(text: times[i], style: const TextStyle(color: Colors.grey, fontSize: 8)), textDirection: TextDirection.ltr)..layout();
        tp.paint(canvas, Offset(toX(i) - tp.width / 2, size.height - padB + 4));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class NeckAngleLinePainter extends CustomPainter {
  final double cvaAngle;
  NeckAngleLinePainter({required this.cvaAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.60;
    final double c7Y = size.height * 0.65;
    canvas.drawLine(Offset(cx, c7Y - 60), Offset(cx, c7Y + 20), Paint()..color = Colors.grey.withOpacity(0.5)..strokeWidth = 1.5);
    final angleRad = (90 - cvaAngle) * math.pi / 180;
    final endX = cx - math.cos(angleRad) * 80.0;
    final endY = c7Y - math.sin(angleRad) * 80.0;
    canvas.drawLine(Offset(cx, c7Y), Offset(endX, endY), Paint()..color = const Color(0xFF378ADD)..strokeWidth = 3..strokeCap = StrokeCap.round);
    canvas.drawArc(Rect.fromCenter(center: Offset(cx, c7Y), width: 50, height: 50), -math.pi / 2, -(90 - cvaAngle) * math.pi / 180, false, Paint()..color = const Color(0xFF378ADD).withOpacity(0.6)..strokeWidth = 1.5..style = PaintingStyle.stroke);
    canvas.drawCircle(Offset(cx, c7Y), 5, Paint()..color = const Color(0xFFE24B4A));
    final textPainter = TextPainter(text: TextSpan(text: "${cvaAngle.toStringAsFixed(1)}°", style: const TextStyle(color: Color(0xFF378ADD), fontSize: 14, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    textPainter.paint(canvas, Offset(cx - 60, c7Y - 50));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

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
    canvas.drawLine(Offset(cx, size.height * 0.1), Offset(cx, size.height * 0.9), Paint()..color = Colors.grey.withOpacity(0.25)..strokeWidth = 1);
    final angleRad = (90 - cvaAngle) * math.pi / 180;
    final endX = cx - math.cos(angleRad) * 60.0;
    final endY = c7Y - math.sin(angleRad) * 60.0;
    canvas.drawLine(Offset(cx, c7Y), Offset(endX, endY), Paint()..color = const Color(0xFF378ADD)..strokeWidth = 2..strokeCap = StrokeCap.round);
    canvas.drawArc(Rect.fromCenter(center: Offset(cx, c7Y), width: 40, height: 40), -math.pi / 2, -angleRad, false, Paint()..color = const Color(0xFF378ADD).withOpacity(0.6)..strokeWidth = 1.5..style = PaintingStyle.stroke);
    final textPainter = TextPainter(text: TextSpan(text: "${cvaAngle.toStringAsFixed(1)}°", style: const TextStyle(color: Color(0xFF378ADD), fontSize: 13, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
    textPainter.paint(canvas, Offset(cx + 14, c7Y - 28));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}