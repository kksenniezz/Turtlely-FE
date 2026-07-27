import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class MonthlyBleService {
  final String targetDeviceName   = "Turtlely_XIAO";
  final Guid   serviceUuid        = Guid("19B10000-E8F2-537E-4F6C-D104768A1214");
  final Guid   characteristicUuid = Guid("19B10001-E8F2-537E-4F6C-D104768A1214");

  BluetoothDevice?         targetDevice;
  BluetoothCharacteristic? targetCharacteristic;
  bool isConnecting     = false;
  bool isDeviceReady    = false;
  bool _isDisconnecting = false;

  double accX = 0.0;
  double accY = 0.0;
  double accZ = 0.0;

  Function(bool)? onDeviceReadyChanged;
  Function(double, double, double)? onAccelUpdated;

  StreamSubscription<List<ScanResult>>?         _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>?                _valueSubscription;

  Future<void> init() async {
    try {
      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) return;
      await _startScan();
    } catch (e) {
      debugPrint("❌ 월간 BLE 초기화 실패: $e");
    }
  }

  // 추가!
  Future<void> sendCommand(String command) async {
    try {
      if (targetCharacteristic == null) {
        debugPrint("❌ 월간 BLE 전송 실패: characteristic null - $command");
        return;
      }
      await targetCharacteristic!.write(command.codeUnits);
      debugPrint("📤 월간 BLE 전송: $command");
    } catch (e) {
      debugPrint("❌ 월간 BLE 전송 실패: $e");
    }
  }

  Future<void> _startScan() async {
    if (targetDevice != null || isDeviceReady || isConnecting || _isDisconnecting) {
      debugPrint("⏳ 이미 연결되어 있으므로 스캔 패스");
      return;
    }

    try {
      debugPrint("🔍 월간 BLE 스캔 시작");
      await FlutterBluePlus.stopScan();
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));

      _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult result in results) {
          final device = result.device;
          final deviceName = device.platformName.isNotEmpty
              ? device.platformName
              : device.localName.isNotEmpty
                  ? device.localName
                  : result.advertisementData.localName;

          if (deviceName == targetDeviceName || deviceName.startsWith("Turtl")) {
            debugPrint("✅ 월간 BLE 타겟 발견! : $deviceName");
            await _connectToDevice(device);
            break;
          }
        }
      });
    } catch (e) {
      debugPrint("❌ 월간 BLE 스캔 실패: $e");
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    if (isConnecting || targetDevice != null) return;
    isConnecting = true;
    try {
      await FlutterBluePlus.stopScan();
      targetDevice = device;
      await device.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
        license: License.free,
      );
      debugPrint("✅ 월간 BLE 연결 성공");

      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          isDeviceReady        = false;
          targetCharacteristic = null;
          targetDevice         = null;
          onDeviceReadyChanged?.call(false);
          debugPrint("🔌 월간 BLE 연결 해제 - 재연결 시도");
          Future.delayed(const Duration(seconds: 2), () {
            if (!isDeviceReady && !_isDisconnecting) {
              _startScan();
            }
          });
        }
      });

      await _discoverServices(device);
    } catch (e) {
      debugPrint("❌ 월간 BLE 연결 실패: $e");
      targetDevice = null;
      isConnecting = false;
    } finally {
      isConnecting = false;
    }
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid == serviceUuid) {
          for (BluetoothCharacteristic c in service.characteristics) {
            if (c.uuid == characteristicUuid) {
              targetCharacteristic = c;
              isDeviceReady        = true;
              onDeviceReadyChanged?.call(true);
              debugPrint("✅ 월간 BLE CHARACTERISTIC READY");
              await _startNotify();
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("❌ 월간 BLE 서비스 탐색 실패: $e");
    }
  }

  Future<void> _startNotify() async {
    try {
      if (targetCharacteristic == null) return;
      if (!(await targetCharacteristic!.isNotifying)) {
        await targetCharacteristic!.setNotifyValue(true);
      }
      _valueSubscription?.cancel();
      _valueSubscription = targetCharacteristic!.lastValueStream.listen((value) {
        if (value.isEmpty) return;
        final data = utf8.decode(value).trim();
        debugPrint("📥 월간 BLE 실시간 센서 데이터: $data");
        if (data == "NO_POSE_CALIB") return;
        final parts = data.split(',');
        if (parts.length >= 3) {
          final x = double.tryParse(parts[0]);
          final y = double.tryParse(parts[1]);
          final z = double.tryParse(parts[2]);
          if (x != null && y != null && z != null) {
            accX = x;
            accY = y;
            accZ = z;
            onAccelUpdated?.call(accX, accY, accZ);
            debugPrint("📡 [데이터 반영] X: $accX, Y: $accY, Z: $accZ");
          }
        }
      });
    } catch (e) {
      debugPrint("❌ 월간 BLE Notify 실패: $e");
    }
  }

  void dispose() {
    _isDisconnecting = true;
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _valueSubscription?.cancel();
    targetDevice?.disconnect();
    debugPrint("🔌 월간 BLE dispose");
  }
}