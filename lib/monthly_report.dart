import 'package:flutter/material.dart';
import 'style.dart';
import 'vision.dart';
import 'services/report_service.dart';

class MonthlyReportView extends StatefulWidget {
  const MonthlyReportView({super.key});

  @override
  State<MonthlyReportView> createState() => _MonthlyReportViewState();
}

class _MonthlyReportViewState extends State<MonthlyReportView> {
  final DateTime _today = DateTime.now();

  late String selectedYear;
  late String selectedMonth;
  static bool isAlarmRegistered = false;

  final ReportService _reportService = ReportService();
  ReportData? _currentReport;

  bool _isLoading = false;
  String? _networkErrorMessage;

  int? _startYear;
  int? _startMonth;

  @override
  void initState() {
    super.initState();
    selectedYear = "${_today.year}년";
    selectedMonth = "${_today.month}월";
    _fetchReportData(isInitialFetch: true);
  }

  Future<void> _fetchReportData({bool isInitialFetch = false}) async {
    setState(() {
      _isLoading = true;
      _networkErrorMessage = null;
    });

    final int targetYear = int.parse(selectedYear.replaceAll('년', ''));
    final int targetMonth = int.parse(selectedMonth.replaceAll('월', ''));

    if (targetYear > _today.year ||
        (targetYear == _today.year && targetMonth > _today.month)) {
      setState(() {
        _currentReport = null;
        _isLoading = false;
      });
      return;
    }

    try {
      final data = await _reportService.fetchMonthlyReport(
        year: targetYear,
        month: targetMonth,
      );

      print(
        "🔍 [월간리포트 수신 데이터] 닉네임: ${data?.nickname}, 측정횟수: ${data?.totalMeasurements}, CVA: ${data?.cvaAngle}",
      );

      setState(() {
        _currentReport = data;

        if (isInitialFetch && data != null && data.year > 0) {
          _startYear = data.year;
          _startMonth = data.month;
        } else if (isInitialFetch) {
          _startYear = _today.year;
          _startMonth = 1;
        }
      });
    } catch (errorMessage) {
      if (errorMessage.toString() == "NOT_FOUND_TRIGGER") {
        setState(() {
          _currentReport = null;
        });
      } else {
        setState(() {
          _networkErrorMessage = errorMessage.toString();
        });
        _showServerAlternativeDialog(errorMessage.toString());
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showServerAlternativeDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "시스템 알림",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "확인",
              style: TextStyle(color: TColor.buttonGreen),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _generateYearList() {
    final int startYear = _startYear ?? _today.year;

    return List.generate(
      (_today.year - startYear) + 1,
      (index) => "${_today.year - index}년",
    );
  }

  List<String> _generateMonthList() {
    int selectedYInt = int.parse(selectedYear.replaceAll('년', ''));
    final int startYear = _startYear ?? _today.year;
    final int startMonth = _startMonth ?? 1;

    if (selectedYInt == startYear) {
      return List.generate(
        12 - startMonth + 1,
        (index) => "${startMonth + index}월",
      );
    }
    return List.generate(12, (i) => "${i + 1}월");
  }

  int _checkStatus() {
    int selY = int.parse(selectedYear.replaceAll('년', ''));
    int selM = int.parse(selectedMonth.replaceAll('월', ''));
    if (selY > _today.year || (selY == _today.year && selM > _today.month)) {
      return 0;
    }
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
                _buildDropdown(selectedYear, _generateYearList(), (val) {
                  if (val != null) {
                    setState(() {
                      selectedYear = val;
                      List<String> validMonths = _generateMonthList();
                      if (!validMonths.contains(selectedMonth)) {
                        selectedMonth = validMonths.first;
                      }
                    });
                    _fetchReportData();
                  }
                }),
                const SizedBox(width: 12),
                _buildDropdown(selectedMonth, _generateMonthList(), (val) {
                  if (val != null) {
                    setState(() => selectedMonth = val);
                    _fetchReportData();
                  }
                }),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: TColor.buttonGreen),
                  )
                : _buildMainContent(status),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(int status) {
    final report = _currentReport;

    if (_networkErrorMessage != null) {
      return Center(
        child: Text(
          "데이터를 불러오지 못했습니다.\n서버 상태나 인터넷 연결을 확인해 주세요.",
          style: TText.body.copyWith(color: TColor.gray),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (status == 1 && (report == null || report.totalMeasurements == 0)) {
      return _buildReadyView(
        title: "이번 달은 월간 거북목 측정을\n아직 하지 않았어요!",
        isMeasureActionMode: true,
      );
    }

    if (status == 2 && report == null) {
      return _buildReadyView(
        title: "${selectedMonth} 월간 거북목 측정 기록이 없습니다",
        hideActionButtons: true,
      );
    }

    if (isAlarmRegistered && status != 2) {
      return Center(
        child: Text(
          status == 0 ? "측정 기간이 되면 알려드릴게요!" : "리포트를 열심히 분석 중이에요!",
          style: TText.body.copyWith(color: TColor.gray),
          textAlign: TextAlign.center,
        ),
      );
    }

    switch (status) {
      case 0:
        return _buildReadyView(title: "이번 달은 측정일이 되면\n월간 거북목 측정을 할 수 있어요");
      case 1:
      case 2:
        return _buildReportResultView();
      default:
        return const SizedBox();
    }
  }

  Widget _buildReadyView({
    required String title,
    bool isMeasureActionMode = false,
    bool hideActionButtons = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TText.title.copyWith(fontSize: 22, height: 1.5),
          ),
          const Spacer(flex: 3),
          if (!hideActionButtons) ...[
            if (!isMeasureActionMode) ...[
              const Text(
                "결과가 나오면 알려드릴까요?",
                style: TextStyle(
                  color: TColor.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton(
              onPressed: isAlarmRegistered && !isMeasureActionMode
                  ? null
                  : () async {
                      if (isMeasureActionMode) {
                        final bool? isMeasured = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const VisionPage(),
                          ),
                        );
                        if (isMeasured == true) {
                          _fetchReportData();
                        }
                      } else {
                        setState(() => isAlarmRegistered = true);
                        await Future.delayed(
                          const Duration(milliseconds: 1200),
                        );
                        if (mounted) Navigator.pop(context);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isAlarmRegistered && !isMeasureActionMode
                    ? const Color(0xFF143601)
                    : TColor.buttonGreen,
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                isMeasureActionMode
                    ? "월간 거북목 측정하러 가기"
                    : (isAlarmRegistered ? "알림 설정 완료" : "알림 설정"),
                style: TText.button,
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildReportResultView() {
    final report = _currentReport;
    final String userNickname = report?.nickname ?? "사용자";
    final String postureType = report?.postureStatus ?? "역C자목";

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
        _buildChartFrame("CVA / CRA 각도 변화 그래프"),
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

  Widget _buildResultCard(String nickname, String type) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        border: Border.all(color: TColor.buttonGreen),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            "$nickname님의 $selectedMonth 거북목 유형은...", // 추후 '님' 추가
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
        ],
      ),
    );
  }

  Widget _buildAnalysisImages(String postureType) {
    final report = _currentReport;
    double myCVA = report?.cvaAngle ?? 69.0;
    double myCRA = report?.craAngle ?? 128.5;

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
            Expanded(child: _buildImageFrame("정상 기준", "normal_cva.png")),
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
            Expanded(child: _buildImageFrame("정상 기준", "normal_cra.png")),
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
        return "turtle_cva.png";
      case "일자목":
        return "military_cva.png";
      case "역C자목":
        return "reverse_cva.png";
      default:
        return "normal_cva.png";
    }
  }

  String _getCraImagePath(String type) {
    switch (type) {
      case "거북목":
        return "turtle_cra.png";
      case "일자목":
        return "military_cra.png";
      case "역C자목":
        return "reverse_cra.png";
      default:
        return "normal_cra.png";
    }
  }

  Widget _buildSimpleDiseaseItem(String name, double percent) {
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
              widthFactor: percent,
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

  Widget _buildChartFrame(String title) {
    return Container(
      height: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const Expanded(
            child: Center(
              child: Text("차트 데이터 영역", style: TextStyle(color: TColor.gray)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBoxFrame() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
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
            "73점",
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

  Widget _buildPredictionBoxFrame() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "거북목 개선 예측",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 250),
          Text(
            "현재 추세 유지 시 3개월 뒤 개선 전망",
            style: TextStyle(fontSize: 13, color: TColor.gray),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(
    String currentValue,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: TColor.lightGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(currentValue) ? currentValue : items.first,
          dropdownColor: TColor.lightGreen,
          items: items
              .map(
                (String item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 14,
                      color: TColor.darkGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          icon: const Icon(Icons.arrow_drop_down, color: TColor.darkGreen),
        ),
      ),
    );
  }
}
