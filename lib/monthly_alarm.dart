import 'package:flutter/material.dart';
import 'style.dart';
import 'services/report_service.dart';

class MonthlyAlarmView extends StatelessWidget {
  final ReportData? report;
  final int status;
  final String selectedMonth;
  final bool isAlarmRegistered;
  final String? networkErrorMessage;
  final Widget Function({
    required String title,
    bool isMeasureActionMode,
    bool hideActionButtons,
  })
  buildReadyView;
  final Widget Function() buildReportResultView;

  const MonthlyAlarmView({
    super.key,
    required this.report,
    required this.status,
    required this.selectedMonth,
    required this.isAlarmRegistered,
    required this.networkErrorMessage,
    required this.buildReadyView,
    required this.buildReportResultView,
  });

  @override
  Widget build(BuildContext context) {
    // 1. 에러 체크
    if (networkErrorMessage != null) {
      return Center(
        child: Text(
          "데이터를 불러오지 못했습니다.\n서버 상태나 인터넷 연결을 확인해 주세요.",
          style: TText.body.copyWith(color: TColor.gray),
          textAlign: TextAlign.center,
        ),
      );
    }

    // 2. 상태별 화면 분기
    if (status == 1 && (report == null || report!.totalMeasurements == 0)) {
      return buildReadyView(
        title: "이번 달은 월간 거북목 측정을\n아직 하지 않았어요!",
        isMeasureActionMode: true,
      );
    }

    if (status == 2 && report == null) {
      return buildReadyView(
        title: "$selectedMonth 월간 거북목 측정 기록이 없습니다",
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
        return buildReadyView(title: "이번 달은 측정일이 되면\n월간 거북목 측정을 할 수 있어요");
      case 1:
      case 2:
        return buildReportResultView();
      default:
        return const SizedBox();
    }
  }
}
