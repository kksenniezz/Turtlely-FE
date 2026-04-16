import 'package:flutter/material.dart';
import 'style.dart';

class TodayReportView extends StatelessWidget {
  final DateTime date;
  const TodayReportView({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: Text("${date.month}월 ${date.day}일 리포트", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 자세 점수 카드
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: TColor.lightGreen, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("자세 유지 점수", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text("72점", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: TColor.buttonGreen)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // 목 각도 분석 이미지 (기획안의 3번째 슬라이드 느낌)
            const Text("평균 고개 각도 분석", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Image.asset("assets/analysis_neck.png", errorBuilder: (context, error, stackTrace) => Container(height: 200, color: Colors.grey, child: const Center(child: Text("분석 이미지 영역")))),
          ],
        ),
      ),
    );
  }
}