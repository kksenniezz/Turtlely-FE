import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math' as math;
import 'dart:io';

class MediaPipeService {
  static String loginId = "";
  static int memberId = 1;
  final String baseUrl = "http://54.144.66.35.nip.io:8080";
  final storage = const FlutterSecureStorage();

  List<Map<String, dynamic>> coordinateBatch = [];

  double _hwAccelX = 0.0;
  double _hwAccelY = 0.0;
  double _hwAccelZ = 0.0;

  void updateHwAccel(double x, double y, double z) {
    _hwAccelX = x;
    _hwAccelY = y;
    _hwAccelZ = z;
  }

  // 0.0~1.0 범위로 클램프
  double _clamp(double value) => value.clamp(0.0, 1.0);

  bool isCapturing = false;
  int _frameCounter = 0;
  Offset? _lastEyePoint;
  bool _isProcessing = false;

  Map<String, dynamic>? _lastValidPose;

  double currentTiltAngleRad = 0.0;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  CameraController? cameraController;
  bool isInitialized = false;

  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );

  final StreamController<Map<String, dynamic>> _poseStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get poseStream => _poseStreamController.stream;

  String _generateTimestamp() {
    final now = DateTime.now();
    String pad(int value) => value.toString().padLeft(2, '0');
    return "${now.year}-${pad(now.month)}-${pad(now.day)} ${pad(now.hour)}:${pad(now.minute)}:${pad(now.second)}";
  }

  Future<void> initializeCamera() async {
    if (cameraController != null) {
      await cameraController!.dispose();
      cameraController = null;
    }

    try {
      _accelerometerSubscription = accelerometerEventStream().listen((
        AccelerometerEvent event,
      ) {
        currentTiltAngleRad = math.atan2(event.y, event.z) - (math.pi / 2);

        final rollAngleRad = math.atan2(event.x, event.y);
        if (rollAngleRad.abs() > 0.17) {
          //debugPrint("기기가 옆으로 기울었어요! 화면을 똑바로 세워주세요");
        }
      });

      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      cameraController = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await cameraController!.initialize();
      isInitialized = true;

      cameraController!.startImageStream((CameraImage image) async {
        // 카메라 꺼질 때 방어 코드
        if (cameraController == null || !cameraController!.value.isInitialized)
          return;

        double imgWidth = image.width.toDouble();
        double imgHeight = image.height.toDouble();

        if (isCapturing && _lastValidPose != null) {
          _addBatchFromCache(imgWidth, imgHeight);
        }

        if (_isProcessing || _frameCounter++ % 5 != 0) return;
        _isProcessing = true;

        try {
          final inputImage = _convertCameraImageToInputImage(image);
          if (inputImage != null) {
            final List<Pose> poses = await _poseDetector.processImage(
              inputImage,
            );

            for (Pose pose in poses) {
              final rightEye = pose.landmarks[PoseLandmarkType.rightEye];
              final rightEar = pose.landmarks[PoseLandmarkType.rightEar];
              final rightShoulder =
                  pose.landmarks[PoseLandmarkType.rightShoulder];

              if (rightEye != null &&
                  rightEar != null &&
                  rightShoulder != null) {
                _dispatchCoordinates(
                  eyeX: rightEye.x,
                  eyeY: rightEye.y,
                  earX: rightEar.x,
                  earY: rightEar.y,
                  c7X: rightShoulder.x,
                  c7Y: rightShoulder.y,
                  rawEyeX: rightEye.x / imgWidth,
                  rawEyeY: rightEye.y / imgHeight,
                  rawEarX: rightEar.x / imgWidth,
                  rawEarY: rightEar.y / imgHeight,
                  rawC7X: rightShoulder.x / imgWidth,
                  rawC7Y: rightShoulder.y / imgHeight,
                );
                _lastValidPose = {
                  'eye': rightEye,
                  'ear': rightEar,
                  'c7': rightShoulder,
                };
                debugPrint("✅ 포즈 감지 | 배치크기: ${coordinateBatch.length}");
              }
            }
          }
        } catch (e) {
          print("AI 추론 에러: $e");
        } finally {
          _isProcessing = false;
        }
      });
    } catch (e) {
      print("카메라 및 AI 엔진 초기화 에러: $e");
    }
  }

  void _addBatchFromCache(double imgWidth, double imgHeight) {
    double cosT = math.cos(-currentTiltAngleRad);
    double sinT = math.sin(-currentTiltAngleRad);
    final rawEye = _lastValidPose!['eye'];
    final rawEar = _lastValidPose!['ear'];
    final rawC7 = _lastValidPose!['c7'];

    double rawC7X = rawC7.x / imgWidth;
    double rawC7Y = rawC7.y / imgHeight;
    double dxEar = (rawEar.x / imgWidth) - rawC7X;
    double dyEar = (rawEar.y / imgHeight) - rawC7Y;
    double dxEye = (rawEye.x / imgWidth) - rawC7X;
    double dyEye = (rawEye.y / imgHeight) - rawC7Y;

    coordinateBatch.add({
      "c7_x": _clamp(rawC7X),
      "c7_y": _clamp(rawC7Y),
      "eye_x": _clamp(rawC7X + (dxEye * cosT - dyEye * sinT)),
      "eye_y": _clamp(rawC7Y + (dxEye * sinT + dyEye * cosT)),
      "tragus_x": _clamp(rawC7X + (dxEar * cosT - dyEar * sinT)),
      "tragus_y": _clamp(rawC7Y + (dxEar * sinT + dyEar * cosT)),
      "hw_accel_x": _hwAccelX,
      "hw_accel_y": _hwAccelY,
      "hw_accel_z": _hwAccelZ,
    });
  }

  void _dispatchCoordinates({
    required double eyeX,
    required double eyeY,
    required double earX,
    required double earY,
    required double c7X,
    required double c7Y,
    required double rawEyeX,
    required double rawEyeY,
    required double rawEarX,
    required double rawEarY,
    required double rawC7X,
    required double rawC7Y,
  }) {
    double filteredEyeX = eyeX;
    double filteredEyeY = eyeY;

    if (_lastEyePoint != null) {
      filteredEyeX = (_lastEyePoint!.dx + eyeX) / 2;
      filteredEyeY = (_lastEyePoint!.dy + eyeY) / 2;
    }

    _lastEyePoint = Offset(filteredEyeX, filteredEyeY);

    _poseStreamController.add({
      'eye': Offset(filteredEyeX, filteredEyeY),
      'ear': Offset(earX, earY),
      'c7': Offset(c7X, c7Y),
      'tilt': currentTiltAngleRad,
    });

    if (isCapturing) {
      _frameCounter++;
      if (_frameCounter % 2 == 0) {
        double cosT = math.cos(-currentTiltAngleRad);
        double sinT = math.sin(-currentTiltAngleRad);

        double dxEar = rawEarX - rawC7X;
        double dyEar = rawEarY - rawC7Y;
        double calibratedRawEarX = rawC7X + (dxEar * cosT - dyEar * sinT);
        double calibratedRawEarY = rawC7Y + (dxEar * sinT + dyEar * cosT);

        double dxEye = rawEyeX - rawC7X;
        double dyEye = rawEyeY - rawC7Y;
        double calibratedRawEyeX = rawC7X + (dxEye * cosT - dyEye * sinT);
        double calibratedRawEyeY = rawC7Y + (dxEye * sinT + dyEye * cosT);

        coordinateBatch.add({
          "c7_x": _clamp(rawC7X),
          "c7_y": _clamp(rawC7Y),
          "eye_x": _clamp(calibratedRawEyeX),
          "eye_y": _clamp(calibratedRawEyeY),
          "tragus_x": _clamp(calibratedRawEarX),
          "tragus_y": _clamp(calibratedRawEarY),
          "hw_accel_x": _hwAccelX,
          "hw_accel_y": _hwAccelY,
          "hw_accel_z": _hwAccelZ,
        });
      }
    }
  }

  void start3SecondCapture() {
    coordinateBatch.clear();
    _lastEyePoint = null;
    _frameCounter = 0;
    isCapturing = true;
    print("3초 데이터 수집 파이프라인 가동 개시");
  }

  Future<Map<String, dynamic>> sendBatchVisionData() async {
    isCapturing = false;

    final List<Map<String, dynamic>> batchCopy = List.from(coordinateBatch);
    coordinateBatch.clear();

    debugPrint("📦 [전송 시작] 복사된 프레임 개수: ${batchCopy.length}");

    if (batchCopy.isEmpty) {
      return {"success": false, "message": "측정된 데이터가 없습니다."};
    }

    // 🚨 백엔드가 요청한 그대로! 왼쪽 Key 값을 언더바(_) 형태로 정확히 매핑합니다.
    final List<Map<String, dynamic>> requestPayload = batchCopy.map((frame) {
      double parseSafely(dynamic val) {
        if (val == null) return 0.0;
        final parsed = double.tryParse(val.toString()) ?? 0.0;
        // 백엔드가 준 예시처럼 소수점 아래 자리를 0.00~1.00 사이로 안전하게 clamp 고정
        return double.parse(parsed.clamp(0.0, 1.0).toStringAsFixed(4));
      }

      return {
        "eye_x": parseSafely(frame["eye_x"]),
        "eye_y": parseSafely(frame["eye_y"]),
        "tragus_x": parseSafely(frame["tragus_x"]),
        "tragus_y": parseSafely(frame["tragus_y"]),
        "c7_x": parseSafely(frame["c7_x"]),
        "c7_y": parseSafely(frame["c7_y"]),
        "hw_accel_x": double.parse((_hwAccelX).toStringAsFixed(4)),
        "hw_accel_y": double.parse((_hwAccelY).toStringAsFixed(4)),
        "hw_accel_z": double.parse((_hwAccelZ).toStringAsFixed(4)),
      };
    }).toList();

    // "frames" 라는 Key로 감싸서 JSON 객체 생성
    final Map<String, dynamic> wrappedPayload = {"frames": requestPayload};

    debugPrint(
      "📤 [백엔드 맞춤 요청 바디 샘플]: ${jsonEncode({"frames": requestPayload.take(1).toList()})}",
    );

    try {
      final response = await _postRequest(
        "/api/monthly/measurements",
        wrappedPayload,
      );
      debugPrint("🚀 [서버 최종 응답]: $response");
      return response;
    } catch (e) {
      debugPrint("❌ [전송 예외 발생]: $e");
      return {"success": false, "message": "네트워크 에러가 발생했습니다."};
    }
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    try {
      if (image.planes.isEmpty || image.planes[0].bytes.isEmpty) return null;
      final sensorOrientation = cameraController!.description.sensorOrientation;

      InputImageRotation rotation =
          InputImageRotationValue.fromRawValue(sensorOrientation) ??
          InputImageRotation.rotation0deg;

      if (Platform.isAndroid) {
        final metadata = InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.planes[0].bytesPerRow,
        );

        final WriteBuffer allBytes = WriteBuffer();
        for (final Plane plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        final bytes = allBytes.done().buffer.asUint8List();

        return InputImage.fromBytes(bytes: bytes, metadata: metadata);
      } else if (Platform.isIOS) {
        final imageFormat =
            InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.bgra8888;

        final metadata = InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: imageFormat,
          bytesPerRow: image.planes[0].bytesPerRow,
        );

        return InputImage.fromBytes(
          bytes: image.planes[0].bytes,
          metadata: metadata,
        );
      }
      return null;
    } catch (e) {
      print("이미지 변환 에러: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>> _postRequest(String path, dynamic body) async {
    final url = Uri.parse('$baseUrl$path');
    final accessToken = await storage.read(key: 'accessToken');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(body),
      );
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      print("응답: $data");
      return {
        "success": data["isSuccess"] ?? false,
        "statusCode": response.statusCode,
        "code": data['code'],
        "message": data['message'],
        "result": data["result"],
      };
    } catch (e) {
      return {"success": false, "message": "네트워크 연결을 확인해주세요."};
    }
  }

  void dispose() {
    _accelerometerSubscription?.cancel();
    _poseDetector.close();
    _poseStreamController.close();
    cameraController?.dispose();
    cameraController = null;
  }
}
