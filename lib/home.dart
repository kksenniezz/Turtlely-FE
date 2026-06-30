import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

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

  // 히스토리 변수
  List<double> cvaHistory     = [];
  List<String> timeHistory    = [];
  List<String> postureHistory = [];
  double cvaSum         = 0.0;
  int    cvaCount       = 0;
  int    warningCount   = 0;
  int    cautionCount   = 0;
  int    normalDuration = 0;
  int    totalDuration  = 0;

  List<double> calibAccXList = [];
  List<double> calibAccYList = [];
  List<double> calibAccZList = [];

  int    _lastStatusCode   = 0;
  String _lastResponseBody = "대기 중";
  bool   _hasToken         = false;
  bool   _showDebug        = true;

  final BleService _ble = BleService();
  final ApiService _api = ApiService();

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

    // 💡 실시간 수신 대기 시작
    await _ble.startNotify(parseSensorData);
  }

  Future<void> startMonitoring() async {
    setState(() {
      isCalibrating     = false;
      isMonitoring      = true;
      monitoringSeconds = 0;
    });

    monitorTimer?.cancel();
    monitorTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => monitoringSeconds++);
    });

    dailyApiTimer?.cancel();
    dailyApiTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      // 💡 이제 업데이트된 최신 실시간 센서 값을 들고 파이썬 서버로 갑니다!
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
        debugPrint("🚨 경고! 진동 울림");
        await _ble.sendCommand("VIBRATE");
      } else if (newPostureResult == "caution") {
        debugPrint("⚠️ 주의! 진동 연속 울림");
        await _ble.sendCommand("VIBRATE");
        await Future.delayed(const Duration(milliseconds: 150));
        await _ble.sendCommand("VIBRATE");
      }

      final now = DateTime.now();
      final timeStr = "${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}";

      setState(() {
        postureResult    = newPostureResult;
        isBadPosture     = isBad || newPostureResult == "caution" || newPostureResult == "warning";
        lastEstimatedCva = estimatedCva;

        cvaSum   += estimatedCva;
        cvaCount++;
        totalDuration++;

        if (newPostureResult == "warning") {
          warningCount++;
        } else if (newPostureResult == "caution") {
          cautionCount++;
        } else {
          normalDuration++;
        }

        if (now.second == 0 || cvaHistory.isEmpty) {
          cvaHistory.add(estimatedCva);
          timeHistory.add(timeStr);
          postureHistory.add(newPostureResult);
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
        debugPrint("📊 캘리브레이션 완료 평균값 세팅");

        _api.sendCalibration(avgX, avgY, avgZ).then((result) {
          setState(() {
            _lastStatusCode   = result["statusCode"];
            _lastResponseBody = result["body"];
            _hasToken         = (result["token"] as String).isNotEmpty;
            _showDebug        = true;
          });
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

    // 💡 중요: 수신된 센서 패킷 수치를 실시간 변수에 쉼 없이 갱신해 줍니다!
    setState(() {
      lastAccX = accX;
      lastAccY = accY ?? 0.0;
      lastAccZ = accZ ?? 0.0;
    });
  }

  Future<void> stopMonitoring() async {
    monitorTimer?.cancel();
    dailyApiTimer?.cancel();
    await _ble.sendCommand("STOP");
    await _ble.stopNotify();

    // Hive 로컬 백업 저장
    if (cvaHistory.isNotEmpty) {
      final today = DateTime.now();
      final dateKey = "${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}";
      final avgCva = cvaCount > 0 ? cvaSum / cvaCount : 0.0;

      await DailyReportStorage.saveHistory(
        date           : dateKey,
        cvaHistory     : List.from(cvaHistory),
        timeHistory    : List.from(timeHistory),
        postureHistory : List.from(postureHistory),
        avgCva         : avgCva,
        warningCount   : warningCount,
        cautionCount   : cautionCount,
        duration       : totalDuration,
        normalDuration : normalDuration,
      );
      debugPrint("✅ Hive 저장 완료: $dateKey");
    }

    // 💡 [수정 완료] 고정된 false 대신, 경고 유무에 맞춰 진짜 상태 전달!
    final result = await _api.saveReport(
      isBadPosture: warningCount > 0 || cautionCount > 0, 
      monitoringSeconds: monitoringSeconds,
      level: _level,
      angle: lastEstimatedCva,
    );

    setState(() {
      _lastStatusCode   = result["statusCode"] ?? 0;
      _lastResponseBody = result["body"] ?? "No Response";
      _hasToken         = (result["token"] as String? ?? "").isNotEmpty;
      _showDebug        = true;
      isMonitoring      = false;
      isCalibrating     = false;
      isBadPosture      = false;
      monitoringSeconds = 0;
      calibrationTimer  = 3;
      lastAccX          = 0.0;
      lastAccY          = 0.0;
      lastAccZ          = 0.0;
      lastEstimatedCva  = 0.0;
      postureResult     = 'normal';
      cvaHistory.clear();
      timeHistory.clear();
      postureHistory.clear();
      cvaSum         = 0.0;
      cvaCount       = 0;
      warningCount   = 0;
      cautionCount   = 0;
      normalDuration = 0;
      totalDuration  = 0;
    });

    if (_lastStatusCode == 200 || _lastStatusCode == 201) {
      _showSnackBar("측정 결과가 안전하게 저장되었어요");
    }
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
    return Stack(
      children: [
        Padding(
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
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const VisionPage()),
                    ),
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
        ),

        if (_showDebug)
          Positioned(
            top: 100,
            left: 10,
            right: 10,
            child: GestureDetector(
              onTap: () => setState(() => _showDebug = false),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent, width: 2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "🛠️ 개발자 도구 (터치시 닫힘)",
                      style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "응답코드: $_lastStatusCode\n바디: $_lastResponseBody\n토큰있음: $_hasToken",
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}