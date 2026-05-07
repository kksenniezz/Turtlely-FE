import 'package:flutter/material.dart';
import 'style.dart'; // TColor.lightGreen, TColor.buttonGreen 등이 정의되어 있어야 함

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black), 
          onPressed: () => Navigator.pop(context)
        ),
        title: Text("${date.year}년 ${date.month}월 ${date.day}일 리포트", 
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 자세 점수 카드
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9), // TColor.lightGreen 대신 직접 색상 지정
                borderRadius: BorderRadius.circular(20)
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("자세 유지 점수", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text("72점", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF33691E))),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            // 목 각도 분석
            const Text("평균 고개 각도 분석", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset("assets/analysis_neck.png", 
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 220, 
                  width: double.infinity, 
                  color: Colors.grey[200], 
                  child: const Center(child: Text("분석 이미지 영역"))
                )
              ),
            ),
            const SizedBox(height: 40),
            
            // 타임라인 히트맵 상세
            const Text("타임라인 히트맵", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(20)
              ),
              child: Image.asset("assets/timeline_heatmap.png", 
                errorBuilder: (context, e, s) => const Center(child: Text("히트맵 이미지 영역"))
              ),
            ),
          ],
        ),
      ),
    );
  }
}