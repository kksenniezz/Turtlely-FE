import 'package:flutter/material.dart';
import 'style.dart';
import 'services/report_service.dart';
import 'posture_api_service.dart'; // ApiService 연결

class MonthlyAlarmView extends StatefulWidget {
  final ReportData? report;
  final String selectedMonth;
  final bool isMeasureAlarmSet;
  final bool isResultAlarmSet;
  final String? networkErrorMessage;
  final VoidCallback onReportDataChanged;
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
  final ApiService _apiService = ApiService();

  late bool _isMeasureAlarm;
  late bool _isResultAlarm;
  bool _isUpdatingAlarm = false;

  @override
  void initState() {
    super.initState();
    _isMeasureAlarm = widget.isMeasureAlarmSet;
    _isResultAlarm = widget.isResultAlarmSet;
  }

  @override
  void didUpdateWidget(covariant MonthlyAlarmView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isMeasureAlarmSet != widget.isMeasureAlarmSet) {
      _isMeasureAlarm = widget.isMeasureAlarmSet;
    }
    if (oldWidget.isResultAlarmSet != widget.isResultAlarmSet) {
      _isResultAlarm = widget.isResultAlarmSet;
    }
  }

  // ★ 월간 알림 설정/해제 API 연동 핸들러
  Future<void> _handleAlarmToggle(String alarmType, bool newValue) async {
    setState(() {
      _isUpdatingAlarm = true;
      if (alarmType == "MEASURE") _isMeasureAlarm = newValue;
      if (alarmType == "RESULT") _isResultAlarm = newValue;
    });

    final response = await _apiService.setMonthlyAlarm(alarmType);

    if (!mounted) return;

    if (response != null && response['isSuccess'] == true) {
      final msg = response['message'] ?? "알림 설정이 변경되었습니다.";
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
      // 부모 데이터 최신화
      widget.onReportDataChanged();
    } else {
      // 실패 시 스위치 원래 위치로 원복
      setState(() {
        if (alarmType == "MEASURE") _isMeasureAlarm = !newValue;
        if (alarmType == "RESULT") _isResultAlarm = !newValue;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("알림 설정 변경에 실패했습니다.")),
      );
    }

    setState(() => _isUpdatingAlarm = false);
  }

  @override
  Widget build(BuildContext context) {
    // 1. 네트워크 에러 시
    if (widget.networkErrorMessage != null) {
      return Center(
        child: Text(
          "에러가 발생했습니다:\n${widget.networkErrorMessage}",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    // 2. 리포트 데이터가 있는 경우 -> 결과 뷰 출력
    if (widget.report != null) {
      return widget.buildReportResultView();
    }

    // 3. 리포트 데이터가 없는 경우 -> 알림 설정 카드 출력
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TText.caption.copyWith(
                fontFamily: 'Pretendard',
                color: Colors.black,
              ),
              children: [
                TextSpan(
                  text: "${widget.selectedMonth} 월간 리포트",
                  style: const TextStyle(
                    color: TColor.darkGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(text: "가 아직 없어요"),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ----------------------------------------------------------------
          // 알림 카드 영역
          // ----------------------------------------------------------------
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TColor.buttonGreen),
            ),
            child: Column(
              children: [
                const Text(
                  "월간 거북목 알림",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "한 달에 한 번, 거북목 상태를 측정하고\n맞춤형 분석 리포트를 받아보세요!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),

                // 1) 정기 측정 주기 알림 (MEASURE)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "정기 측정 알림",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "측정 주기가 되면 푸시 알림을 받습니다",
                          style: TextStyle(fontSize: 11, color: Colors.black45),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isMeasureAlarm,
                      activeColor: TColor.darkGreen,
                      onChanged: _isUpdatingAlarm
                          ? null
                          : (val) => _handleAlarmToggle("MEASURE", val),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // 2) 리포트 발행 알림 (RESULT)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "리포트 발행 알림",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "월간 리포트 생성 완료 시 푸시 알림을 받습니다",
                          style: TextStyle(fontSize: 11, color: Colors.black45),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isResultAlarm,
                      activeColor: TColor.darkGreen,
                      onChanged: _isUpdatingAlarm
                          ? null
                          : (val) => _handleAlarmToggle("RESULT", val),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}