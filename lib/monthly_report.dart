import 'package:flutter/material.dart';
import 'style.dart';

class MonthlyReportView extends StatelessWidget {
  const MonthlyReportView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text("월간 리포트", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // 결과 배너
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFFF0F4F0), borderRadius: BorderRadius.circular(16)),
            child: const Text("측정 결과, 현재 '역C자목' 상태입니다.", style: TextStyle(fontWeight: FontWeight.bold, color: TColor.buttonGreen)),
          ),
          const SizedBox(height: 32),
          const Text("CVA / CRA 각도 변화 그래프", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          // 그래프 영역
          Container(
            height: 220,
            decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey!)),
            child: const Center(child: Text("그래프 라이브러리(fl_chart) 적용 구간")),
          ),
          const SizedBox(height: 32),
          const Text("거북목 개선 예측", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text("현재 추세라면 3개월 뒤 각도가 5도 개선될 것으로 보여요!", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}