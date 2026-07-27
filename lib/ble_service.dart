import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  static const String SERVICE_UUID   = "12345678-1234-1234-1234-123456789012";
  static const String CHAR_UUID      = "87654321-4321-4321-4321-210987654321";
  static const String CMD_CHAR_UUID  = "11111111-1111-1111-1111-111111111111";
  static const String BATT_CHAR_UUID = "2A19"; // ✅ 배터리

  BluetoothDevice?         _connectedDevice;
  BluetoothCharacteristic? targetCharacteristic;
  BluetoothCharacteristic? _cmdCharacteristic;

  bool _isDeviceReady = false;
  bool get isDeviceReady => _isDeviceReady;

  Function(bool)? onDeviceReadyChanged;
  Function(int)?  onBatteryChanged; // ✅ 배터리 콜백

  StreamSubscription<List<ScanResult>>?         _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>?                _notifySubscription;
  StreamSubscription<List<int>>?                _battNotifySubscription; // ✅ 배터리

  bool _isConnecting = false;
  bool _isScanning   = false;

  Future<void> init() async {
    if (_isConnecting || _isScanning) {
      debugPrint("이미 스캔/연결 중");
      return;
    }

    try {
      _isScanning = true;
      debugPrint("🔵 BLE 스캔 시작");

      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          if (r.device.platformName == "Turtlely_XIAO" && !_isConnecting) {
            _isConnecting = true;
            await FlutterBluePlus.stopScan();
            _isScanning = false;
            await _connectToDevice(r.device);
            break;
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
      _isScanning = false;
    } catch (e) {
      _isScanning   = false;
      _isConnecting = false;
      debugPrint("❌ BLE 스캔 오류: $e");
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect(license: License.free);
      _connectedDevice = device;
      debugPrint("✅ 기기 연결됨: ${device.platformName}");

      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.disconnected) {
          _isDeviceReady = false;
          _isConnecting  = false;
          targetCharacteristic = null;
          _cmdCharacteristic   = null;
          onDeviceReadyChanged?.call(false);
          debugPrint("❌ 기기 연결 끊김");
          await Future.delayed(const Duration(seconds: 2));
          await init();
        }
      });

      await _discoverServices(device);
    } catch (e) {
      _isConnecting = false;
      debugPrint("❌ 연결 실패: $e");
      await Future.delayed(const Duration(seconds: 3));
      await init();
    }
  }

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

            // ✅ 배터리 특성 (_battCharacteristic 변수 없이 로컬로 처리)
            if (uuid == BATT_CHAR_UUID.toLowerCase()) {
              try {
                await c.setNotifyValue(true);
                _battNotifySubscription?.cancel();
                _battNotifySubscription = c.value.listen((value) {
                  if (value.isNotEmpty) {
                    final battPercent = value[0];
                    debugPrint("🔋 배터리: $battPercent%");
                    onBatteryChanged?.call(battPercent);
                  }
                });
                debugPrint("✅ 배터리 특성 발견");
              } catch (e) {
                debugPrint("❌ 배터리 Notify 실패: $e");
              }
            }
          }

          if (targetCharacteristic != null && _cmdCharacteristic != null) {
            _isDeviceReady = true;
            _isConnecting  = false;
            onDeviceReadyChanged?.call(true);
            debugPrint("✅ 기기 준비 완료");
          }
        }
      }
    } catch (e) {
      _isConnecting = false;
      debugPrint("❌ 서비스 탐색 실패: $e");
    }
  }

  Future<void> startNotify(Function(String) onData) async {
    if (targetCharacteristic == null) {
      debugPrint("❌ CVA 특성 없음");
      return;
    }
    try {
      _notifySubscription?.cancel();
      await targetCharacteristic!.setNotifyValue(true);
      _notifySubscription = targetCharacteristic!.value.listen((value) {
        if (value.isNotEmpty) {
          final str = String.fromCharCodes(value);
          onData(str);
        }
      });
      debugPrint("✅ Notify 시작");
    } catch (e) {
      debugPrint("❌ Notify 시작 실패: $e");
    }
  }

  Future<void> stopNotify() async {
    if (targetCharacteristic == null) return;
    try {
      _notifySubscription?.cancel();
      _notifySubscription = null;
      await targetCharacteristic!.setNotifyValue(false);
      debugPrint("✅ Notify 중지");
    } catch (e) {
      debugPrint("❌ Notify 중지 실패: $e");
    }
  }

  Future<void> sendCommand(String command) async {
    if (_cmdCharacteristic == null) {
      debugPrint("❌ CMD 특성 없음");
      return;
    }
    try {
      await _cmdCharacteristic!.write(command.codeUnits, withoutResponse: false);
      debugPrint("📤 명령 전송: $command");
    } catch (e) {
      debugPrint("❌ 명령 전송 실패: $e");
    }
  }

  Future<void> disconnect() async {
    try {
      _scanSubscription?.cancel();
      _connectionSubscription?.cancel();
      _notifySubscription?.cancel();
      _battNotifySubscription?.cancel(); // ✅ 배터리 notify 취소
      _scanSubscription       = null;
      _connectionSubscription = null;
      _notifySubscription     = null;
      _battNotifySubscription = null;

      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
        _connectedDevice = null;
      }

      _isDeviceReady       = false;
      _isConnecting        = false;
      _isScanning          = false;
      targetCharacteristic = null;
      _cmdCharacteristic   = null;
      onDeviceReadyChanged?.call(false);
      debugPrint("✅ 기기 연결 해제 완료");
    } catch (e) {
      debugPrint("❌ 연결 해제 실패: $e");
    }
  }

  void dispose() {
    disconnect();
  }
}