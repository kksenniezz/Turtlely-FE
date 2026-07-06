import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  final String targetDeviceName   = "Turtlely_XIAO";
  final Guid   serviceUuid        = Guid("19B10000-E8F2-537E-4F6C-D104768A1214");
  final Guid   characteristicUuid = Guid("19B10001-E8F2-537E-4F6C-D104768A1214");

  BluetoothDevice?         targetDevice;
  BluetoothCharacteristic? targetCharacteristic;
  bool isConnecting     = false;
  bool isDeviceReady    = false;
  bool _isDisconnecting = false;

  StreamSubscription<List<ScanResult>>?         scanSubscription;
  StreamSubscription<BluetoothConnectionState>? connectionSubscription;
  StreamSubscription<List<int>>?                _valueSubscription;

  Function(bool)? onDeviceReadyChanged;

  Future<void> init() async {
    _isDisconnecting = false; // 재연결 허용!
    try {
      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) return;
      startDeviceScan();
    } catch (e) {
      debugPrint("❌ BLE 초기화 실패: $e");
    }
  }

  Future<void> startDeviceScan() async {
    try {
      debugPrint("🔍 BLE 스캔 시작");
      await FlutterBluePlus.stopScan();
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 30));

      scanSubscription?.cancel();
      scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult result in results) {
          final device = result.device;
          final deviceName = device.platformName.isNotEmpty
              ? device.platformName
              : device.localName.isNotEmpty
                  ? device.localName
                  : result.advertisementData.localName;

          debugPrint("📡 발견된 기기: '$deviceName' | RSSI: ${result.rssi}");

          if (deviceName == targetDeviceName || deviceName.startsWith("Turtl")) {
            debugPrint("✅ 타겟 기기 발견!");
            await connectToDevice(device);
            break;
          }
        }
      });
    } catch (e) {
      debugPrint("❌ 스캔 실패: $e");
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    if (isConnecting || targetDevice != null) return;
    isConnecting = true;
    try {
      await FlutterBluePlus.stopScan();
      targetDevice = device;
      await device.connect(timeout: const Duration(seconds: 10), license: License.free);
      debugPrint("✅ BLE 연결 성공");

      connectionSubscription?.cancel();
      connectionSubscription = device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.disconnected) {
          isDeviceReady        = false;
          targetCharacteristic = null;
          targetDevice         = null;
          onDeviceReadyChanged?.call(false);
          await reconnect();
        }
      });

      await discoverServices(device);
    } catch (e) {
      debugPrint("❌ 연결 실패: $e");
      targetDevice = null;
      isConnecting = false;
      await reconnect();
    } finally {
      isConnecting = false;
    }
  }

  Future<void> discoverServices(BluetoothDevice device) async {
    try {
      final services = await device.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid == serviceUuid) {
          for (BluetoothCharacteristic c in service.characteristics) {
            if (c.uuid == characteristicUuid) {
              targetCharacteristic = c;
              isDeviceReady        = true;
              onDeviceReadyChanged?.call(true);
              debugPrint("✅ CHARACTERISTIC READY");
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("❌ 서비스 탐색 실패: $e");
    }
  }

  Future<void> reconnect() async {
    if (_isDisconnecting) return; // 의도적 해제면 재연결 안 함!
    debugPrint("🔄 BLE 재연결 시도");
    await Future.delayed(const Duration(seconds: 2));
    startDeviceScan();
  }

  Future<void> sendCommand(String command) async {
    try {
      if (targetCharacteristic == null) {
        debugPrint("❌ 전송 실패: characteristic null - $command");
        return;
      }
      await targetCharacteristic!.write(command.codeUnits);
      debugPrint("📤 전송: $command");
    } catch (e) {
      debugPrint("❌ 전송 실패: $e");
    }
  }

  Future<void> startNotify(Function(String) onData) async {
    try {
      await _valueSubscription?.cancel();
      if (!(await targetCharacteristic!.isNotifying)) {
        await targetCharacteristic!.setNotifyValue(true);
      }
      _valueSubscription = targetCharacteristic!.lastValueStream.listen((value) {
        if (value.isEmpty) return;
        onData(String.fromCharCodes(value));
      });
    } catch (e) {
      debugPrint("❌ Notify 실패: $e");
    }
  }

  Future<void> stopNotify() async {
    try {
      await _valueSubscription?.cancel();
      _valueSubscription = null;
      if (targetCharacteristic != null && await targetCharacteristic!.isNotifying) {
        await targetCharacteristic!.setNotifyValue(false);
      }
    } catch (e) {
      debugPrint("❌ Notify 해제 실패: $e");
    }
  }

  Future<void> disconnect() async {
    try {
      _isDisconnecting = true; // 재연결 막기!
      scanSubscription?.cancel();
      connectionSubscription?.cancel();
      await FlutterBluePlus.stopScan();
      await targetDevice?.disconnect();
      targetDevice         = null;
      targetCharacteristic = null;
      isDeviceReady        = false;
      debugPrint("🔌 BLE 연결 해제 완료");
    } catch (e) {
      debugPrint("❌ BLE disconnect 실패: $e");
    }
    // finally에서 false로 안 돌림! init() 호출할 때 초기화됨
  }

  void dispose() {
    scanSubscription?.cancel();
    connectionSubscription?.cancel();
    disconnect();
  }
}