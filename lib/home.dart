import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'style.dart';
import 'vision.dart';
import 'ble_service.dart';
import 'posture_api_service.dart';
import 'daily_report_storage.dart';

class HomeViewContent extends StatefulWidget {
  const HomeViewContent({super.key});

  @override
  State<HomeViewContent> createState() => _HomeViewContentState();
}

class _HomeViewContentState extends State<HomeViewContent> {

  bool isMonitoring  = false;
  bool isCalibrating = false;
  bool isBadPosture  = false;

  int    calibrationTimer   = 3;
  int    monitoringSeconds  = 0;
  String selectedDifficulty = '보통';

  double lastAccX         = 0.0;
  double lastAccY         = 0.0;
  double lastAccZ         = 0.0;
  double lastEstimatedCva = 0.0;
  String postureResult    = 'normal';

  // ✅ 이전 자세 상태 (전환될 때만 카운트)
  String _prevPostureResult = 'normal';

  List<double> cvaHistory     = [];
  List<String> timeHistory    = [];
  List<String> postureHistory = [];

  List<double> accXHistory       = [];
  List<double> accYHistory       = [];
  List<double> accZHistory       = [];
  List<String> rawTimeHistory    = [];
  List<double> cvaRawHistory     = [];
  List<String> postureRawHistory = [];

  double cvaSum         = 0.0;
  int    cvaCount       = 0;
  int    warningCount   = 0;
  int    cautionCount   = 0;
  int    normalDuration = 0;
  int    totalDuration  = 0;

  List<double> calibAccXList = [];
  List<double> calibAccYList = [];
  List<double> calibAccZList = [];

  String _worstPostureInMinute = 'normal';

  final BleService _ble = BleService();
  final ApiService _api = ApiService();
  final _storage = const FlutterSecureStorage();

  Timer? monitorTimer;
  Timer? dailyApiTimer;

  String get _level =>
      selectedDifficulty == '낮음' ? 'easy'
    : selectedDifficulty == '높음' ? 'hard'
    : 'normal';

  @override
  void initState() {
    super.initState();
    _ble.onDeviceReadyChanged = (ready) {
      if (!mounted) return;
      setState(() {});
    };
    _ble.init();

    _storage.read(key: 'accessToken').then((token) {
      debugPrint("🔑 accessToken: $token");
    });
  }

  Future<void> startCalibration() async {
    if (!_ble.isDeviceReady || _ble.targetCharacteristic == null) {
      _showSnackBar("기기가 연결되지 않았어요");
      return;
    }

    calibAccXList.clear();
    calibAccYList.clear();
    calibAccZList.clear();

    setState(() {
      isCalibrating    = true;
      calibrationTimer = 3;
      isBadPosture     = false;
    });

    await _ble.sendCommand("CALIB_START");

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
      isCalibrating     = false;
      isMonitoring      = true;
      monitoringSeconds = 0;
      _prevPostureResult = 'normal'; // ✅ 초기화
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
      final newPostureResult = result["postureResult"] as String;
      final estimatedCva     = result["estimatedCva"] as double;
      final isBad            = result["isWarning"] as bool;

      if (newPostureResult == "warning") {
        debugPrint("🚨 경고! CVA: $estimatedCva | 진동 울림");
        await _ble.sendCommand("VIBRATE");
      } else if (newPostureResult == "caution") {
        debugPrint("⚠️ 주의! CVA: $estimatedCva | 진동 연속 울림");
        await _ble.sendCommand("VIBRATE");
        await Future.delayed(const Duration(milliseconds: 150));
        await _ble.sendCommand("VIBRATE");
        await Future.delayed(const Duration(milliseconds: 150));
        await _ble.sendCommand("VIBRATE");
      } else {
        debugPrint("✅ 자세 정상 | CVA: $estimatedCva");
      }

      if (newPostureResult == 'warning') {
        _worstPostureInMinute = 'warning';
      } else if (newPostureResult == 'caution' && _worstPostureInMinute != 'warning') {
        _worstPostureInMinute = 'caution';
      }

      final now = DateTime.now();
      final timeStr    = "${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}";
      final rawTimeStr = "${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}:${now.second.toString().padLeft(2,'0')}";

      setState(() {
        postureResult    = newPostureResult;
        isBadPosture     = isBad || newPostureResult == "caution" || newPostureResult == "warning";
        lastEstimatedCva = estimatedCva;

        cvaSum   += estimatedCva;
        cvaCount++;
        totalDuration++;

        // ✅ 전환될 때만 카운트
        if (newPostureResult == "warning" && _prevPostureResult != "warning") {
          warningCount++;
        } else if (newPostureResult == "caution" && _prevPostureResult != "caution") {
          cautionCount++;
        } else if (newPostureResult == "normal") {
          normalDuration++;
        }
        _prevPostureResult = newPostureResult;

        // 매초 raw 데이터 저장
        rawTimeHistory.add(rawTimeStr);
        accXHistory.add(lastAccX);
        accYHistory.add(lastAccY);
        accZHistory.add(lastAccZ);
        cvaRawHistory.add(estimatedCva);
        postureRawHistory.add(newPostureResult);

        // 분 단위 요약
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

    debugPrint("📥 BLE 수신: $cleanData");

    if (cleanData.startsWith("CALIB_DONE")) {
      final parts = cleanData.replaceFirst("CALIB_DONE:", "").split(',');
      if (parts.length >= 3) {
        final avgX = double.tryParse(parts[0]) ?? 0.0;
        final avgY = double.tryParse(parts[1]) ?? 0.0;
        final avgZ = double.tryParse(parts[2]) ?? 0.0;
        debugPrint("📊 캘리브레이션 완료 | avgX: $avgX, avgY: $avgY, avgZ: $avgZ");
        _api.sendCalibration(avgX, avgY, avgZ).then((result) {
          debugPrint("📡 캘리브레이션 서버 응답: ${result['statusCode']} | ${result['body']}");
        });
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
    monitorTimer?.cancel();
    dailyApiTimer?.cancel();

    // ✅ 버튼 누르는 즉시 UI 초기화
    setState(() {
      isMonitoring          = false;
      isCalibrating         = false;
      isBadPosture          = false;
      postureResult         = 'normal';
      _worstPostureInMinute = 'normal';
      _prevPostureResult    = 'normal';
    });

    await _ble.sendCommand("STOP");
    await _ble.stopNotify();

    if (cvaHistory.isNotEmpty) {
      final today = DateTime.now();
      final dateKey = "${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}";
      final avgCva = cvaCount > 0 ? cvaSum / cvaCount : 0.0;

      // ✅ 기존 데이터 불러와서 합산
      final existingData = await DailyReportStorage.loadHistory(dateKey);

      final prevWarningCount      = existingData?['warningCount']    ?? 0;
      final prevCautionCount      = existingData?['cautionCount']    ?? 0;
      final prevNormalDuration    = existingData?['normalDuration']  ?? 0;
      final prevDuration          = existingData?['duration']        ?? 0;
      final prevAvgCva            = (existingData?['avgCva'] ?? 0.0).toDouble();

      final prevCvaHistory        = List<double>.from(existingData?['cvaHistory']        ?? []);
      final prevTimeHistory       = List<String>.from(existingData?['timeHistory']       ?? []);
      final prevPostureHistory    = List<String>.from(existingData?['postureHistory']    ?? []);
      final prevAccXHistory       = List<double>.from(existingData?['accXHistory']       ?? []);
      final prevAccYHistory       = List<double>.from(existingData?['accYHistory']       ?? []);
      final prevAccZHistory       = List<double>.from(existingData?['accZHistory']       ?? []);
      final prevRawTimeHistory    = List<String>.from(existingData?['rawTimeHistory']    ?? []);
      final prevCvaRawHistory     = List<double>.from(existingData?['cvaRawHistory']     ?? []);
      final prevPostureRawHistory = List<String>.from(existingData?['postureRawHistory'] ?? []);

      // ✅ 평균 CVA 합산 평균
      final prevCvaCount  = prevCvaHistory.length;
      final mergedAvgCva  = (prevCvaCount + cvaCount) > 0
          ? (prevAvgCva * prevCvaCount + avgCva * cvaCount) / (prevCvaCount + cvaCount)
          : avgCva;

      await DailyReportStorage.saveHistory(
        date              : dateKey,
        cvaHistory        : [...prevCvaHistory,        ...cvaHistory],
        timeHistory       : [...prevTimeHistory,       ...timeHistory],
        postureHistory    : [...prevPostureHistory,    ...postureHistory],
        avgCva            : mergedAvgCva,
        warningCount      : prevWarningCount   + warningCount,
        cautionCount      : prevCautionCount   + cautionCount,
        duration          : prevDuration       + totalDuration,
        normalDuration    : prevNormalDuration + normalDuration,
        accXHistory       : [...prevAccXHistory,       ...accXHistory],
        accYHistory       : [...prevAccYHistory,       ...accYHistory],
        accZHistory       : [...prevAccZHistory,       ...accZHistory],
        rawTimeHistory    : [...prevRawTimeHistory,    ...rawTimeHistory],
        cvaRawHistory     : [...prevCvaRawHistory,     ...cvaRawHistory],
        postureRawHistory : [...prevPostureRawHistory, ...postureRawHistory],
      );
      debugPrint("✅ Hive 저장 완료: $dateKey | 평균CVA: $mergedAvgCva | 경고: ${prevWarningCount + warningCount} | 주의: ${prevCautionCount + cautionCount}");
    }

    _showSnackBar("측정 결과가 저장되었어요");

    setState(() {
      monitoringSeconds  = 0;
      calibrationTimer   = 3;
      lastAccX           = 0.0;
      lastAccY           = 0.0;
      lastAccZ           = 0.0;
      lastEstimatedCva   = 0.0;
      cvaHistory.clear();
      timeHistory.clear();
      postureHistory.clear();
      accXHistory.clear();
      accYHistory.clear();
      accZHistory.clear();
      rawTimeHistory.clear();
      cvaRawHistory.clear();
      postureRawHistory.clear();
      cvaSum         = 0.0;
      cvaCount       = 0;
      warningCount   = 0;
      cautionCount   = 0;
      normalDuration = 0;
      totalDuration  = 0;
    });
  }

  @override
  void dispose() {
    monitorTimer?.cancel();
    dailyApiTimer?.cancel();
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
                style: TText.title.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () async {
                  await _ble.stopNotify();
                  await _ble.disconnect();
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const VisionPage()),
                  ).then((_) {
                    _ble.init();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                  ),
                  child: Text(
                    "월간 거북목 측정하러 가기 >",
                    style: TText.caption.copyWith(color: TColor.darkGreen, fontWeight: FontWeight.bold),
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
                    style: TText.title.copyWith(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.battery_3_bar, color: TColor.gray, size: 20),
                      const SizedBox(width: 4),
                      const Text("85%", style: TText.caption),
                      const SizedBox(width: 8),
                      Icon(
                        _ble.isDeviceReady ? Icons.bluetooth_connected : Icons.bluetooth_searching,
                        color: _ble.isDeviceReady ? TColor.buttonGreen : TColor.gray,
                        size: 14,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        _ble.isDeviceReady ? "기기 연결됨" : "기기 탐색 중",
                        style: TextStyle(
                          fontSize: 11,
                          color: _ble.isDeviceReady ? TColor.buttonGreen : TColor.gray,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: ['낮음', '보통', '높음'].map((level) {
                  final isSelected = selectedDifficulty == level;
                  return GestureDetector(
                    onTap: () => setState(() => selectedDifficulty = level),
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? TColor.buttonGreen : TColor.lightGreen,
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
                            Text("$calibrationTimer", style: TText.logo.copyWith(fontSize: 48)),
                            const SizedBox(height: 8),
                            Text("평소 자세 유지해주세요", style: TText.caption),
                          ],
                        ),
                      ],
                    )
                  : Image.asset(
                      postureResult == "warning"
                          ? 'assets/fire_turtle.png'
                          : postureResult == "caution"
                              ? 'assets/surprised_turtle.png'
                              : 'assets/normal_turtle.png',
                      width: 280,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/normal_turtle.png',
                        width: 280,
                        errorBuilder: (_, __, ___) => const SizedBox(),
                      ),
                    ),
            ),
          ),
          Text("거북목 교정 중에는 터틀훅을 착용해주세요", style: TText.caption),
          const SizedBox(height: 16),
          ElevatedButton(
            style: T_MainButtonStyle,
            onPressed: isMonitoring ? stopMonitoring : startCalibration,
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