import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  static const String SERVICE_UUID   = "12345678-1234-1234-1234-123456789012";
  static const String CHAR_UUID      = "87654321-4321-4321-4321-210987654321";
  static const String CMD_CHAR_UUID  = "11111111-1111-1111-1111-111111111111";
  static const String BATT_CHAR_UUID = "2a19";

  BluetoothDevice?         _connectedDevice;
  BluetoothCharacteristic? targetCharacteristic;
  BluetoothCharacteristic? _cmdCharacteristic;

  bool _isDeviceReady = false;
  bool get isDeviceReady => _isDeviceReady;

  Function(bool)? onDeviceReadyChanged;
  Function(int)?  onBatteryChanged;

  StreamSubscription<List<ScanResult>>?         _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>?                _notifySubscription;
  StreamSubscription<List<int>>?                _battNotifySubscription;

  Timer? _pingTimer;

  bool _isConnecting = false;
  bool _isScanning   = false;

  /// BLE 스캔 시작
  Future<void> init() async {
    if (_isDeviceReady) {
      onDeviceReadyChanged?.call(true);
      return;
    }
    if (_isConnecting || _isScanning) {
      debugPrint("⚠️ 이미 스캔 또는 연결 시도 중입니다.");
      return;
    }

    try {
      _isScanning = true;
      debugPrint("🔵 BLE 스캔 시작...");

      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          final deviceName = r.device.platformName;
          final advertisesService = r.advertisementData.serviceUuids
              .any((u) => u.toString().toLowerCase() == SERVICE_UUID.toLowerCase());

          if ((deviceName.contains("Turtlely") || advertisesService) && !_isConnecting) {
            _isConnecting = true;
            debugPrint("🎯 타겟 기기 발견: $deviceName (${r.device.remoteId})");

            await FlutterBluePlus.stopScan();
            _isScanning = false;
            await _connectToDevice(r.device);
            break;
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

      // 스캔이 끝날 때까지 기다렸다가, 못 찾았으면 플래그 풀기
      await FlutterBluePlus.isScanning.where((s) => s == false).first;
      if (!_isConnecting && !_isDeviceReady) {
        _isScanning = false;
        _scanSubscription?.cancel();
        _scanSubscription = null;
        debugPrint("⚠️ 스캔 종료: 기기를 찾지 못했습니다.");
      }
    } catch (e) {
      _isScanning   = false;
      _isConnecting = false;
      debugPrint("❌ BLE 스캔 오류: $e");
    }
  }

  /// 디바이스 연결
  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(
        license: License.free,
        autoConnect: false,
        timeout: const Duration(seconds: 10),
      );
      _connectedDevice = device;
      debugPrint("✅ 기기 연결 성공: ${device.platformName}");

      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnected();
          debugPrint("❌ 기기 연결 해제됨 (OS 이벤트)");
        }
      });

      await _discoverServices(device);
    } catch (e) {
      _isConnecting = false;
      _isScanning   = false;
      debugPrint("❌ 기기 연결 실패: $e");
      // 2초 뒤 한 번 더 시도
      Future.delayed(const Duration(seconds: 2), () {
        if (!_isDeviceReady) init();
      });
    }
  }

  /// 서비스 및 특성 탐색
  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();

      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          for (BluetoothCharacteristic c in service.characteristics) {
            final uuid = c.uuid.toString().toLowerCase();

            if (uuid == CHAR_UUID.toLowerCase()) {
              targetCharacteristic = c;
              debugPrint("✅ CVA 특성 발견");
            }

            if (uuid == CMD_CHAR_UUID.toLowerCase()) {
              _cmdCharacteristic = c;
              debugPrint("✅ CMD 특성 발견");
            }

            if (uuid.contains(BATT_CHAR_UUID)) {
              try {
                await c.setNotifyValue(true);
                _battNotifySubscription?.cancel();
                _battNotifySubscription = c.value.listen((value) {
                  if (value.isNotEmpty) {
                    final battPercent = value[0];
                    debugPrint("🔋 잔여 배터리: $battPercent%");
                    onBatteryChanged?.call(battPercent);
                  }
                });
                debugPrint("✅ 배터리 특성 구독 완료");
              } catch (e) {
                debugPrint("❌ 배터리 Notify 실패: $e");
              }
            }
          }

          if (targetCharacteristic != null && _cmdCharacteristic != null) {
            _isDeviceReady = true;
            _isConnecting  = false;
            onDeviceReadyChanged?.call(true);
            debugPrint("✅ 모든 특성 준비 완료!");
            _startPingMonitor();
          }
        }
      }

      // 필요한 특성을 못 찾았으면 플래그 풀고 정리
      if (!_isDeviceReady) {
        debugPrint("❌ 필요한 서비스/특성을 찾지 못했습니다.");
        _isConnecting = false;
        await disconnect();
      }
    } catch (e) {
      _isConnecting = false;
      debugPrint("❌ 서비스 탐색 오류: $e");
    }
  }

  /// 1초마다 연결 확인 (3번 연속 실패해야 끊김으로 판단)
  void _startPingMonitor() {
    _pingTimer?.cancel();
    int failCount = 0;
    _pingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_connectedDevice != null && _isDeviceReady) {
        try {
          await _connectedDevice!.readRssi();
          failCount = 0;
        } catch (e) {
          failCount++;
          debugPrint("⚠️ Ping 실패 $failCount/3");
          if (failCount >= 3) {
            debugPrint("⚡ 전원 꺼짐 감지!");
            timer.cancel();
            await disconnect();
          }
        }
      } else {
        timer.cancel();
      }
    });
  }

  /// 데이터 수신 시작
  Future<void> startNotify(Function(String) onData) async {
    if (targetCharacteristic == null) return;
    try {
      _notifySubscription?.cancel();
      await targetCharacteristic!.setNotifyValue(true);
      _notifySubscription = targetCharacteristic!.value.listen((value) {
        if (value.isNotEmpty) {
          onData(String.fromCharCodes(value));
        }
      });
      debugPrint("✅ Notify 구독 시작");
    } catch (e) {
      debugPrint("❌ Notify 구독 실패: $e");
    }
  }

  /// 데이터 수신 중지
  Future<void> stopNotify() async {
    if (targetCharacteristic == null) return;
    try {
      _notifySubscription?.cancel();
      _notifySubscription = null;
      await targetCharacteristic!.setNotifyValue(false);
      debugPrint("✅ Notify 구독 중지");
    } catch (e) {
      debugPrint("❌ Notify 중지 실패: $e");
    }
  }

  /// 기기로 명령 전송
  Future<void> sendCommand(String command) async {
    if (_cmdCharacteristic == null || !_isDeviceReady) {
      debugPrint("❌ CMD 특성 없음 또는 기기 미연결");
      throw Exception("기기가 연결되어 있지 않습니다.");
    }

    try {
      await _cmdCharacteristic!.write(command.codeUnits, withoutResponse: false);
      debugPrint("📤 명령 전송 성공: $command");
    } catch (e) {
      debugPrint("❌ 명령 전송 실패 (전원 꺼짐 감지): $e");
      await disconnect();
      throw Exception("기기와 통신할 수 없습니다. 전원을 확인해 주세요.");
    }
  }

  /// 내부 연결 해제 상태 처리
  void _handleDisconnected() {
    final wasReady = _isDeviceReady;
    _pingTimer?.cancel();
    _isDeviceReady = false;
    _isConnecting  = false;
    _isScanning    = false;
    targetCharacteristic = null;
    _cmdCharacteristic   = null;
    if (wasReady) onDeviceReadyChanged?.call(false);
  }

  /// 연결 해제 및 리소스 정리
  Future<void> disconnect() async {
    try {
      _pingTimer?.cancel();
      _scanSubscription?.cancel();
      _connectionSubscription?.cancel();
      _notifySubscription?.cancel();
      _battNotifySubscription?.cancel();

      _scanSubscription       = null;
      _connectionSubscription = null;
      _notifySubscription     = null;
      _battNotifySubscription = null;

      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
        _connectedDevice = null;
      }

      _handleDisconnected();
      debugPrint("✅ 안전하게 연결 해제되었습니다.");
    } catch (e) {
      debugPrint("❌ 연결 해제 중 에러 발생: $e");
    }
  }

  void dispose() {
    disconnect();
  }
}