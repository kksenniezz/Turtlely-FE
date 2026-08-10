import 'package:flutter/material.dart';
import 'style.dart';
import 'vision.dart';
import 'services/report_service.dart';
import 'posture_api_service.dart';

class MonthlyAlarmView extends StatefulWidget {
  final ReportData? report;
  final DateTime? lastMeasuredAt;
  final String selectedMonth;
  final bool isMeasureAlarmSet;
  final bool isResultAlarmSet;
  final String? networkErrorMessage;
  final Function() onReportDataChanged;
  final Widget Function() buildReportResultView;

  const MonthlyAlarmView({
    super.key,
    required this.report,
    this.lastMeasuredAt,
    required this.selectedMonth,
    required this.isMeasureAlarmSet,
    required this.isResultAlarmSet,
    required this.networkErrorMessage,
    required this.onReportDataChanged,
    required this.buildReportResultView,
  });

  @override
  State<MonthlyAlarmView> createState() => _MonthlyAlarmViewState();
}

class _MonthlyAlarmViewState extends State<MonthlyAlarmView> {
  final ApiService _apiService = ApiService();
  bool _isMeasureAlarmSet = false;
  bool _isResultAlarmSet = false;
  bool _isUpdatingAlarm = false;

  @override
  void initState() {
    super.initState();
    _isMeasureAlarmSet = widget.isMeasureAlarmSet;
    _isResultAlarmSet = widget.isResultAlarmSet;
  }

  @override
  void didUpdateWidget(covariant MonthlyAlarmView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMeasureAlarmSet != oldWidget.isMeasureAlarmSet ||
        widget.isResultAlarmSet != oldWidget.isResultAlarmSet) {
      setState(() {
        _isMeasureAlarmSet = widget.isMeasureAlarmSet;
        _isResultAlarmSet = widget.isResultAlarmSet;
      });
    }
  }

  Future<void> _handleAlarmToggle(String alarmType) async {
    if (_isUpdatingAlarm) return;

    setState(() => _isUpdatingAlarm = true);

    final response = await _apiService.setMonthlyAlarm(alarmType);

    if (!mounted) return;

    if (response != null && response['isSuccess'] == true) {
      setState(() {
        if (alarmType == "MEASURE") {
          _isMeasureAlarmSet = !_isMeasureAlarmSet;
        } else {
          _isResultAlarmSet = !_isResultAlarmSet;
        }
      });

      // 부모 상태 최신화
      widget.onReportDataChanged();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("알림 설정 변경에 실패했습니다")));
    }

    setState(() => _isUpdatingAlarm = false);
  }

  @override
  Widget build(BuildContext context) {
    // 0. 네트워크 에러 발생 시
    if (widget.networkErrorMessage != null) {
      return Center(
        child: Text(
          "데이터를 불러오지 못했습니다\n서버 상태나 인터넷 연결을 확인해 주세요",
          style: TText.body.copyWith(color: TColor.gray),
          textAlign: TextAlign.center,
        ),
      );
    }

    // 1. 현재 드롭다운에서 선택된 달(숫자)과 오늘 날짜(월)
    DateTime now = DateTime.now();
    int selectedMonthNum =
        int.tryParse(widget.selectedMonth.replaceAll('월', '').trim()) ??
        now.month;

    // 2. 불러온 리포트가 '현재 선택한 달'의 리포트인지 검증
    bool isReportForSelectedMonth = false;
    if (widget.report != null && widget.report!.measuredAt != null) {
      isReportForSelectedMonth =
          (widget.report!.measuredAt!.month == selectedMonthNum &&
          widget.report!.measuredAt!.year == now.year);
    }

    // 3. 선택한 달의 리포트가 존재하고 AVAILABLE 상태인 경우 -> 결과 뷰
    if (isReportForSelectedMonth && widget.report?.dataStatus == "AVAILABLE") {
      return widget.buildReportResultView();
    }

    // 4. 선택한 달이 '이번 달'인 경우의 처리
    bool isCurrentMonth = (selectedMonthNum == now.month);

    if (isCurrentMonth) {
      DateTime? lastMeasuredAt =
          widget.lastMeasuredAt ?? widget.report?.measuredAt;

      print("👉 selectedMonth: ${widget.selectedMonth}");
      print("👉 widget.report: ${widget.report?.measuredAt}");
      print("👉 widget.lastMeasuredAt: ${widget.lastMeasuredAt}");
      print("👉 최종 lastMeasuredAt: $lastMeasuredAt");

      // 4-1. 아예 측정한 적이 없는 신규 유저
      if (lastMeasuredAt == null) {
        return _buildReadyView(
          title: "이번 달은 월간 측정을\n아직 하지 않았어요!",
          isMeasureActionMode: true,
        );
      }

      DateTime today = DateTime(now.year, now.month, now.day);
      DateTime lastDate = DateTime(
        lastMeasuredAt.year,
        lastMeasuredAt.month,
        lastMeasuredAt.day,
      );
      DateTime nextAvailableDate = lastDate.add(const Duration(days: 30));

      // 4-2. 마지막 측정일로부터 30일이 지난 경우 -> 측정 유도 안내
      bool canMeasureToday =
          today.isAfter(nextAvailableDate) ||
          today.isAtSameMomentAs(nextAvailableDate);

      if (canMeasureToday) {
        return _buildReadyView(
          title: "이번 달은 월간 측정을\n아직 하지 않았어요!",
          isMeasureActionMode: true,
        );
      } else {
        // 아직 30일이 안 지난 경우 -> N일 알림 안내
        String nDay = "${nextAvailableDate.day}일";

        return _buildReadyView(
          title: "이번 달은 $nDay부터\n월간 측정을 할 수 있어요",
          guideText: "$nDay에 알림을 보내드릴까요?",
          alarmType: "MEASURE",
        );
      }
    }

    // 5. 예외 상황 -> 리포트 준비 중/알림 안내
    return _buildReadyView(
      title: "${widget.selectedMonth} 월간 리포트를\n준비 중이에요",
      guideText: "결과가 나오면 알려드릴까요?",
      alarmType: "RESULT",
    );
  }

  Widget _buildReadyView({
    required String title,
    String? guideText,
    bool isMeasureActionMode = false,
    String? alarmType,
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
          if (guideText != null) ...[
            Text(
              guideText,
              style: TextStyle(
                color: TColor.black,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (isMeasureActionMode)
            // 1. 측정 유도 버튼
            _buildActionButton(
              text: "월간 측정하러 가기",
              onPressed: () async {
                final bool? isMeasured = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VisionPage()),
                );
                if (isMeasured == true) widget.onReportDataChanged();
              },
            )
          else if (alarmType != null)
            // 2. 알림 설정 버튼 (MEASURE 또는 RESULT)
            _buildAlarmButton(alarmType: alarmType),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // 공통 버튼 스타일 빌더
  Widget _buildActionButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: TColor.buttonGreen,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: Text(text, style: TText.button),
    );
  }

  // 알림 전용 버튼
  Widget _buildAlarmButton({required String alarmType}) {
    bool isSet = (alarmType == "MEASURE")
        ? _isMeasureAlarmSet
        : _isResultAlarmSet;

    return ElevatedButton(
      onPressed: _isUpdatingAlarm ? null : () => _handleAlarmToggle(alarmType),
      style: ElevatedButton.styleFrom(
        backgroundColor: TColor.darkGreen,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: Text(isSet ? "알림 설정 완료" : "알림 설정", style: TText.button),
    );
  }
}
