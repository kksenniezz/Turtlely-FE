import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleService {
  final String targetDeviceName   = "Turtlely_XIAO";
  final Guid   serviceUuid        = Guid("19B10000-E8F2-537E-4F6C-D104768A1214");
  final Guid   characteristicUuid = Guid("19B10001-E8F2-537E-4F6C-D104768A1214");

  BluetoothDevice?         targetDevice;
  BluetoothCharacteristic? targetCharacteristic;
  bool isConnecting  = false;
  bool isDeviceReady = false;

  StreamSubscription<List<ScanResult>>?         scanSubscription;
  StreamSubscription<BluetoothConnectionState>? connectionSubscription;

  // 연결 상태 변경 콜백
  Function(bool)? onDeviceReadyChanged;
  // 데이터 수신 콜백
  Function(String)? onDataReceived;

  Future<void> init() async {
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
        await reconnect(); // 연결 끊기면 재연결
      }
    });

    await discoverServices(device);
  } catch (e) {
    debugPrint("❌ 연결 실패: $e");
    targetDevice = null;
    isConnecting = false;
    await reconnect(); // 실패해도 재연결 추가!
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

  StreamSubscription<List<int>>? _valueSubscription;

  Future<void> startNotify(Function(String) onData) async {
    try {
      await _valueSubscription?.cancel(); // 기존 구독 취소!
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
    await _valueSubscription?.cancel(); // 추가!
    _valueSubscription = null;
    if (await targetCharacteristic!.isNotifying) {
      await targetCharacteristic!.setNotifyValue(false);
    }
  } catch (e) {
    debugPrint("❌ Notify 해제 실패: $e");
  }
}

  Future<void> disconnect() async {
    try {
      await targetDevice?.disconnect();
      debugPrint("🔌 BLE 연결 해제");
    } catch (e) {
      debugPrint("❌ BLE disconnect 실패: $e");
    }
  }

  void dispose() {
    scanSubscription?.cancel();
    connectionSubscription?.cancel();
    disconnect();
  }
}