import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  // Service 및 Characteristic UUID 설정
  static const String SERVICE_UUID   = "12345678-1234-1234-1234-123456789012";
  static const String CHAR_UUID      = "87654321-4321-4321-4321-210987654321";
  static const String CMD_CHAR_UUID  = "11111111-1111-1111-1111-111111111111";
  static const String BATT_CHAR_UUID = "2a19"; // 16진수 소문자

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

  Timer? _pingTimer; // ★ 실시간 전원 상태 빠른 감시 타이머 ★

  bool _isConnecting = false;
  bool _isScanning   = false;

  /// BLE 서비스 초기화 및 기기 스캔 시작
  Future<void> init() async {
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

      FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
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
      debugPrint("❌ 기기 연결 실패: $e");
    }
  }

  /// 서비스 및 특성(Characteristic) 탐색
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

            // ★ 1초 주기 실시간 연결 상태 모니터링 시작 ★
            _startPingMonitor();
          }
        }
      }
    } catch (e) {
      _isConnecting = false;
      debugPrint("❌ 서비스 탐색 오류: $e");
    }
  }

  /// ★ 1초 간격으로 신호 상태를 체크하여 전원 끄짐을 초고속 감지 ★
  void _startPingMonitor() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_connectedDevice != null && _isDeviceReady) {
        try {
          await _connectedDevice!.readRssi();
        } catch (e) {
          debugPrint("⚡ 실시간 전원 꺼짐 감지! (1초 내 Ping 실패)");
          _pingTimer?.cancel();
          _handleDisconnected();
          disconnect();
        }
      } else {
        timer.cancel();
      }
    });
  }

  /// 데이터 수신(Notify) 시작
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

  /// 데이터 수신(Notify) 중지
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

      _handleDisconnected();
      disconnect();

      throw Exception("기기와 통신할 수 없습니다. 전원을 확인해 주세요.");
    }
  }

  /// 내부 연결 해제 상태 처리
  void _handleDisconnected() {
    _pingTimer?.cancel();
    _isDeviceReady = false;
    _isConnecting  = false;
    _isScanning    = false;
    targetCharacteristic = null;
    _cmdCharacteristic   = null;
    onDeviceReadyChanged?.call(false);
  }

  /// 블루투스 연결 해제 및 리소스 정리
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