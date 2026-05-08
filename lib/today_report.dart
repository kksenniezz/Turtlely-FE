import 'package:flutter/material.dart';
import 'style.dart'; // TColor, TText 등이 정의된 파일

class TodayReportView extends StatelessWidget {
  // 💡 ReportView에서 'selectedDate'라는 이름으로 넘겨준다면 이름을 맞춰주는게 좋습니다.
  final DateTime date; 
  
  const TodayReportView({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0, // 스크롤 시 색상 변경 방지
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20), 
          onPressed: () => Navigator.pop(context)
        ),
        // 💡 제목에 날짜 반영
        title: Text("${date.year}년 ${date.month}월 ${date.day}일 리포트", 
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. 자세 점수 카드
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F8E9), // TColor.lightGreen
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
                  Text("72점", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: const Color(0xFF33691E))),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            // 2. 목 각도 분석
            const Text("평균 고개 각도 분석", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                height: 220,
                color: const Color(0xFFF5F5F5),
                child: Image.asset(
                  "assets/analysis_neck.png", 
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.analytics_outlined, color: Colors.grey, size: 40),
                        SizedBox(height: 8),
                        Text("목 각도 분석 데이터", style: TextStyle(color: Colors.grey)),
                      ],
                    )
                  )
                ),
              ),
            ),
            const SizedBox(height: 40),
            
            // 3. 타임라인 히트맵
            const Text("타임라인 히트맵", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: Image.asset(
                "assets/timeline_heatmap.png", 
                errorBuilder: (context, e, s) => const Center(
                  child: Text("시간대별 자세 변화 그래프", style: TextStyle(color: Colors.grey))
                )
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}