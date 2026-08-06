import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'style.dart';
import 'monthly_report.dart';
import 'daily_report_storage.dart';
import 'posture_api_service.dart';
import 'report_onboarding_dialog.dart'; // ★ 리포트 온보딩 다이얼로그 연동

class ReportView extends StatefulWidget {
  const ReportView({super.key});

  @override
  _ReportViewState createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  int _viewIndex = 0; // 0: 주간/리포트 메인 뷰, 1: 월간 달력 뷰
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();

  PageController? _calendarPageController;
  final ScrollController _scrollController = ScrollController();

  final List<DateTime> _recordedDays = [];
  List<dynamic> _calendarReports = [];

  int?    _selectedScore;
  double  _avgCva         = 0.0;
  int     _warningCount   = 0;
  int     _cautionCount   = 0;
  List<double> _cvaHistory     = [];
  List<String> _timeHistory    = [];
  List<String> _postureHistory = [];
  bool    _isLoadingReport = false;

  // CVA 그래프 제어용 변수
  int _selectedInterval = 1; // 기본 1분
  List<Map<String, dynamic>> _processedGraphData = [];
  Map<String, dynamic>? _selectedPoint;

  // ★ 사용자 개별 설정값 ★
  double _myBaseCva = 52.0;    // 월간 측정에서 나온 개인 기준 각도
  String _selectedLevel = 'normal'; // 난이도 ('easy', 'normal', 'hard')

  // 이탈 각도 기준 산출 함수
  Map<String, double> getThresholds(String level, double baseCva) {
    double cautionOffset;
    if (level == 'hard') {
      cautionOffset = 2.0;
    } else if (level == 'easy') {
      cautionOffset = 8.0;
    } else {
      cautionOffset = 5.0; // normal
    }

    return {
      'cautionY': baseCva - cautionOffset, // 주의 임계 각도
      'warningY': baseCva - 15.0,         // 경고 임계 각도 (공통 15도)
    };
  }

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

    // ★ 화면 렌더링 완료 후 리포트 최초 1회 온보딩 팝업 노출 ★
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ReportOnboardingDialog.checkAndShow(
        context,
        userName: "사용자", // 필요 시 유저 닉네임 파라미터 연결
        onComplete: () {
          debugPrint("리포트 온보딩 완료!");
        },
      );
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

    _processGraphData();

    if (mounted) setState(() { _isLoadingReport = false; });
  }

  void _processGraphData() {
    if (_cvaHistory.isEmpty) {
      setState(() {
        _processedGraphData = [];
        _selectedPoint = null;
      });
      return;
    }

    List<Map<String, dynamic>> temp = [];
    int step = _selectedInterval;

    for (int i = 0; i < _cvaHistory.length; i += step) {
      int end = math.min(i + step, _cvaHistory.length);
      List<double> chunkCva = _cvaHistory.sublist(i, end);
      List<String> chunkPosture = _postureHistory.sublist(i, end);

      if (chunkCva.isEmpty) continue;

      double sum = chunkCva.reduce((a, b) => a + b);
      double avg = sum / chunkCva.length;

      int wCount = chunkPosture.where((p) => p == "warning").length;
      int cCount = chunkPosture.where((p) => p == "caution").length;

      String timeStr = i < _timeHistory.length ? _timeHistory[i] : '';

      temp.add({
        'avgCva': avg,
        'warningCount': wCount,
        'cautionCount': cCount,
        'time': timeStr,
        'index': i,
      });
    }

    setState(() {
      _processedGraphData = temp;
      _selectedPoint = null;
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {
    // ★ 미래 날짜 선택 클릭 차단
    if (selectedDay.isAfter(DateTime.now())) return;

    setState(() {
      _selectedDay    = selectedDay;
      _focusedDay     = focusedDay.isAfter(DateTime.now()) ? DateTime.now() : focusedDay;
      _viewIndex      = 0;
      _selectedScore  = null;
      _avgCva         = 0.0;
      _cvaHistory     = [];
      _postureHistory = [];
      _timeHistory    = [];
      _warningCount   = 0;
      _cautionCount   = 0;
      _processedGraphData = [];
      _selectedPoint  = null;
    });

    if (_hasRecord(selectedDay)) {
      final id = _getDailyId(selectedDay);
      await _loadFullData(selectedDay, id);
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
            locale: 'ko_KR',
            firstDay: DateTime.utc(2024, 1, 1),
            // ★ lastDay를 오늘로 고정하여 미래 날짜 제한
            lastDay: DateTime.now(),
            focusedDay: _focusedDay.isAfter(DateTime.now()) ? DateTime.now() : _focusedDay,
            calendarFormat: CalendarFormat.week, headerVisible: false,
            onCalendarCreated: (controller) => _calendarPageController = controller,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: _onDaySelected,
            onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay.isAfter(DateTime.now()) ? DateTime.now() : focusedDay),
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

    final thresholds = getThresholds(_selectedLevel, _myBaseCva);
    final double cautionY = thresholds['cautionY']!;
    final double warningY = thresholds['warningY']!;

    bool isNormal  = _avgCva >= cautionY;
    bool isCaution = _avgCva < cautionY && _avgCva >= warningY;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        color: isNormal ? const Color(0xFFE8F5E9) : isCaution ? const Color(0xFFFFF3E0) : const Color(0xFFFCEBEB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isNormal ? "정상" : isCaution ? "주의" : "경고",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                          color: isNormal ? const Color(0xFF1D9E75) : isCaution ? const Color(0xFFFF9800) : const Color(0xFFE24B4A)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isNormal ? "바른 자세를 유지하고 있어요!" : isCaution ? "목 각도에 주의가 필요해요" : "거북목 위험 구간이에요",
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          const Text("CVA 각도 변화 그래프", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text("그래프 위 측정 지점을 눌러 나의 상태를 확인해 보세요", style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [1, 10, 30, 60].map((interval) {
              bool isSelected = _selectedInterval == interval;
              String label = interval == 60 ? "1시간" : "$interval분";
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedInterval = interval;
                    _processGraphData();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFF1F8E9) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFC8E6C9) : const Color(0xFFE0E0E0),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? const Color(0xFF33691E) : Colors.grey,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.grey, shape: BoxShape.circle)),
                    const SizedBox(width: 2),
                    const Text("정상(53°)", style: TextStyle(fontSize: 9, color: Colors.grey)),
                    const SizedBox(width: 6),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle)),
                    const SizedBox(width: 2),
                    Text("나의 기준(${_myBaseCva.toInt()}°)", style: const TextStyle(fontSize: 9, color: Colors.blueAccent)),
                    const SizedBox(width: 6),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF33691E), shape: BoxShape.circle)),
                    const SizedBox(width: 2),
                    const Text("나의 각도", style: TextStyle(fontSize: 9, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 8),

                SizedBox(
                  height: screenHeight * 0.25,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: math.max(
                        MediaQuery.of(context).size.width - 48 - 24,
                        _processedGraphData.length * 50.0,
                      ),
                      child: GestureDetector(
                        onTapDown: (TapDownDetails details) {
                          if (_processedGraphData.isEmpty) return;
                          double tapX = details.localPosition.dx;
                          double chartW = math.max(
                            MediaQuery.of(context).size.width - 48 - 24,
                            _processedGraphData.length * 50.0,
                          ) - 36 - 16;

                          double ratio = ((tapX - 36) / chartW).clamp(0.0, 1.0);
                          int clickedIdx = (ratio * (_processedGraphData.length - 1)).round();
                          setState(() {
                            _selectedPoint = _processedGraphData[clickedIdx];
                          });
                        },
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: CorrectedCvaChartPainter(
                            data: _processedGraphData,
                            selectedPoint: _selectedPoint,
                            myBaseCva: _myBaseCva,
                            selectedLevel: _selectedLevel,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_selectedPoint != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC8E6C9)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Text("시간: ${_selectedPoint!['time']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text("평균: ${(_selectedPoint!['avgCva'] as double).toStringAsFixed(1)}°", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF33691E))),
                  Text("경고: ${_selectedPoint!['warningCount']}회", style: const TextStyle(fontSize: 12, color: Color(0xFFE24B4A))),
                  Text("주의: ${_selectedPoint!['cautionCount']}회", style: const TextStyle(fontSize: 12, color: Color(0xFFFF9800))),
                ],
              ),
            ),
          ],

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
        Expanded(
          child: ListView.builder(
            controller: _scrollController, 
            reverse: true, 
            itemCount: 24, 
            itemBuilder: (context, index) {
              final DateTime monthToShow = DateTime(DateTime.now().year, DateTime.now().month - index);
              
              // 현재 달인 경우 오늘 날짜까지, 이전 달인 경우 해당 월의 마지막 날까지 계산
              final DateTime lastAllowedDay = (monthToShow.year == DateTime.now().year && monthToShow.month == DateTime.now().month)
                  ? DateTime.now()
                  : DateTime(monthToShow.year, monthToShow.month + 1, 0);

              return Container(
                padding: const EdgeInsets.only(bottom: 20), 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    Padding(padding: const EdgeInsets.only(left: 24, top: 24, bottom: 8), child: Text("${monthToShow.year}년 ${monthToShow.month}월", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                    TableCalendar(
                      locale: 'ko_KR', 
                      firstDay: DateTime(monthToShow.year, monthToShow.month, 1), 
                      // ★ 월간 뷰에서도 미래 날짜 제한 적용
                      lastDay: lastAllowedDay, 
                      focusedDay: monthToShow.isAfter(DateTime.now()) ? DateTime.now() : monthToShow, 
                      calendarFormat: CalendarFormat.month, 
                      headerVisible: false, 
                      daysOfWeekVisible: false, 
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day), 
                      onDaySelected: _onDaySelected, 
                      calendarBuilders: _customBuilders(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
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

// ------------------------------------------------------------------
// CVA 그래프 CustomPainter
// ------------------------------------------------------------------
class CorrectedCvaChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final Map<String, dynamic>? selectedPoint;
  final double myBaseCva;
  final String selectedLevel;

  CorrectedCvaChartPainter({
    required this.data, 
    this.selectedPoint,
    required this.myBaseCva,
    required this.selectedLevel,
  });

  Map<String, double> getThresholds(String level, double baseCva) {
    double cautionOffset;
    if (level == 'hard') {
      cautionOffset = 2.0;
    } else if (level == 'easy') {
      cautionOffset = 8.0;
    } else {
      cautionOffset = 5.0; // normal
    }

    return {
      'cautionY': baseCva - cautionOffset,
      'warningY': baseCva - 15.0,
    };
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const double padL = 36, padR = 16, padT = 12, padB = 32;
    final double chartW = size.width - padL - padR;
    final double chartH = size.height - padT - padB;

    const double minVal = 30.0;
    const double maxVal = 70.0;

    double toX(int i) => padL + (i * chartW / math.max(data.length - 1, 1));
    
    double toY(double v) {
      double clampedV = v.clamp(minVal, maxVal);
      return padT + (1 - (clampedV - minVal) / (maxVal - minVal)) * chartH;
    }

    final thresholds = getThresholds(selectedLevel, myBaseCva);
    final double cautionY = thresholds['cautionY']!;
    final double warningY = thresholds['warningY']!;

    final paintZone = Paint()..style = PaintingStyle.fill;
    
    canvas.drawRect(
      Rect.fromLTRB(padL, toY(maxVal), padL + chartW, toY(cautionY)),
      paintZone..color = const Color(0xFFC8E6C9).withOpacity(0.4),
    );
    canvas.drawRect(
      Rect.fromLTRB(padL, toY(cautionY), padL + chartW, toY(warningY)),
      paintZone..color = const Color(0xFFFFE0B2).withOpacity(0.5),
    );
    canvas.drawRect(
      Rect.fromLTRB(padL, toY(warningY), padL + chartW, toY(minVal)),
      paintZone..color = const Color(0xFFFFCDD2).withOpacity(0.5),
    );

    final gridPaint = Paint()..color = Colors.grey.withOpacity(0.2)..strokeWidth = 0.5;
    for (double v in [30.0, 40.0, 50.0, 60.0, 70.0]) {
      canvas.drawLine(Offset(padL, toY(v)), Offset(padL + chartW, toY(v)), gridPaint);
      final tp = TextPainter(
        text: TextSpan(text: "${v.toInt()}°", style: const TextStyle(color: Colors.grey, fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(4, toY(v) - 5));
    }

    final normalGuideLinePaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(padL, toY(53.0)), Offset(padL + chartW, toY(53.0)), normalGuideLinePaint);

    final myBaseGuideLinePaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    double dashW = 4, dashS = 3;
    double currentX = padL;
    double targetY = toY(myBaseCva);
    while (currentX < padL + chartW) {
      canvas.drawLine(
        Offset(currentX, targetY),
        Offset(math.min(currentX + dashW, padL + chartW), targetY),
        myBaseGuideLinePaint,
      );
      currentX += dashW + dashS;
    }

    final linePaint = Paint()
      ..color = const Color(0xFF33691E)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final verticalDashPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < data.length - 1; i++) {
      double x1 = toX(i);
      double y1 = toY((data[i]['avgCva'] as double));
      double x2 = toX(i + 1);
      double y2 = toY((data[i + 1]['avgCva'] as double));

      int idxDiff = data[i + 1]['index'] - data[i]['index'];
      if (idxDiff > 10) {
        double currY = padT;
        while (currY < padT + chartH) {
          canvas.drawLine(Offset(x2, currY), Offset(x2, math.min(currY + 4, padT + chartH)), verticalDashPaint);
          currY += 7;
        }
      } else {
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), linePaint);
      }
    }

    for (int i = 0; i < data.length; i++) {
      double x = toX(i);
      double rawCva = (data[i]['avgCva'] as double);
      double y = toY(rawCva);

      Color pointColor = const Color(0xFF33691E);
      if (rawCva < minVal) {
        pointColor = Colors.redAccent;
      } else if (rawCva > maxVal) {
        pointColor = Colors.orangeAccent;
      }

      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = pointColor);
      canvas.drawCircle(Offset(x, y), 3.5, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.0);

      String t = data[i]['time'] as String;
      if (t.isNotEmpty) {
        final tp = TextPainter(
          text: TextSpan(text: t, style: TextStyle(color: Colors.grey.shade600, fontSize: 8)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, size.height - padB + 6));
      }
    }

    if (selectedPoint != null) {
      int selIdx = data.indexOf(selectedPoint!);
      if (selIdx != -1) {
        double selX = toX(selIdx);
        double selY = toY((selectedPoint!['avgCva'] as double));

        canvas.drawLine(Offset(selX, padT), Offset(selX, padT + chartH), Paint()..color = const Color(0xFF33691E).withOpacity(0.4)..strokeWidth = 1);

        canvas.drawCircle(Offset(selX, selY), 6, Paint()..color = const Color(0xFF33691E));
        canvas.drawCircle(Offset(selX, selY), 6, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ------------------------------------------------------------------
// ★ CVA (C7 귓볼 완벽 대응 및 수평선 위쪽 호 교정) Painter ★
// ------------------------------------------------------------------
class NeckAngleLinePainter extends CustomPainter {
  final double cvaAngle;
  NeckAngleLinePainter({required this.cvaAngle});

  @override
  void paint(Canvas canvas, Size size) {
    // 이미상 C7 점 정확히 조준 (빨간 점 위치)
    final double cx = size.width * 0.62;
    final double c7Y = size.height * 0.62;

    // 1. C7 수평 기준선
    final horizontalLinePaint = Paint()
      ..color = Colors.grey.withOpacity(0.6)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(cx - 55, c7Y), Offset(cx + 20, c7Y), horizontalLinePaint);

    // 2. C7 -> 귓볼(위쪽/왼쪽) 방향 사선 계산 (Flutter Y축 반전 반영)
    final angleRad = cvaAngle * math.pi / 180;
    final endX = cx - math.cos(angleRad) * 60.0;
    final endY = c7Y - math.sin(angleRad) * 60.0; // Y축 차감으로 위쪽 이동!

    canvas.drawLine(
      Offset(cx, c7Y), 
      Offset(endX, endY), 
      Paint()..color = const Color(0xFF378ADD)..strokeWidth = 2.5..strokeCap = StrokeCap.round,
    );

    // 3. 수평선(180°)부터 귓볼 사선 사이(위쪽 공간)의 CVA 각도 호(Arc)
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, c7Y), width: 32, height: 32),
      math.pi,     // 수평선 좌측(180°)에서 시작
      angleRad,    // 위쪽 방향으로 cvaAngle만큼 채움
      false,
      Paint()..color = const Color(0xFF378ADD).withOpacity(0.8)..strokeWidth = 1.5..style = PaintingStyle.stroke,
    );

    // 4. C7 포인트 (빨간 점)
    canvas.drawCircle(Offset(cx, c7Y), 4, Paint()..color = const Color(0xFFE24B4A));

    // 5. CVA 수치 텍스트 표기
    final textPainter = TextPainter(
      text: TextSpan(
        text: "${cvaAngle.toStringAsFixed(1)}°", 
        style: const TextStyle(color: Color(0xFF378ADD), fontSize: 13, fontWeight: FontWeight.bold),
      ), 
      textDirection: TextDirection.ltr,
    )..layout();
    
    textPainter.paint(canvas, Offset(cx - 45, c7Y - 26));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class NeckAnglePainter extends CustomPainter {
  final double cvaAngle;
  NeckAnglePainter({required this.cvaAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width * 0.62;
    final double c7Y = size.height * 0.62;

    final bodyPaint   = Paint()..color = const Color(0xFFE8D5C4)..style = PaintingStyle.fill;
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

    canvas.drawCircle(Offset(cx, c7Y), 4, Paint()..color = const Color(0xFFE24B4A));

    // 수평선
    canvas.drawLine(Offset(cx - 50, c7Y), Offset(cx + 20, c7Y), Paint()..color = Colors.grey.withOpacity(0.4)..strokeWidth = 1);

    final angleRad = cvaAngle * math.pi / 180;
    final endX = cx - math.cos(angleRad) * 55.0;
    final endY = c7Y - math.sin(angleRad) * 55.0;

    canvas.drawLine(Offset(cx, c7Y), Offset(endX, endY), Paint()..color = const Color(0xFF378ADD)..strokeWidth = 2..strokeCap = StrokeCap.round);
    
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, c7Y), width: 32, height: 32), 
      math.pi, 
      angleRad, 
      false, 
      Paint()..color = const Color(0xFF378ADD).withOpacity(0.6)..strokeWidth = 1.2..style = PaintingStyle.stroke,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: "${cvaAngle.toStringAsFixed(1)}°", style: const TextStyle(color: Color(0xFF378ADD), fontSize: 12, fontWeight: FontWeight.bold)), 
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(cx - 40, c7Y - 22));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}