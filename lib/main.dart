import 'dart:async';
import 'package:flutter/material.dart';
import 'style.dart';    // TColor, TText 등이 정의된 파일
import 'exercise.dart'; 
import 'report.dart';
import 'mypage.dart';

void main() => runApp(const TurtlyApp());

class TurtlyApp extends StatelessWidget {
  const TurtlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Pretendard', 
        scaffoldBackgroundColor: TColor.white
      ),
      home: const TurtlyMainPage(),
    );
  }
}

class TurtlyMainPage extends StatefulWidget {
  const TurtlyMainPage({super.key});

  @override
  _TurtlyMainPageState createState() => _TurtlyMainPageState();
}

class _TurtlyMainPageState extends State<TurtlyMainPage> {
  int _selectedIndex = 0; // 하단 탭 선택 인덱스

  // 이동할 페이지 목록
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // 페이지 구성 (0: 홈, 2: 운동)
    _pages = [
      const HomeViewContent(),     // 아래에 정의된 홈 화면 클래스
      const ReportView(), 
      ExerciseView(),              // exercise.dart에서 가져온 클래스
      const MyPageView(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: TColor.white,
        elevation: 0,
        centerTitle: true,
        title: Text("Turtly", style: TText.logo),
        actions: [
          IconButton(
            onPressed: () {}, 
            icon: const Icon(Icons.notifications_none, color: TColor.black)
          )
        ],
      ),
      // 현재 선택된 인덱스에 맞는 페이지를 보여줌
      body: _pages[_selectedIndex], 
      
      bottomNavigationBar: Container(
        height: 80,
        decoration: const BoxDecoration(
          color: TColor.white, 
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE)))
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, "Home", 0),
            _buildNavItem(Icons.bar_chart_rounded, "Report", 1),
            _buildNavItem(Icons.fitness_center, "Exercise", 2),
            _buildNavItem(Icons.person_outline, "MyPage", 3),
          ],
        ),
      ),
    );
  }

  // 하단 탭 아이템 빌더
  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: Container(
        color: Colors.transparent, // 터치 영역 확보
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              color: isSelected ? TColor.buttonGreen : TColor.black.withOpacity(0.4), 
              size: 28
            ),
            Text(
              label, 
              style: TextStyle(
                color: isSelected ? TColor.buttonGreen : TColor.black.withOpacity(0.4), 
                fontSize: 12
              )
            ),
          ],
        ),
      ),
    );
  }
}

// --- 홈 화면의 실제 내용만 따로 분리한 위젯 ---
class HomeViewContent extends StatefulWidget {
  const HomeViewContent({super.key});

  @override
  _HomeViewContentState createState() => _HomeViewContentState();
}

class _HomeViewContentState extends State<HomeViewContent> {
  bool isMonitoring = false;
  bool isCalibrating = false;
  int calibrationTimer = 3;
  int monitoringSeconds = 0;
  String selectedDifficulty = '보통';
  Timer? _timer;

  String _getTodayDate() {
    var now = DateTime.now();
    return "${now.month}월 ${now.day}일";
  }

  String getTurtleImage() {
    return 'assets/normal_turtle.png'; 
  }

  void startCalibration() {
    setState(() { isCalibrating = true; calibrationTimer = 3; });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (calibrationTimer > 1) { setState(() => calibrationTimer--); } 
      else { timer.cancel(); startMonitoring(); }
    });
  }

  void startMonitoring() {
    setState(() { isCalibrating = false; isMonitoring = true; monitoringSeconds = 0; });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => monitoringSeconds++);
    });
  }

  void stopMonitoring() {
    // 1. 타이머가 살아있다면 확실히 죽이기
    if (_timer != null) {
      _timer!.cancel();
      _timer = null; // null로 비워줘야 다음에 다시 시작할 때 꼬이지 않아요.
    }
    
    // 2. 상태 업데이트
    setState(() { 
      isMonitoring = false; 
      // 만약 종료 시 시간을 0으로 초기화하고 싶지 않다면 아래 줄은 지우셔도 됩니다.
      monitoringSeconds = 0; 
    });
    
    print("모니터링 중지됨: $monitoringSeconds"); // 디버깅용
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_getTodayDate(), style: TText.title.copyWith(fontSize: 22, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VisionPage())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                  ),
                  child: Text("월간 거북목 측정하러 가기 >", style: TText.caption.copyWith(color: TColor.darkGreen, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${(monitoringSeconds ~/ 60).toString().padLeft(2, '0')}:${(monitoringSeconds % 60).toString().padLeft(2, '0')}",
                    style: TText.title.copyWith(fontSize: 32, fontWeight: FontWeight.bold)),
                  Row(
                    children: const [
                      Icon(Icons.battery_3_bar, color: TColor.gray, size: 20),
                      SizedBox(width: 4),
                      Text("85%", style: TText.caption),
                    ],
                  ),
                ],
              ),
              Row(
                children: ['낮음', '보통', '높음'].map((level) {
                  bool isSelected = selectedDifficulty == level;
                  return GestureDetector(
                    onTap: () => setState(() => selectedDifficulty = level),
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? TColor.buttonGreen : TColor.lightGreen,
                        borderRadius: BorderRadius.circular(15)
                      ),
                      child: Text(level, style: TextStyle(color: isSelected ? TColor.white : TColor.gray, fontSize: 13)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Expanded(
            child: Center(
              child: isCalibrating 
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(width: 200, height: 200, child: CircularProgressIndicator(value: 1 - (calibrationTimer / 3), color: TColor.buttonGreen, strokeWidth: 8)),
                      Text("$calibrationTimer", style: TText.logo.copyWith(fontSize: 48, color: TColor.black)),
                    ],
                  )
                : Image.asset(getTurtleImage(), width: 280, errorBuilder: (context, error, stackTrace) {
                    return const Text("이미지 파일 위치 확인 (assets/normal_turtle.png)");
                  }),
            ),
          ),
          Text("거북목을 교정을 하는 동안 터틀훅을 꼭 착용해 주세요", style: TText.caption),
          const SizedBox(height: 16),
          ElevatedButton(
            style: T_MainButtonStyle,
            onPressed: isMonitoring ? stopMonitoring : startCalibration,
            child: Text(isMonitoring ? "자세 교정 종료하기" : "자세 교정 시작하기", style: TText.button),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// 비전 페이지 (임시)
class VisionPage extends StatelessWidget {
  const VisionPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text("비전 측정")), body: const Center(child: Text("카메라 연동 화면")));
}