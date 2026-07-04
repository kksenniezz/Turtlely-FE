import 'package:flutter/material.dart';
import 'style.dart';
import 'vision.dart';
import 'services/report_service.dart';

class MonthlyAlarmView extends StatefulWidget {
  final ReportData? report;
  final String selectedMonth;
  final bool isMeasureAlarmSet;
  final bool isResultAlarmSet;
  final String? networkErrorMessage;
  final Function() onReportDataChanged;
  final Widget Function() buildReportResultView;

  const MonthlyAlarmView({
    super.key,
    required this.report,
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
  bool _isMeasureAlarmSet = false;
  bool _isResultAlarmSet = false;

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

  @override
  Widget build(BuildContext context) {
    if (widget.networkErrorMessage != null) {
      return Center(
        child: Text(
          "데이터를 불러오지 못했습니다.\n서버 상태나 인터넷 연결을 확인해 주세요.",
          style: TText.body.copyWith(color: TColor.gray),
          textAlign: TextAlign.center,
        ),
      );
    }

    // 1. 한 번도 측정 안 했거나 / 측정 안 했는데(NOT_YET), 30일 경과 시: 측정 유도
    DateTime now = DateTime.now();
    bool isCurrentMonth =
        (widget.report?.year == now.year && widget.report?.month == now.month);
    bool is30DaysPassed =
        isCurrentMonth &&
        widget.report?.measuredAt != null &&
        now.difference(widget.report!.measuredAt!).inDays >= 30;

    if (widget.report?.dataStatus == "NOT_YET" || is30DaysPassed) {
      return _buildReadyView(
        title: "이번 달은 월간 거북목 측정을\n아직 하지 않았어요!",
        isMeasureActionMode: true,
      );
    }

    // 2. 측정은 안 했지만 (NOT_YET), 30일이 지나지 않은 경우: 추후 알림 설정
    if (widget.report?.dataStatus == "NOT_YET" && !is30DaysPassed) {
      DateTime nextAvailableDate = widget.report!.measuredAt!.add(
        const Duration(days: 30),
      );
      String nDay = "${nextAvailableDate.day}일";

      return _buildReadyView(
        title: "이번 달은 $nDay부터 월간 거북목 측정을 할 수 있어요",
        guideText: "$nDay에 알림을 보내드릴까요?",
        alarmType: "MEASURE",
      );
    }

    // 3. 측정 완료 (AVAILABLE): 결과 뷰
    if (widget.report?.dataStatus == "AVAILABLE") {
      return widget.buildReportResultView();
    }

    // 5. 리포트 준비 중: 알림 설정
    return _buildReadyView(
      title: "${widget.selectedMonth} 월간 리포트\n준비 중 . . .",
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
              text: "월간 거북목 측정하러 가기",
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
      onPressed: isSet
          ? null
          : () async {
              final success = await ReportService().registerMonthlyAlarm(
                alarmType: alarmType,
              );
              if (success) {
                setState(() {
                  if (alarmType == "MEASURE")
                    _isMeasureAlarmSet = true;
                  else
                    _isResultAlarmSet = true;
                });
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSet ? TColor.darkGreen : TColor.buttonGreen,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: Text(isSet ? "알림 설정 완료" : "알림 설정", style: TText.button),
    );
  }
}
