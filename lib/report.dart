import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'style.dart'; 
import 'monthly_report.dart'; 

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

  // 샘플 데이터
  final List<DateTime> _recordedDays = [
    DateTime.utc(2026, 5, 1), 
    DateTime.utc(2026, 5, 4), 
    DateTime.utc(2026, 5, 5), 
  ];

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _hasRecord(DateTime day) => _recordedDays.any((d) => isSameDay(d, day));

  // 💡 [추가] 다음 주로 넘어갈 수 있는지 체크 (미래 날짜 방지)
  bool _canGoNext() {
    // 현재 보고 있는 주(Week)에 오늘 날짜가 포함되어 있으면 더 이상 미래로 못 가게 설정
    DateTime now = DateTime.now();
    return _focusedDay.isBefore(DateTime(now.year, now.month, now.day));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: _viewIndex == 0 
        ? FloatingActionButton(
            elevation: 3,
            backgroundColor: TColor.lightGreen,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15), 
              side: const BorderSide(color: Color(0xFFC8E6C9))
            ),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MonthlyReportView())),
            child: const Icon(Icons.description, color: TColor.darkGreen),
          ) 
        : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: _viewIndex == 1 
        ? Column( // [화면 2] 세로 스크롤 달력
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back_ios, size: 18), onPressed: () => setState(() => _viewIndex = 0)),
                    const Spacer(), 
                    const SizedBox(width: 48), 
                  ],
                ),
              ),
              _buildDayOfWeekHeader(),
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  itemCount: 24, 
                  itemBuilder: (context, index) {
                    final DateTime monthToShow = DateTime(DateTime.now().year, DateTime.now().month - index);
                    return Container(
                      height: 400, 
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 24, top: 24, bottom: 8),
                            child: Text("${monthToShow.year}년 ${monthToShow.month}월", 
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          TableCalendar(
                            locale: 'ko_KR',
                            firstDay: DateTime(monthToShow.year, monthToShow.month, 1),
                            lastDay: DateTime(monthToShow.year, monthToShow.month + 1, 0),
                            focusedDay: monthToShow,
                            calendarFormat: CalendarFormat.month,
                            headerVisible: false,
                            daysOfWeekVisible: false,
                            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                                _viewIndex = 0; 
                              });
                            },
                            calendarBuilders: _customBuilders(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          )
        : SingleChildScrollView( // [화면 1] 메인 주간 리포트
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 16.0, right: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 💡 왼쪽 화살표 (과거로는 계속 갈 수 있음)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.arrow_left, size: 28),
                            onPressed: () => _calendarPageController?.previousPage(
                              duration: const Duration(milliseconds: 300), curve: Curves.easeOut
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "${_focusedDay.year}년 ${_focusedDay.month}월", 
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: TColor.darkGreen)
                          ),
                          const SizedBox(width: 8),
                          // 💡 오른쪽 화살표 (미래라면 회색 처리)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            // 상태에 따라 색상 변경 (활성: 검정, 비활성: 회색)
                            icon: Icon(
                              Icons.arrow_right, 
                              size: 28, 
                              color: _canGoNext() ? Colors.black : Colors.grey.shade400
                            ),
                            // 상태에 따라 기능 작동 여부 변경
                            onPressed: _canGoNext() 
                              ? () => _calendarPageController?.nextPage(
                                  duration: const Duration(milliseconds: 300), curve: Curves.easeOut
                                )
                              : null, // null을 주면 버튼이 자동으로 비활성화(회색 느낌) 됩니다.
                          ),
                        ],
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.calendar_month_outlined, size: 24),
                        onPressed: () => setState(() { _viewIndex = 1; _focusedDay = DateTime.now(); }),
                      ),
                    ],
                  ),
                ),
                TableCalendar(
                  locale: 'ko_KR',
                  firstDay: DateTime.utc(2024, 1, 1),
                  lastDay: DateTime.now(),
                  focusedDay: _focusedDay,
                  calendarFormat: CalendarFormat.week,
                  headerVisible: false, 
                  onCalendarCreated: (controller) => _calendarPageController = controller,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() { _selectedDay = selectedDay; _focusedDay = focusedDay; });
                  }, 
                  onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
                  calendarBuilders: _customBuilders(),
                ),
                const Divider(thickness: 1, color: Color(0xFFEEEEEE), height: 40),
                
                if (_hasRecord(_selectedDay!)) 
                   _buildActiveContent()
                else 
                  _buildEmptyContent(),
                const SizedBox(height: 100), 
              ],
            ),
          ),
      ),
    );
  }

  // --- UI 컴포넌트들 (기존과 동일) ---
  Widget _buildActiveContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          Center(child: Text("${_selectedDay?.month}월 ${_selectedDay?.day}일 측정 결과예요!", style: const TextStyle(color: Colors.grey, fontSize: 13))),
          const SizedBox(height: 20),
          _buildScoreBox(),
          const SizedBox(height: 40),
          const Text("평균 고개 각도", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(height: 220, width: double.infinity, decoration: BoxDecoration(color: TColor.lightGreen, borderRadius: BorderRadius.circular(15)), child: const Center(child: Text("이미지 영역"))),
          const SizedBox(height: 40),
          const Text("타임라인 히트맵", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), 
          const SizedBox(height: 16),
          Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(20)), child: const Center(child: Text("히트맵 영역"))),
        ],
      ),
    );
  }

  Widget _buildEmptyContent() {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Column(children: [
          const Icon(Icons.assignment_late_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text("${_selectedDay?.month}월 ${_selectedDay?.day}일\n기록이 없습니다.", textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ]),
      ),
    );
  }

  Widget _buildScoreBox() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(border: Border.all(color: TColor.buttonGreen), borderRadius: BorderRadius.circular(25)),
      child: Column(children: [
        const Text("오늘의 자세 유지 점수는...", style: TextStyle(fontSize: 15)),
        const SizedBox(height: 20),
        Text("72점", style: TextStyle(fontSize: 54, fontWeight: FontWeight.bold, color: TColor.darkGreen)),
        const SizedBox(height: 20),
        const Text("자세 유지 시간 / 측정 시간으로 계산했어요", style: TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
    );
  }

  Widget _buildDayOfWeekHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: ['일', '월', '화', '수', '목', '금', '토'].map((d) => Text(d, style: const TextStyle(color: Colors.grey, fontSize: 13))).toList(),
      ),
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
    return Center(
      child: Container(
        width: 38, height: 38, decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Center(child: Text('${day.day}', style: TextStyle(color: text, fontSize: 14, fontWeight: isExtraBold ? FontWeight.w900 : (isBold ? FontWeight.bold : FontWeight.normal)))),
      ),
    );
  }
}