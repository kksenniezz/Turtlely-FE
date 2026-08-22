import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'style.dart';
import 'vision.dart';
import 'ble_service.dart';
import 'posture_api_service.dart';
import 'daily_report_storage.dart';
import 'main.dart';
import 'home_onboarding_dialog.dart';

final GlobalKey monthlyBtnKey = GlobalKey();
final GlobalKey difficultyBtnKey = GlobalKey();

class HomeViewContent extends StatefulWidget {
  const HomeViewContent({super.key});

  @override
  State<HomeViewContent> createState() => _HomeViewContentState();
}

class _HomeViewContentState extends State<HomeViewContent> {
  bool isMonitoring = false;
  bool isCalibrating = false;
  bool isBadPosture = false;

  int calibrationTimer = 3;
  int monitoringSeconds = 0;
  String selectedDifficulty = '보통';

  double lastAccX = 0.0;
  double lastAccY = 0.0;
  double lastAccZ = 0.0;
  double lastEstimatedCva = 0.0;
  String postureResult = 'normal';

  String _prevPostureResult = 'normal';
  int? _batteryPercent;
  bool _hasSentBatteryNotification = false;

  bool _isNavigatingToVision = false;

  List<double> cvaHistory = [];
  List<String> timeHistory = [];
  List<String> postureHistory = [];

  List<double> accXHistory = [];
  List<double> accYHistory = [];
  List<double> accZHistory = [];
  List<String> rawTimeHistory = [];
  List<double> cvaRawHistory = [];
  List<String> postureRawHistory = [];

  double cvaSum = 0.0;
  int cvaCount = 0;
  int warningCount = 0;
  int cautionCount = 0;
  int normalDuration = 0;
  int totalDuration = 0;

  List<double> calibAccXList = [];
  List<double> calibAccYList = [];
  List<double> calibAccZList = [];

  String _worstPostureInMinute = 'normal';

  final BleService _ble = BleService();
  final ApiService _api = ApiService();
  final _storage = const FlutterSecureStorage();

  Timer? monitorTimer;
  Timer? dailyApiTimer;

  String get _level => selectedDifficulty == '낮음'
      ? 'easy'
      : selectedDifficulty == '높음'
      ? 'hard'
      : 'normal';

  @override
  void initState() {
    super.initState();
    _ble.onDeviceReadyChanged = (ready) async {
      if (!mounted) return;
      setState(() {});

      if (!ready) {
        if (_isNavigatingToVision) {
          debugPrint("⏸️ 월간 화면 이동 중 - 홈 BLE 자동 재연결 스킵");
          return;
        }

        if (isMonitoring) {
          _showDisconnectDialog();
        }

        await Future.delayed(const Duration(seconds: 3));
        if (mounted && !_ble.isDeviceReady && !_isNavigatingToVision) {
          debugPrint("🔄 BLE 기기 자동 재연결 시도...");
          _ble.init();
        }
      }
    };

    _ble.onBatteryChanged = (batt) {
      if (!mounted) return;
      setState(() => _batteryPercent = batt);
      _checkBatteryLevelAndNotify(batt);
    };

    _storage.read(key: 'accessToken').then((token) {
      debugPrint("🔑 accessToken: $token");
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      HomeOnboardingDialog.checkAndShow(
        context,
        userName: "사용자",
        onComplete: () {
          debugPrint("홈 온보딩 완료!");
          _ble.init();
        },
      );
    });
  }

  Future<Map<String, dynamic>> _checkMonthlyMeasurementValid() async {
    try {
      final token = await _storage.read(key: 'accessToken');
      if (token == null || token.isEmpty) {
        return {'isValid': false, 'reason': 'NO_TOKEN'};
      }

      final response = await http.get(
        Uri.parse("http://54.144.66.35.nip.io:8080/api/monthly/list"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final List<dynamic> list = jsonResponse['result'] ?? [];

        final validReports = list
            .where((item) => item['measuredAt'] != null)
            .toList();

        if (validReports.isEmpty) {
          return {'isValid': false, 'reason': 'NO_MEASUREMENT'};
        }

        validReports.sort(
          (a, b) => DateTime.parse(
            b['measuredAt'],
          ).compareTo(DateTime.parse(a['measuredAt'])),
        );

        final DateTime lastMeasuredAt = DateTime.parse(
          validReports.first['measuredAt'],
        );
        final DateTime expireDate = lastMeasuredAt.add(
          const Duration(days: 30),
        );
        final DateTime now = DateTime.now();

        if (now.isAfter(expireDate)) {
          int passedDays = now.difference(lastMeasuredAt).inDays;
          return {
            'isValid': false,
            'reason': 'EXPIRED',
            'passedDays': passedDays,
          };
        }

        return {'isValid': true, 'lastMeasuredAt': lastMeasuredAt};
      }
    } catch (e) {
      debugPrint("월간 측정 검증 오류: $e");
    }

    return {'isValid': false, 'reason': 'ERROR'};
  }

  void _showMonthlyRequiredDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 52,
                  color: Color(0xFFFF9800),
                ),
                const SizedBox(height: 16),
                const Text(
                  "월간 측정 필요",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE0E0E0),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text(
                            "취소",
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TColor.buttonGreen,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            Navigator.of(dialogContext).pop();
                            _isNavigatingToVision = true;

                            try {
                              await _ble.stopNotify();
                              await _ble.disconnect();
                            } catch (_) {}

                            if (!mounted) return;

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const VisionPage(),
                              ),
                            ).then((_) {
                              _isNavigatingToVision = false;
                              if (mounted) _ble.init();
                            });
                          },
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "측정하기",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _checkBatteryLevelAndNotify(int battery) {
    if (battery <= 20) {
      if (!_hasSentBatteryNotification) {
        _hasSentBatteryNotification = true;

        final now = DateTime.now();
        final timeStr =
            "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

        localNotifications.insert(0, {
          "notification_id": DateTime.now().millisecondsSinceEpoch,
          "type": "BATTERY",
          "content": "터틀훅 배터리가 $battery% 남았습니다. 충전해 주세요!",
          "is_read": false,
          "created_at": timeStr,
        });

        hasUnreadNotification.value = true;
      }
    } else {
      _hasSentBatteryNotification = false;
    }
  }

  void _showStopConfirmDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "자세 교정을 종료하시겠습니까?",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE0E0E0),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: const Text(
                            "취소",
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF91A88C),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            stopMonitoring();
                          },
                          child: const Text(
                            "확인",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                const Text(
                  "터틀훅 연결이 끊겼어요!",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  "블루투스 연결 상태를 확인한 후\n다시 시도해 주세요",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF91A88C),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      forceStopMonitoring();
                    },
                    child: const Text(
                      "확인",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void forceStopMonitoring() {
    monitorTimer?.cancel();
    dailyApiTimer?.cancel();

    try {
      _ble.stopNotify();
    } catch (_) {}

    setState(() {
      isMonitoring = false;
      isCalibrating = false;
      isBadPosture = false;
      monitoringSeconds = 0;
      calibrationTimer = 3;
      postureResult = 'normal'; // ✅ 기본 거북이로 초기화
      _worstPostureInMinute = 'normal';
      _prevPostureResult = 'normal';
      lastAccX = 0.0;
      lastAccY = 0.0;
      lastAccZ = 0.0;
      lastEstimatedCva = 0.0;
      cvaHistory.clear();
      timeHistory.clear();
      postureHistory.clear();
      accXHistory.clear();
      accYHistory.clear();
      accZHistory.clear();
      rawTimeHistory.clear();
      cvaRawHistory.clear();
      postureRawHistory.clear();
      cvaSum = 0.0;
      cvaCount = 0;
      warningCount = 0;
      cautionCount = 0;
      normalDuration = 0;
      totalDuration = 0;
    });

    _showSnackBar("연결이 끊겨 측정이 종료되었습니다.");
  }

  Future<void> startCalibration() async {
    final checkResult = await _checkMonthlyMeasurementValid();

    if (!checkResult['isValid']) {
      if (mounted) {
        String reason = checkResult['reason'];
        if (reason == 'NO_MEASUREMENT') {
          _showMonthlyRequiredDialog("월간 측정 기록이 없습니다.");
        } else if (reason == 'EXPIRED') {
          int passedDays = checkResult['passedDays'] ?? 30;
          _showMonthlyRequiredDialog(
            "마지막 월간 측정 후 $passedDays일이 지났습니다.\n정확한 자세 교정을 위해 월간 측정을 다시 진행해 주세요.",
          );
        } else {
          _showSnackBar("월간 측정 상태를 확인하지 못했습니다.");
        }
      }
      return;
    }

    if (!_ble.isDeviceReady || _ble.targetCharacteristic == null) {
      _showSnackBar("기기가 연결되지 않았어요. 전원을 확인해 주세요.");
      return;
    }

    try {
      await _ble.sendCommand("CALIB_START");
    } catch (e) {
      if (mounted) {
        _showSnackBar("기기와 연결할 수 없어요. 전원이 켜져 있는지 확인해 주세요.");
      }
      return;
    }

    calibAccXList.clear();
    calibAccYList.clear();
    calibAccZList.clear();

    setState(() {
      isCalibrating = true;
      calibrationTimer = 3;
      isBadPosture = false;
      postureResult = 'normal'; // ✅ 캘리브레이션 시작 시 기본 거북이 유지
    });

    monitorTimer?.cancel();
    monitorTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (calibrationTimer > 1) {
        setState(() => calibrationTimer--);
      } else {
        timer.cancel();
      }
    });

    await _ble.startNotify(parseSensorData);
  }

  Future<void> startMonitoring() async {
    setState(() {
      isCalibrating = false;
      isMonitoring = true;
      monitoringSeconds = 0;
      postureResult = 'normal';
      _prevPostureResult = 'normal';
    });

    monitorTimer?.cancel();
    monitorTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => monitoringSeconds++);
    });

    dailyApiTimer?.cancel();
    dailyApiTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final result = await _api.sendDaily(
        accX: lastAccX,
        accY: lastAccY,
        accZ: lastAccZ,
        level: _level,
      );

      // ✅ 종료된 상태에서 늦게 도착한 API 응답 무시 (거북이 상태 덮어쓰기 방지)
      if (!isMonitoring || !mounted) return;

      final newPostureResult = result["postureResult"] as String;
      final estimatedCva = result["estimatedCva"] as double;
      final isBad = result["isWarning"] as bool;

      if (newPostureResult == "warning") {
        await _ble.sendCommand("VIBRATE");
        await Future.delayed(const Duration(milliseconds: 150));
        await _ble.sendCommand("VIBRATE");
        await Future.delayed(const Duration(milliseconds: 150));
        await _ble.sendCommand("VIBRATE");
      } else if (newPostureResult == "caution") {
        await _ble.sendCommand("VIBRATE");
      } else {
        debugPrint("✅ 자세 정상 | CVA: $estimatedCva");
      }

      if (newPostureResult == 'warning') {
        _worstPostureInMinute = 'warning';
      } else if (newPostureResult == 'caution' &&
          _worstPostureInMinute != 'warning') {
        _worstPostureInMinute = 'caution';
      }

      final now = DateTime.now();
      final timeStr =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
      final rawTimeStr =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

      setState(() {
        postureResult = newPostureResult;
        isBadPosture =
            isBad ||
            newPostureResult == "caution" ||
            newPostureResult == "warning";
        lastEstimatedCva = estimatedCva;

        cvaSum += estimatedCva;
        cvaCount++;
        totalDuration++;

        if (newPostureResult == "warning" && _prevPostureResult != "warning") {
          warningCount++;
        } else if (newPostureResult == "caution" &&
            _prevPostureResult != "caution") {
          cautionCount++;
        } else if (newPostureResult == "normal") {
          normalDuration++;
        }
        _prevPostureResult = newPostureResult;

        rawTimeHistory.add(rawTimeStr);
        accXHistory.add(lastAccX);
        accYHistory.add(lastAccY);
        accZHistory.add(lastAccZ);
        cvaRawHistory.add(estimatedCva);
        postureRawHistory.add(newPostureResult);

        if (now.second == 0 || cvaHistory.isEmpty) {
          cvaHistory.add(estimatedCva);
          timeHistory.add(timeStr);
          postureHistory.add(_worstPostureInMinute);
          _worstPostureInMinute = 'normal';
        }
      });
    });
  }

  void parseSensorData(String data) {
    final cleanData = data.trim();
    if (cleanData.isEmpty) return;

    if (cleanData.startsWith("CALIB_DONE")) {
      final parts = cleanData.replaceFirst("CALIB_DONE:", "").split(',');
      if (parts.length >= 3) {
        final avgX = double.tryParse(parts[0]) ?? 0.0;
        final avgY = double.tryParse(parts[1]) ?? 0.0;
        final avgZ = double.tryParse(parts[2]) ?? 0.0;
        _api.sendCalibration(avgX, avgY, avgZ);
      }
      startMonitoring();
      return;
    }

    if (cleanData == "NO_POSE_CALIB") {
      _showSnackBar("자세 교정 시작 버튼을 눌러주세요");
      return;
    }

    if (cleanData == "WAIT") return;

    final parts = cleanData.split(',');
    if (parts.length < 3) return;

    final accX = double.tryParse(parts[0]);
    final accY = double.tryParse(parts[1]);
    final accZ = double.tryParse(parts[2]);
    if (accX == null) return;

    setState(() {
      lastAccX = accX;
      lastAccY = accY ?? 0.0;
      lastAccZ = accZ ?? 0.0;
    });
  }

  Future<void> stopMonitoring() async {
    // 1. 타이머 즉시 정지
    monitorTimer?.cancel();
    dailyApiTimer?.cancel();

    // 2. 화면 상태를 즉시 '기본 거북이' 및 모니터링 종료로 리셋
    setState(() {
      isMonitoring = false;
      isCalibrating = false;
      isBadPosture = false;
      postureResult = 'normal'; // ✅ 첫 화면 기본 거북이로 확실하게 고정
      _worstPostureInMinute = 'normal';
      _prevPostureResult = 'normal';
    });

    if (_ble.isDeviceReady) {
      try {
        await _ble.sendCommand("STOP");
        await _ble.stopNotify();
      } catch (_) {}
    }

    // 3. 기록 저장 처리
    if (cvaHistory.isNotEmpty) {
      final today = DateTime.now();
      final dateKey =
          "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
      final avgCva = cvaCount > 0 ? cvaSum / cvaCount : 0.0;

      final existingData = await DailyReportStorage.loadHistory(dateKey);

      final prevWarningCount = existingData?['warningCount'] ?? 0;
      final prevCautionCount = existingData?['cautionCount'] ?? 0;
      final prevNormalDuration = existingData?['normalDuration'] ?? 0;
      final prevDuration = existingData?['duration'] ?? 0;
      final prevAvgCva = (existingData?['avgCva'] ?? 0.0).toDouble();

      final prevCvaHistory = List<double>.from(
        existingData?['cvaHistory'] ?? [],
      );
      final prevTimeHistory = List<String>.from(
        existingData?['timeHistory'] ?? [],
      );
      final prevPostureHistory = List<String>.from(
        existingData?['postureHistory'] ?? [],
      );
      final prevAccXHistory = List<double>.from(
        existingData?['accXHistory'] ?? [],
      );
      final prevAccYHistory = List<double>.from(
        existingData?['accYHistory'] ?? [],
      );
      final prevAccZHistory = List<double>.from(
        existingData?['accZHistory'] ?? [],
      );
      final prevRawTimeHistory = List<String>.from(
        existingData?['rawTimeHistory'] ?? [],
      );
      final prevCvaRawHistory = List<double>.from(
        existingData?['cvaRawHistory'] ?? [],
      );
      final prevPostureRawHistory = List<String>.from(
        existingData?['postureRawHistory'] ?? [],
      );

      final prevCvaCount = prevCvaHistory.length;
      final mergedAvgCva = (prevCvaCount + cvaCount) > 0
          ? (prevAvgCva * prevCvaCount + avgCva * cvaCount) /
                (prevCvaCount + cvaCount)
          : avgCva;

      await DailyReportStorage.saveHistory(
        date: dateKey,
        cvaHistory: [...prevCvaHistory, ...cvaHistory],
        timeHistory: [...prevTimeHistory, ...timeHistory],
        postureHistory: [...prevPostureHistory, ...postureHistory],
        avgCva: mergedAvgCva,
        warningCount: prevWarningCount + warningCount,
        cautionCount: prevCautionCount + cautionCount,
        duration: prevDuration + totalDuration,
        normalDuration: prevNormalDuration + normalDuration,
        accXHistory: [...prevAccXHistory, ...accXHistory],
        accYHistory: [...prevAccYHistory, ...accYHistory],
        accZHistory: [...prevAccZHistory, ...accZHistory],
        rawTimeHistory: [...prevRawTimeHistory, ...rawTimeHistory],
        cvaRawHistory: [...prevCvaRawHistory, ...cvaRawHistory],
        postureRawHistory: [...prevPostureRawHistory, ...postureRawHistory],
      );
      debugPrint("✅ Hive 저장 완료: $dateKey");
    }

    _showSnackBar("측정 결과가 저장되었어요");

    setState(() {
      monitoringSeconds = 0;
      calibrationTimer = 3;
      lastAccX = 0.0;
      lastAccY = 0.0;
      lastAccZ = 0.0;
      lastEstimatedCva = 0.0;
      postureResult = 'normal'; // ✅ 데이터 저장 후에도 기본 거북이 유지
      cvaHistory.clear();
      timeHistory.clear();
      postureHistory.clear();
      accXHistory.clear();
      accYHistory.clear();
      accZHistory.clear();
      rawTimeHistory.clear();
      cvaRawHistory.clear();
      postureRawHistory.clear();
      cvaSum = 0.0;
      cvaCount = 0;
      warningCount = 0;
      cautionCount = 0;
      normalDuration = 0;
      totalDuration = 0;
    });
  }

  @override
  void dispose() {
    monitorTimer?.cancel();
    dailyApiTimer?.cancel();

    _ble.onDeviceReadyChanged = null;
    _ble.onBatteryChanged = null;

    _ble.dispose();
    super.dispose();
  }

  String getTodayDate() {
    final now = DateTime.now();
    return "${now.month}월 ${now.day}일";
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                getTodayDate(),
                style: TText.title.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              GestureDetector(
                onTap: () async {
                  _isNavigatingToVision = true;

                  try {
                    await _ble.stopNotify();
                    await _ble.disconnect();
                  } catch (e) {
                    debugPrint("BLE 해제 중 예외 발생 (무시하고 화면 이동): $e");
                  }

                  if (!mounted) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VisionPage()),
                  ).then((_) {
                    _isNavigatingToVision = false;
                    if (mounted) {
                      _ble.init();
                    }
                  });
                },
                child: Container(
                  key: monthlyBtnKey,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    "월간 측정하러 가기 >",
                    style: TText.caption.copyWith(
                      color: TColor.darkGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${(monitoringSeconds ~/ 60).toString().padLeft(2, '0')}:${(monitoringSeconds % 60).toString().padLeft(2, '0')}",
                    style: TText.title.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      if (_ble.isDeviceReady && _batteryPercent != null) ...[
                        Icon(
                          (_batteryPercent! >= 75)
                              ? Icons.battery_full
                              : (_batteryPercent! >= 50)
                              ? Icons.battery_5_bar
                              : (_batteryPercent! >= 25)
                              ? Icons.battery_3_bar
                              : (_batteryPercent! >= 10)
                              ? Icons.battery_1_bar
                              : Icons.battery_alert,
                          color: (_batteryPercent! <= 20)
                              ? Colors.red
                              : TColor.gray,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text("$_batteryPercent%", style: TText.caption),
                        const SizedBox(width: 8),
                      ],
                      Icon(
                        _ble.isDeviceReady
                            ? Icons.bluetooth_connected
                            : Icons.bluetooth_searching,
                        color: _ble.isDeviceReady
                            ? TColor.buttonGreen
                            : TColor.gray,
                        size: 14,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _ble.isDeviceReady ? "기기 연결됨" : "기기 탐색 중",
                        style: TextStyle(
                          fontSize: 11,
                          color: _ble.isDeviceReady
                              ? TColor.buttonGreen
                              : TColor.gray,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                key: difficultyBtnKey,
                children: ['낮음', '보통', '높음'].map((level) {
                  final isSelected = selectedDifficulty == level;
                  return GestureDetector(
                    onTap: () => setState(() => selectedDifficulty = level),
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? TColor.buttonGreen
                            : TColor.lightGreen,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        level,
                        style: TextStyle(
                          color: isSelected ? TColor.white : TColor.gray,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Expanded(
            child: Center(
              child: isCalibrating
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 200,
                          height: 200,
                          child: CircularProgressIndicator(
                            value: 1 - (calibrationTimer / 3),
                            color: TColor.buttonGreen,
                            strokeWidth: 8,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "$calibrationTimer",
                              style: TText.logo.copyWith(fontSize: 48),
                            ),
                            const SizedBox(height: 8),
                            Text("평소 자세 유지해주세요", style: TText.caption),
                          ],
                        ),
                      ],
                    )
                  : Image.asset(
                      // ✅ 측정 중이 아닐 때는 무조건 기본 거북이 표시
                      (!isMonitoring || postureResult == "normal")
                          ? 'assets/normal_turtle.png'
                          : postureResult == "warning"
                          ? 'assets/fire_turtle.png'
                          : 'assets/surprised_turtle.png',
                      width: 280,
                      errorBuilder: (_, __, ___) =>
                          Image.asset('assets/normal_turtle.png', width: 280),
                    ),
            ),
          ),
          Text("거북목 교정을 하는 동안 터틀훅을 꼭 착용해 주세요", style: TText.caption),
          const SizedBox(height: 16),
          ElevatedButton(
            style: T_MainButtonStyle,
            onPressed: isMonitoring ? _showStopConfirmDialog : startCalibration,
            child: Text(
              isMonitoring ? "자세 교정 종료하기" : "자세 교정 시작하기",
              style: TText.button,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}