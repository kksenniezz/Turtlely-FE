import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class MonthlyBleService {
  final String targetDeviceName = "Turtlely_XIAO";

  // ✅ 펌웨어(.ino)와 반드시 일치해야 하는 UUID들
  final Guid serviceUuid = Guid("12345678-1234-1234-1234-123456789012");
  final Guid cvaCharacteristicUuid =
      Guid("87654321-4321-4321-4321-210987654321"); // notify (센서 데이터 수신)
  final Guid cmdCharacteristicUuid =
      Guid("11111111-1111-1111-1111-111111111111"); // write (명령 전송)
  final Guid battCharacteristicUuid = Guid("2A19"); // 표준 Battery Level

  BluetoothDevice? targetDevice;

  // ✅ notify용 / write용 characteristic을 각각 따로 보관
  BluetoothCharacteristic? _cvaCharacteristic;
  BluetoothCharacteristic? _cmdCharacteristic;
  BluetoothCharacteristic? _battCharacteristic;

  bool isConnecting = false;
  bool isDeviceReady = false;
  bool _isDisconnecting = false;

  double accX = 0.0;
  double accY = 0.0;
  double accZ = 0.0;

  Function(bool)? onDeviceReadyChanged;
  Function(double, double, double)? onAccelUpdated;
  Function(int)? onBatteryUpdated;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _valueSubscription;
  StreamSubscription<List<int>>? _battSubscription;

  Future<void> init() async {
    try {
      final state = await FlutterBluePlus.adapterState.first;
      if (state != BluetoothAdapterState.on) return;
      await _startScan();
    } catch (e) {
      debugPrint("❌ 월간 BLE 초기화 실패: $e");
    }
  }

  // ✅ 명령은 반드시 cmdCharacteristic으로만 전송
  Future<void> sendCommand(String command) async {
    try {
      if (_cmdCharacteristic == null) {
        debugPrint("❌ 월간 BLE 전송 실패: cmdCharacteristic null - $command");
        return;
      }
      await _cmdCharacteristic!.write(command.codeUnits);
      debugPrint("📤 월간 BLE 전송: $command");
    } catch (e) {
      debugPrint("❌ 월간 BLE 전송 실패: $e");
    }
  }

  Future<void> _startScan() async {
    if (targetDevice != null ||
        isDeviceReady ||
        isConnecting ||
        _isDisconnecting) {
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

          if (deviceName == targetDeviceName ||
              deviceName.startsWith("Turtl")) {
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
          isDeviceReady = false;
          _cvaCharacteristic = null;
          _cmdCharacteristic = null;
          _battCharacteristic = null;
          targetDevice = null;
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
            if (c.uuid == cvaCharacteristicUuid) {
              _cvaCharacteristic = c;
              debugPrint("✅ CVA(notify) characteristic 발견");
            } else if (c.uuid == cmdCharacteristicUuid) {
              _cmdCharacteristic = c;
              debugPrint("✅ CMD(write) characteristic 발견");
            }
          }
        }
        // 배터리는 표준 서비스(180F)에 별도로 존재할 수 있음
        for (BluetoothCharacteristic c in service.characteristics) {
          if (c.uuid == battCharacteristicUuid) {
            _battCharacteristic = c;
            debugPrint("✅ BATT(notify) characteristic 발견");
          }
        }
      }

      // ✅ 필수 characteristic(cva, cmd) 둘 다 찾았을 때만 ready
      if (_cvaCharacteristic != null && _cmdCharacteristic != null) {
        isDeviceReady = true;
        onDeviceReadyChanged?.call(true);
        debugPrint("✅ 월간 BLE DEVICE READY");
        await _startNotify();
        await _startBattNotify();
      } else {
        debugPrint(
          "❌ 필수 characteristic 못 찾음 (cva:${_cvaCharacteristic != null}, cmd:${_cmdCharacteristic != null})",
        );
      }
    } catch (e) {
      debugPrint("❌ 월간 BLE 서비스 탐색 실패: $e");
    }
  }

  Future<void> _startNotify() async {
    try {
      if (_cvaCharacteristic == null) return;
      if (!(await _cvaCharacteristic!.isNotifying)) {
        await _cvaCharacteristic!.setNotifyValue(true);
      }
      _valueSubscription?.cancel();
      _valueSubscription = _cvaCharacteristic!.lastValueStream.listen((value) {
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

  Future<void> _startBattNotify() async {
    try {
      if (_battCharacteristic == null) return;
      if (!(await _battCharacteristic!.isNotifying)) {
        await _battCharacteristic!.setNotifyValue(true);
      }
      _battSubscription?.cancel();
      _battSubscription = _battCharacteristic!.lastValueStream.listen((value) {
        if (value.isEmpty) return;
        final percent = value.first; // BLEUnsignedCharCharacteristic 1바이트
        onBatteryUpdated?.call(percent);
        debugPrint("🔋 월간 배터리: $percent%");
      });
    } catch (e) {
      debugPrint("❌ 월간 BLE 배터리 Notify 실패: $e");
    }
  }

  void dispose() {
    _isDisconnecting = true;
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _valueSubscription?.cancel();
    _battSubscription?.cancel();
    targetDevice?.disconnect();
    debugPrint("🔌 월간 BLE dispose");
  }
}