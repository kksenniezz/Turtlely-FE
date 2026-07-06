import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hive_flutter/hive_flutter.dart'; // 추가!

import 'style.dart';
import 'exercise.dart';
import 'report.dart';
import 'mypage.dart';
import 'vision.dart';
import 'splash.dart';
import 'home.dart';
import 'ble_service.dart';
import 'posture_api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);
  await Hive.initFlutter(); // 추가!
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
  State<TurtlelyMainPage> createState() => _TurtlelyMainPageState();
}

class _TurtlelyMainPageState extends State<TurtlelyMainPage> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = const [
      HomeViewContent(),
      ReportView(),
      ExerciseView(),
      MyPageView(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 1
          ? null
          : AppBar(
              toolbarHeight: 80,
              backgroundColor: TColor.white,
              elevation: 0,
              centerTitle: true,
              automaticallyImplyLeading: false,
              title: Text("Turtlely", style: TText.logo),
              actions: [
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none, color: TColor.black),
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
    final bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? TColor.buttonGreen : TColor.black.withOpacity(0.4),
              size: 28,
            ),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? TColor.buttonGreen : TColor.black.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}