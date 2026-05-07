import 'package:flutter/material.dart';
import 'style.dart';

class MonthlyReportView extends StatefulWidget {
  const MonthlyReportView({super.key});

  @override
  State<MonthlyReportView> createState() => _MonthlyReportViewState();
}

class _MonthlyReportViewState extends State<MonthlyReportView> {
  final int appInstallYear = 2024;
  final DateTime _today = DateTime.now();

  late String selectedYear;
  late String selectedMonth;

  static bool isAlarmRegistered = false;

  @override
  void initState() {
    super.initState();
    selectedYear = "${_today.year}년";
    selectedMonth = "${_today.month}월";
  }

  int _checkStatus() {
    int selY = int.parse(selectedYear.replaceAll('년', ''));
    int selM = int.parse(selectedMonth.replaceAll('월', ''));
    if (selY > _today.year || (selY == _today.year && selM > _today.month)) return 0;
    if (selY == _today.year && selM == _today.month) return 1;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    int status = _checkStatus();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: TColor.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("월간 리포트", style: TText.title),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                _buildDropdown(selectedYear, _generateYearList(), (val) { if (val != null) setState(() => selectedYear = val); }),
                const SizedBox(width: 12),
                _buildDropdown(selectedMonth, _generateMonthList(), (val) { if (val != null) setState(() => selectedMonth = val); }),
              ],
            ),
          ),
          Expanded(child: _buildMainContent(status)),
        ],
      ),
    );
  }

  Widget _buildMainContent(int status) {
    if (isAlarmRegistered && status != 2) {
      return Center(child: Text(status == 0 ? "측정 기간이 되면 알려드릴게요!" : "리포트를 열심히 분석 중이에요!", style: TText.body.copyWith(color: TColor.gray), textAlign: TextAlign.center));
    }
    switch (status) {
      case 0: return _buildReadyView(title: "이번 달은 1일부터\n월간 거북목 측정을 할 수 있어요");
      case 1: return _buildReadyView(title: "$selectedMonth 월간 리포트\n준비 중 . . .");
      case 2: return _buildReportResultView();
      default: return const SizedBox();
    }
  }

  Widget _buildReadyView({required String title}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Text(title, textAlign: TextAlign.center, style: TText.title.copyWith(fontSize: 22, height: 1.5)),
          const Spacer(flex: 3),
          const Text("결과가 나오면 알려드릴까요?", style: TextStyle(color: TColor.black, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isAlarmRegistered ? null : () async {
              setState(() => isAlarmRegistered = true);
              await Future.delayed(const Duration(milliseconds: 1200));
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isAlarmRegistered ? const Color(0xFF143601) : TColor.buttonGreen, 
              minimumSize: const Size(double.infinity, 56), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), 
              elevation: 0
            ),
            child: Text(isAlarmRegistered ? "알림 설정 완료" : "알림 설정", style: TText.button),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildReportResultView() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        const Center(child: Text("측정 결과를 확인해 보세요!", style: TText.caption)),
        const SizedBox(height: 16),
        _buildResultCard(),
        const SizedBox(height: 32),
        const Text("거북목 각도(CVA) 및 목의 가동 범위(CRA)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildAnalysisImages(),
        const SizedBox(height: 32),
        
        _buildChartFrame("CVA / CRA 각도 변화 그래프"),
        
        const SizedBox(height: 32),
        const Row(children: [Text("종합 소견", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), SizedBox(width: 4), Icon(Icons.info_outline, size: 16, color: TColor.gray)]),
        const SizedBox(height: 16),
        
        _buildScoreBoxFrame(),
        const SizedBox(height: 16),

        // 💡 [최종 수정] 이모티콘 제거 & 텍스트-그래프 초밀착 구성
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white, 
            border: Border.all(color: Colors.grey.shade200), 
            borderRadius: BorderRadius.circular(16)
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("예상 질병 TOP 3", style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              
              _buildSimpleDiseaseItem("목디스크", 0.85),
              const SizedBox(height: 16),
              _buildSimpleDiseaseItem("후두신경통", 0.65),
              const SizedBox(height: 16),
              _buildSimpleDiseaseItem("척추측만증", 0.35),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        _buildPredictionBoxFrame(),
        const SizedBox(height: 50),
      ],
    );
  }

  // 💡 군더더기 없이 이름과 그래프만 있는 깔끔한 위젯
  Widget _buildSimpleDiseaseItem(String name, double percent) {
    return Row(
      children: [
        SizedBox(
          width: 75, // 텍스트 영역을 적절히 확보
          child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ),
        // 간격을 아주 좁게 설정
        const SizedBox(width: 2), 
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5), 
              borderRadius: BorderRadius.circular(6)
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percent,
              child: Container(
                decoration: BoxDecoration(
                  color: TColor.buttonGreen, 
                  borderRadius: BorderRadius.circular(6)
                )
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- 레이아웃 프레임들 (동일하게 유지) ---
  Widget _buildChartFrame(String title) {
    return Container(
      height: 240, padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const Expanded(child: Center(child: Text("차트 데이터 영역", style: TextStyle(color: TColor.gray)))),
      ]),
    );
  }

  Widget _buildScoreBoxFrame() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(16)),
      child: const Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("경추 건강 점수", style: TextStyle(fontWeight: FontWeight.w600)),
          Text("AI 분석 시스템", style: TextStyle(fontSize: 10, color: TColor.gray)),
        ]),
        SizedBox(height: 8),
        Text("73점", style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: TColor.darkGreen)),
      ]),
    );
  }

  Widget _buildPredictionBoxFrame() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("거북목 개선 예측", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 250), // 길어진 그래프 높이 반영
          Text("현재 추세 유지 시 3개월 뒤 개선 전망", style: TextStyle(fontSize: 13, color: TColor.gray)),
        ],
      ),
    );
  }

  Widget _buildResultCard() { return Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 32), decoration: BoxDecoration(border: Border.all(color: TColor.buttonGreen), borderRadius: BorderRadius.circular(20)), child: Column(children: [Text("@@님의 $selectedMonth 거북목 유형은...", style: TText.body.copyWith(fontWeight: FontWeight.bold)), const SizedBox(height: 16), const Text("역C자목", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: TColor.darkGreen))])); }
  Widget _buildAnalysisImages() { return Container(height: 180, width: double.infinity, decoration: BoxDecoration(color: TColor.lightGreen, borderRadius: BorderRadius.circular(16)), child: const Center(child: Text("이미지 영역"))); }
  List<String> _generateYearList() => List.generate((_today.year - appInstallYear) + 1, (index) => "${_today.year - index}년");
  List<String> _generateMonthList() => List.generate(12, (i) => "${i + 1}월");
  Widget _buildDropdown(String currentValue, List<String> items, ValueChanged<String?> onChanged) { return Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: TColor.lightGreen, borderRadius: BorderRadius.circular(12)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: items.contains(currentValue) ? currentValue : items.first, dropdownColor: TColor.lightGreen, items: items.map((String item) => DropdownMenuItem<String>(value: item, child: Text(item, style: const TextStyle(fontSize: 14, color: TColor.darkGreen, fontWeight: FontWeight.w500)))).toList(), onChanged: onChanged, icon: const Icon(Icons.arrow_drop_down, color: TColor.darkGreen)))); }
}