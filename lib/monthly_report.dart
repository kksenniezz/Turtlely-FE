import 'package:flutter/material.dart';
import 'style.dart';
import 'services/report_service.dart';
import 'monthly_alarm.dart';
import 'monthly_chart.dart';

class MonthlyReportView extends StatefulWidget {
  const MonthlyReportView({super.key});

  @override
  State<MonthlyReportView> createState() => _MonthlyReportViewState();
}

class _MonthlyReportViewState extends State<MonthlyReportView> {
  final DateTime _today = DateTime.now();

  final ReportService _reportService = ReportService();
  List<MonthlyListItem> _monthlyList = [];
  MonthlyListItem? _selectedItem;

  late int _selectedYear;
  late int _selectedMonth;
  ReportData? _currentReport;

  bool _isLoading = false;
  String? _networkErrorMessage;

  static bool isAlarmRegistered = false;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  Future<void> _initLoad() async {
    setState(() => _isLoading = true);

    try {
      // 1. 월 목록 가져오기
      final list = await _reportService.fetchMonthlyList();

      if (list.isEmpty) {
        setState(() {
          _monthlyList = [];
          _isLoading = false;
        });
        return;
      }

      // 2. 최신 월 자동 선택 (measuredAt 기준)
      list.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));

      setState(() {
        _monthlyList = list;
        _selectedItem = list.first;

        _selectedYear = list.first.year;
        _selectedMonth = list.first.month;
      });

      // 3. 첫 report 호출
      await _fetchReport(list.first.monthlyId);
    } catch (e) {
      setState(() {
        _networkErrorMessage = e.toString();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchReport(int monthlyId) async {
    setState(() => _isLoading = true);
    try {
      final data = await _reportService.fetchMonthlyReport(
        monthlyId: monthlyId,
      );

      setState(() {
        _currentReport = data;
      });
    } catch (e) {
      setState(() {
        _networkErrorMessage = e.toString();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSelectMonthly(MonthlyListItem item) {
    setState(() {
      _selectedItem = item;
      _selectedYear = item.year;
      _selectedMonth = item.month;
    });
    _fetchReport(item.monthlyId);
  }

  int _checkStatus() {
    final item = _selectedItem;
    if (item == null) return 0;

    if (item.year > _today.year ||
        (item.year == _today.year && item.month > _today.month)) {
      return 0;
    }

    if (item.year == _today.year && item.month == _today.month) {
      return 1;
    }

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
            child: _buildDropdown(),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : MonthlyAlarmView(
                    report: _currentReport,
                    status: status,
                    selectedMonth: _selectedItem != null
                        ? "${_selectedItem!.month}월"
                        : "",
                    isAlarmRegistered: isAlarmRegistered,
                    networkErrorMessage: _networkErrorMessage,
                    onReportDataChanged: () =>
                        _fetchReport(_selectedItem?.monthlyId ?? 0),
                    buildReportResultView: _buildReportResultView,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    if (_monthlyList.isEmpty || _selectedItem == null) {
      return const Text("데이터 없음"); // 추후 알림뷰로
    }

    final years = _monthlyList.map((e) => e.year).toSet().toList()
      ..sort((a, b) => b.compareTo(a));
    final months = _monthlyList.where((e) => e.year == _selectedYear).toList()
      ..sort((a, b) => b.month.compareTo(a.month));

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: TColor.lightGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _selectedYear,
              dropdownColor: TColor.lightGreen,
              icon: const Icon(Icons.arrow_drop_down, color: TColor.darkGreen),
              items: years.map((year) {
                return DropdownMenuItem<int>(
                  value: year,
                  child: Text(
                    "$year년",
                    style: const TextStyle(
                      fontSize: 14,
                      color: TColor.darkGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (year) {
                if (year == null) return;

                final firstMonth =
                    _monthlyList.where((e) => e.year == year).toList()
                      ..sort((a, b) => b.month.compareTo(a.month));

                _onSelectMonthly(firstMonth.first);
              },
            ),
          ),
        ),

        const SizedBox(width: 12),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: TColor.lightGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<MonthlyListItem>(
              value: _selectedItem,
              dropdownColor: TColor.lightGreen,
              icon: const Icon(Icons.arrow_drop_down, color: TColor.darkGreen),
              items: months.map((item) {
                return DropdownMenuItem<MonthlyListItem>(
                  value: item,
                  child: Text(
                    "${item.month}월",
                    style: const TextStyle(
                      fontSize: 14,
                      color: TColor.darkGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (item) {
                if (item != null) {
                  _onSelectMonthly(item);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultCard(String nickname, String type) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        border: Border.all(color: TColor.buttonGreen),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            "$nickname님의 $_selectedMonth월 추정 거북목 유형은...",
            style: TText.body.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            type,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: TColor.darkGreen,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "본 서비스는 카메라 측정 기반의 '자세 참고용' 결과이며,\n의학적 진단을 대신할 수 없습니다\n정확한 진단이 필요한 경우 전문가에게 문의하세요",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: TColor.gray,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisImages(String postureType) {
    final report = _currentReport;
    if (report == null) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text("분석 데이터가 없습니다."),
      );
    }

    final double myCVA = report.cvaAngle;
    final double myCRA = report.craAngle;

    double cvaDiff = myCVA - 55.0;
    String cvaDesc = cvaDiff > 0
        ? "이상적인 범위(50~55°)보다 약 ${cvaDiff.toStringAsFixed(1)}° 높게 측정되었습니다."
        : "이상적인 범위(50~55°)보다 약 ${cvaDiff.abs().toStringAsFixed(1)}° 낮게 측정되었습니다.";
    if (myCVA >= 50.0 && myCVA <= 55.0) {
      cvaDesc = "이상적인 범위(50~55°) 내에 안정적으로 속해 있습니다.";
    }

    String craDesc = myCRA <= 145.0
        ? "이상적인 범위(145° 이하) 내에 속해 목의 가동성이 안정적입니다."
        : "이상적인 범위(145° 이하)를 약 ${(myCRA - 145.0).toStringAsFixed(1)}° 벗어났습니다.";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "• 거북목 각도 (CVA) 비교",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildImageFrame(
                "내 상태 (CVA)",
                _getCvaImagePath(postureType),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _buildImageFrame("정상 기준", "assets/normal_cva.png")),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "내 CVA는 ${myCVA}° 이며, $cvaDesc",
          style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
        ),
        const SizedBox(height: 28),
        const Text(
          "• 목 가동 범위 (CRA) 비교",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildImageFrame(
                "내 상태 (CRA)",
                _getCraImagePath(postureType),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _buildImageFrame("정상 기준", "assets/normal_cra.png")),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "내 CRA는 ${myCRA}° 이며, $craDesc",
          style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildImageFrame(String title, String imagePath) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(Icons.image, color: Colors.grey)),
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getCvaImagePath(String type) {
    switch (type) {
      case "거북목":
        return "assets/turtle_cva.png";
      case "일자목":
        return "assets/military_cva.png";
      case "역C자목":
        return "assets/reverse_cva.png";
      default:
        return "assets/normal_cva.png";
    }
  }

  String _getCraImagePath(String type) {
    switch (type) {
      case "거북목":
        return "assets/turtle_cra.png";
      case "일자목":
        return "assets/military_cra.png";
      case "역C자목":
        return "assets/reverse_cra.png";
      default:
        return "assets/normal_cra.png";
    }
  }

  Widget _buildScoreBoxFrame() {
    final score = _currentReport?.score ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("경추 건강 점수", style: TextStyle(fontWeight: FontWeight.w600)),
              Text(
                "AI 분석 시스템",
                style: TextStyle(fontSize: 10, color: TColor.gray),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            "$score점",
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: TColor.darkGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportResultView() {
    final report = _currentReport;
    final String userNickname = report?.nickname ?? "사용자";
    final String postureType = report?.postureStatus ?? "역C자목";

    // 1. 차트 데이터 가공 (서버 응답을 차트가 원하는 List<double>로 변환)
    final List<double> cvaHistory =
        report?.cvaHistory
            ?.map((e) => (e['angle'] as num).toDouble())
            .toList() ??
        [];
    final List<double> craHistory =
        report?.craHistory
            ?.map((e) => (e['angle'] as num).toDouble())
            .toList() ??
        [];

    // 2. 예측 데이터 가공
    final List<double> predScores =
        (report?.predictionData?['prediction_scores'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];
    final List<String> predMonths =
        report?.predictionData?['prediction_months']?.cast<String>() ?? [];
    final diseases = report?.predictedDiseases ?? [];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TText.caption.copyWith(
              fontFamily: 'Pretendard',
              color: Colors.black,
            ),
            children: [
              TextSpan(text: "$userNickname님의 "), // 추후 '님' 추가
              TextSpan(
                text: "월간 거북목 측정",
                style: const TextStyle(
                  color: TColor.darkGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const TextSpan(text: " 결과를 확인해 보세요!"),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildResultCard(userNickname, postureType),
        const SizedBox(height: 32),
        const Text(
          "거북목 각도(CVA) 및 목의 가동 범위(CRA)",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildAnalysisImages(postureType),
        const SizedBox(height: 32),
        MonthlyChartWidget(cvaData: cvaHistory, craData: craHistory),
        const SizedBox(height: 32),
        const Row(
          children: [
            Text(
              "종합 소견",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 4),
            Icon(Icons.info_outline, size: 16, color: TColor.gray),
          ],
        ),
        const SizedBox(height: 16),
        _buildScoreBoxFrame(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "예상 질병 TOP 3",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              ...List.generate(diseases.length, (index) {
                final disease = diseases[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildSimpleDiseaseItem(
                    disease["name"] as String,
                    (disease["score"] as num).toDouble(),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 32),
        PredictionChartWidget(
          predictionData: predScores,
          predictionMonths: predMonths,
        ),
        const SizedBox(height: 50),
      ],
    );
  }

  Widget _buildSimpleDiseaseItem(String name, double percent) {
    final progress = percent.clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 75,
          child: Text(
            name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  color: TColor.buttonGreen,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
