import 'package:flutter/material.dart';
import 'style.dart';
import 'vision.dart';
import 'services/report_service.dart';

class MonthlyAlarmView extends StatefulWidget {
  final ReportData? report;
  final int status;
  final String selectedMonth;
  final bool isAlarmRegistered;
  final String? networkErrorMessage;
  final Function() onReportDataChanged;
  final Widget Function() buildReportResultView;

  const MonthlyAlarmView({
    super.key,
    required this.report,
    required this.status,
    required this.selectedMonth,
    required this.isAlarmRegistered,
    required this.networkErrorMessage,
    required this.onReportDataChanged,
    required this.buildReportResultView,
  });

  @override
  State<MonthlyAlarmView> createState() => _MonthlyAlarmViewState();
}

class _MonthlyAlarmViewState extends State<MonthlyAlarmView> {
  bool _isAlarmRegistered = false;

  @override
  void initState() {
    super.initState();
    _isAlarmRegistered = widget.isAlarmRegistered;
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

    // 2. 상태별 화면 분기
    if (widget.status == 1 &&
        (widget.report == null || widget.report!.totalMeasurements == 0)) {
      return _buildReadyView(
        title: "이번 달은 월간 거북목 측정을\n아직 하지 않았어요!",
        isMeasureActionMode: true,
      );
    }

    if (widget.status == 2 && widget.report == null) {
      return _buildReadyView(
        title: "${widget.selectedMonth} 월간 거북목 측정 기록이 없습니다",
        hideActionButtons: true,
      );
    }

    if (widget.isAlarmRegistered && widget.status != 2) {
      return Center(
        child: Text(
          widget.status == 0 ? "측정 기간이 되면 알려드릴게요!" : "리포트를 열심히 분석 중이에요!",
          style: TText.body.copyWith(color: TColor.gray),
          textAlign: TextAlign.center,
        ),
      );
    }

    switch (widget.status) {
      case 0:
        return _buildReadyView(title: "이번 달은 측정일이 되면\n월간 거북목 측정을 할 수 있어요");
      case 1:
      case 2:
        return widget.buildReportResultView();
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
              onPressed: _isAlarmRegistered && !isMeasureActionMode
                  ? null
                  : () async {
                      if (isMeasureActionMode) {
                        final bool? isMeasured = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const VisionPage(),
                          ),
                        );
                        if (isMeasured == true) widget.onReportDataChanged();
                      } else {
                        setState(() => _isAlarmRegistered = true);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAlarmRegistered && !isMeasureActionMode
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
                    : (_isAlarmRegistered ? "알림 설정 완료" : "알림 설정"),
                style: TText.button,
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
