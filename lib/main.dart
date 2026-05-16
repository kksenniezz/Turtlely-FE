import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'style.dart'; // TColor, TText 등이 정의된 파일
import 'exercise.dart';
import 'report.dart';
import 'mypage.dart';
import 'vision.dart';
import 'splash.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  runApp(const TurtlelyApp());
}

class TurtlelyApp extends StatelessWidget {
  const TurtlelyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Pretendard',
        scaffoldBackgroundColor: TColor.white,
      ),
      home: const Splash(),
    );
  }
}

class TurtlelyMainPage extends StatefulWidget {
  const TurtlelyMainPage({super.key});

  @override
  _TurtlelyMainPageState createState() => _TurtlelyMainPageState();
}

class _TurtlelyMainPageState extends State<TurtlelyMainPage> {
  int _selectedIndex = 0;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomeViewContent(),
      const ReportView(),
      const ExerciseView(),
      const MyPageView(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 💡 리포트(1번 인덱스)일 때는 여기서 앱바를 그리지 않음 (중복 방지)
      appBar: _selectedIndex == 1
          ? null
          : AppBar(
              toolbarHeight: 80,
              backgroundColor: TColor.white,
              elevation: 0,
              centerTitle: true,
              title: Text("Turtlely", style: TText.logo),
              actions: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.notifications_none,
                    color: TColor.black,
                  ),
                ),
              ],
            ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        height: 80,
        decoration: const BoxDecoration(
          color: TColor.white,
          border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
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

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        color: Colors.transparent,
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? TColor.buttonGreen
                  : TColor.black.withOpacity(0.4),
              size: 28,
            ),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? TColor.buttonGreen
                    : TColor.black.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

  String _getTodayDate() => "${DateTime.now().month}월 ${DateTime.now().day}일";

  void startCalibration() {
    setState(() {
      isCalibrating = true;
      calibrationTimer = 3;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (calibrationTimer > 1)
        setState(() => calibrationTimer--);
      else {
        timer.cancel();
        startMonitoring();
      }
    });
  }

  void startMonitoring() {
    setState(() {
      isCalibrating = false;
      isMonitoring = true;
      monitoringSeconds = 0;
    });
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => setState(() => monitoringSeconds++),
    );
  }

  void stopMonitoring() {
    _timer?.cancel();
    setState(() {
      isMonitoring = false;
    });
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
              Text(
                _getTodayDate(),
                style: TText.title.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VisionPage()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      const BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    "월간 거북목 측정하러 가기 >",
                    style: TText.caption.copyWith(
                      color: TColor.darkGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                  Text(
                    "${(monitoringSeconds ~/ 60).toString().padLeft(2, '0')}:${(monitoringSeconds % 60).toString().padLeft(2, '0')}",
                    style: TText.title.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Row(
                    children: [
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? TColor.buttonGreen
                            : TColor.lightGreen,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        level,
                        style: TextStyle(
                          color: isSelected ? TColor.white : TColor.gray,
                          fontSize: 13,
                        ),
                      ),
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
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: CircularProgressIndicator(
                            value: 1 - (calibrationTimer / 3),
                            color: TColor.buttonGreen,
                            strokeWidth: 8,
                          ),
                        ),
                        Text(
                          "$calibrationTimer",
                          style: TText.logo.copyWith(fontSize: 48),
                        ),
                      ],
                    )
                  : Image.asset(
                      'assets/normal_turtle.png',
                      width: 280,
                      errorBuilder: (c, e, s) => const Text("이미지 없음"),
                    ),
            ),
          ),
          Text("거북목을 교정을 하는 동안 터틀훅을 꼭 착용해 주세요", style: TText.caption),
          const SizedBox(height: 16),
          ElevatedButton(
            style: T_MainButtonStyle,
            onPressed: isMonitoring ? stopMonitoring : startCalibration,
            child: Text(
              isMonitoring ? "자세 교정 종료하기" : "자세 교정 시작하기",
              style: TText.button,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
