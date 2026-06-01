import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:js' as js;

class MediaPipeService {
  static int memberId = 1;
  final String baseUrl = "http://54.144.66.35.nip.io:8000";
  final storage = const FlutterSecureStorage();
  // 임시적으로 3초간 측정한 좌표를 담는 바구니 (초당 10-15프레임 가정 -> 30-45개 좌표)
  List<Map<String, dynamic>> coordinateBatch = [];

  bool isCapturing = false;
  int _frameCounter = 0;
  Offset? _lastEyePoint;

  CameraController? cameraController;
  bool isInitialized = false;

  // 모바일용 MLKit 포즈 엔진
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );

  final StreamController<Map<String, Offset>> _poseStreamController =
      StreamController<Map<String, Offset>>.broadcast();
  Stream<Map<String, Offset>> get poseStream => _poseStreamController.stream;

  // 📸 카메라 초기화 및 실시간 프레임 리슨 시작
  String _generateTimestamp() {
    final now = DateTime.now();
    String maroon(int value) => value.toString().padLeft(2, '0');
    return "${now.year}-${maroon(now.month)}-${maroon(now.day)} ${maroon(now.hour)}:${maroon(now.minute)}:${maroon(now.second)}";
  }

  Future<void> initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888, // 앱/웹 공통 처리용 포맷
      );

      await cameraController!.initialize();
      isInitialized = true;

      if (kIsWeb) {
        // 🌐 [웹 브라우저 환경 실행]
        Timer(const Duration(milliseconds: 500), () {
          js.context.callMethod('startWebMediaPipe');
        });

        // 자바스크립트(index.html)가 꺼내온 오른쪽 좌표 리시버 등록
        js.context['onWebPoseDetected'] = (String jsonPayload) {
          final data = jsonDecode(jsonPayload);

          // 웹 미디어파이프 기본 스케일 보정 (화면 가이드라인 테두리 안쪽으로 안착)
          double xRatio = 360.0;
          double yRatio = 480.0;

          _dispatchCoordinates(
            eyeX: (data['eyeX'] ?? 0.5) * xRatio,
            eyeY: (data['eyeY'] ?? 0.3) * yRatio,
            earX: (data['earX'] ?? 0.5) * xRatio,
            earY: (data['earY'] ?? 0.4) * yRatio,
            c7X: (data['c7X'] ?? 0.5) * xRatio,
            c7Y: (data['c7Y'] ?? 0.6) * yRatio,
            rawEyeX: data['eyeX'] ?? 0.5,
            rawEyeY: data['eyeY'] ?? 0.3,
            rawEarX: data['earX'] ?? 0.5,
            rawEarY: data['earY'] ?? 0.4,
            rawC7X: data['c7X'] ?? 0.5,
            rawC7Y: data['c7Y'] ?? 0.6,
          );
        };
      } else {
        // 스마트폰 모바일 앱 환경 실행
        cameraController!.startImageStream((CameraImage image) async {
          final inputImage = _convertCameraImageToInputImage(image);
          if (inputImage == null) return;

          final List<Pose> poses = await _poseDetector.processImage(inputImage);
          double scaleX = 0.5;
          double scaleY = 0.5;
          double imgWidth = image.width.toDouble();
          double imgHeight = image.height.toDouble();

          for (Pose pose in poses) {
            final rightEye = pose.landmarks[PoseLandmarkType.rightEye];
            final rightEar = pose.landmarks[PoseLandmarkType.rightEar];
            final rightShoulder =
                pose.landmarks[PoseLandmarkType.rightShoulder];

            if (rightEye != null && rightEar != null && rightShoulder != null) {
              // 🎯 중요: 모바일 앱 픽셀 기반 좌표를 해상도로 나누어 0.0 ~ 1.0 비율로 실시간 정규화 처리!
              _dispatchCoordinates(
                eyeX: rightEye.x * scaleX,
                eyeY: rightEye.y * scaleY,
                earX: rightEar.x * scaleX,
                earY: rightEar.y * scaleY,
                c7X: rightShoulder.x * scaleX,
                c7Y: rightShoulder.y * scaleY,
                rawEyeX: rightEye.x / imgWidth,
                rawEyeY: rightEye.y / imgHeight,
                rawEarX: rightEar.x / imgWidth,
                rawEarY: rightEar.y / imgHeight,
                rawC7X: rightShoulder.x / imgWidth,
                rawC7Y: rightShoulder.y / imgHeight,
              );
            }
          }
        });
      }
    } catch (e) {
      print("카메라 및 AI 엔진 초기화 에러: $e");
    }
  }

  // 🔄 좌표 스트림 전송 및 바구니 적재 공통화 함수 (정규화 인자 분리 설계)
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

    // 🎯 vision.dart UI단에 쫀득하게 그릴 반응형 픽셀 좌표 전달
    _poseStreamController.add({
      'eye': Offset(filteredEyeX, filteredEyeY),
      'ear': Offset(earX, earY),
      'c7': Offset(c7X, c7Y),
    });

    // ⏳ 3초 타이머 활성화됐을 때만 바구니에 차곡차곡 적재
    if (isCapturing) {
      _frameCounter++;
      if (_frameCounter % 2 == 0) {
        // 백엔드 전송용 바구니에는 웹/앱 구별 없이 완벽하게 정규화된 0.0 ~ 1.0 값만 저장!
        coordinateBatch.add({
          "c7_x": rawC7X,
          "c7_y": rawC7Y,
          "eye_x": rawEyeX,
          "eye_y": rawEyeY,
          "tragus_x": rawEarX,
          "tragus_y": rawEarY,
          "timestamp": _generateTimestamp(),
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

  // [연동의 정수] vision.dart 한 줄도 안 고치고 이메일 연동 완료하는 마법 구역
  Future<bool> sendBatchVisionData() async {
    isCapturing = false;

    if (coordinateBatch.isEmpty) return false;

    int activeMemberId = 1;

    try {
      final accessToken = await storage.read(key: 'accessToken');
      if (accessToken != null &&
          accessToken.isNotEmpty &&
          accessToken != "null") {
        final normalizedPayload = utf8.decode(
          base64Url.decode(base64Url.normalize(accessToken.split('.')[1])),
        );
        final Map<String, dynamic> payloadMap = jsonDecode(normalizedPayload);

        // [토큰 디코딩 보안 분석 기법] 토큰 배를 갈라 숫자 member_id 원천 추출
        if (payloadMap['member_id'] != null) {
          activeMemberId = int.parse(payloadMap['member_id'].toString());
          MediaPipeService.memberId = activeMemberId; // 전역 스태틱 공간 공유 백업
        }
      }
    } catch (e) {
      print("비전 데이터 송신 전 member_id 토큰 파싱 에러 (기본값 처리): $e");
    }

    final Map<String, dynamic> requestPayload = {
      "frames": coordinateBatch.map((frame) {
        return {
          "c7_x": double.parse(
            double.parse(frame["c7_x"].toString()).toStringAsFixed(2),
          ),
          "c7_y": double.parse(
            double.parse(frame["c7_y"].toString()).toStringAsFixed(2),
          ),
          "eye_x": double.parse(
            double.parse(frame["eye_x"].toString()).toStringAsFixed(2),
          ),
          "eye_y": double.parse(
            double.parse(frame["eye_y"].toString()).toStringAsFixed(2),
          ),
          "tragus_x": double.parse(
            double.parse(frame["tragus_x"].toString()).toStringAsFixed(2),
          ),
          "tragus_y": double.parse(
            double.parse(frame["tragus_y"].toString()).toStringAsFixed(2),
          ),
          "timestamp": frame["timestamp"], // 타임스탬프 데이터 결합
        };
      }).toList(),
      "member_id": activeMemberId,
    };

    print("터틀리 백엔드 POST /report/analyze 최종 바디: ${jsonEncode(requestPayload)}");
    final response = await _postRequest("/report/analyze", requestPayload);

    if (response['success'] == true && response['result'] != null) {
      try {
        final resData = response['result']['data'] ?? response['result'];
        print(
          "🎯 [분석 성공 완벽 동기화] 생성된 리포트 ID: ${resData['report_id']}, 측정시간: ${resData['measured_at']}",
        );
      } catch (e) {
        print("응답 바디 로그 출력 도중 미세 파싱 에러 방어: $e");
      }
    }
    return response['success'] == true;
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();
      final imageRotation = InputImageRotation.rotation0deg;
      final inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;

      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      );
      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      print("MLKit 바이트 변환 에러: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>> _postRequest(String path, dynamic body) async {
    final url = Uri.parse('$baseUrl$path');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return {
        "success": (response.statusCode == 200),
        "message": data['message'] ?? "에러가 발생했습니다.",
        "result": data['result'],
      };
    } catch (e) {
      return {"success": false, "message": "네트워크 연결을 확인해주세요."};
    }
  }

  void dispose() {
    cameraController?.dispose();
    _poseDetector.close();
    _poseStreamController.close();
  }
}
