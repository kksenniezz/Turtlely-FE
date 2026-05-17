import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:js' as js;

class MediaPipeService {
  // 1. 서버 주소랑 좌표 바구니 선언
  final String baseUrl = "http://54.144.66.35.nip.io:8080";
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

          // 💡 변수명 깔끔하게 통일하여 디스패치 호출
          _dispatchCoordinates(
            (data['eyeX'] ?? 0.5) * xRatio,
            (data['eyeY'] ?? 0.3) * yRatio,
            (data['earX'] ?? 0.5) * xRatio,
            (data['earY'] ?? 0.4) * yRatio,
            (data['c7X'] ?? 0.5) * xRatio,
            (data['c7Y'] ?? 0.6) * yRatio,
          );
        };
      } else {
        // 📱 [스마트폰 모바일 앱 환경 실행]
        cameraController!.startImageStream((CameraImage image) async {
          final inputImage = _convertCameraImageToInputImage(image);
          if (inputImage == null) return;

          final List<Pose> poses = await _poseDetector.processImage(inputImage);

          // 💡 모바일 화면 픽셀 매핑을 위한 스마트폰 해상도 스케일 보정값
          double scaleX = 0.5;
          double scaleY = 0.5;

          for (Pose pose in poses) {
            // 💡 [수정] 왼쪽으로 고개 돌렸을 때 렌즈에 찍히는 오른쪽(Right) 부위만 추적!
            final rightEye = pose.landmarks[PoseLandmarkType.rightEye];
            final rightEar = pose.landmarks[PoseLandmarkType.rightEar];
            final rightShoulder =
                pose.landmarks[PoseLandmarkType.rightShoulder]; // C7 대용

            if (rightEye != null && rightEar != null && rightShoulder != null) {
              _dispatchCoordinates(
                rightEye.x * scaleX,
                rightEye.y * scaleY,
                rightEar.x * scaleX,
                rightEar.y * scaleY,
                rightShoulder.x * scaleX,
                rightShoulder.y * scaleY,
              );
            }
          }
        });
      }
    } catch (e) {
      print("카메라 및 AI 엔진 초기화 에러: $e");
    }
  }

  // 🔄 좌표 스트림 전송 및 바구니 적재 공통화 함수
  void _dispatchCoordinates(
    double eyeX,
    double eyeY,
    double earX,
    double earY,
    double c7X,
    double c7Y,
  ) {
    // 💡 미세 떨림 방어용 실시간 노이즈 필터링 (직전 좌표와 스무딩 평균 처리)
    double filteredEyeX = eyeX;
    double filteredEyeY = eyeY;

    if (_lastEyePoint != null) {
      filteredEyeX = (_lastEyePoint!.dx + eyeX) / 2;
      filteredEyeY = (_lastEyePoint!.dy + eyeY) / 2;
    }

    _lastEyePoint = Offset(filteredEyeX, filteredEyeY);

    // 🎯 vision.dart의 CustomPainter로 쫀득하게 정제된 픽셀 좌표 전달
    _poseStreamController.add({
      'eye': Offset(filteredEyeX, filteredEyeY),
      'ear': Offset(earX, earY),
      'c7': Offset(c7X, c7Y),
    });

    // ⏳ [수정] 3초 타이머 촬영 트리거가 활성화되었을 때만 솎아내어 적재 시작!
    if (isCapturing) {
      _frameCounter++;

      // 실시간 프레임 스트림 중 6프레임당 1개씩 솎아냅니다. (3초간 총 15개 안팎 수집)
      if (_frameCounter % 2 == 0) {
        coordinateBatch.add({
          "frame_index": _frameCounter,
          "timestamp": DateTime.now().millisecondsSinceEpoch,
          "eyeX": filteredEyeX,
          "eyeY": filteredEyeY,
          "earX": earX,
          "earY": earY,
          "c7X": c7X,
          "c7Y": c7Y,
        });
      }
    }
  }

  // ⏱️ [추가] 3초 카운트다운과 연동하여 데이터 수집을 제어하는 외부 트리거 함수
  void start3SecondCapture() {
    coordinateBatch.clear(); // 이전 측정 쓰레기 데이터 청소
    _lastEyePoint = null;
    _frameCounter = 0; // 카운터 초기화
    isCapturing = true; // 3초간 적재 락 해제!
    print("🎬 [터틀리] 3초 데이터 수집 파이프라인 가동 개시");
  }

  // 🚀 [대체 개편] 3초간 이쁘게 솎아 모은 10~15개의 프레임 배열을 백엔드에 한방에 전송!
  Future<bool> sendBatchVisionData() async {
    // 유저가 움직여서 수집 플래그가 여전히 켜져 있다면 안전하게 꺼줍니다.
    isCapturing = false;

    if (coordinateBatch.isEmpty) {
      print("❌ [터틀리 전송 실패] 수집된 데이터 프레임이 아예 없습니다.");
      return false;
    }

    print("📤 [터틀리 전송 시도] 총 ${coordinateBatch.length}개의 정제된 프레임 리스트를 쏩니다.");

    // 백엔드 아키텍처에 맞춰 프레임 리스트 통째로 묶어 전송 구우러 가기 🍖
    final response = await _postRequest("/api/vision/measurement", {
      "frames": coordinateBatch,
    });

    return response['success'] == true;
  }

  // 최신 Google ML Kit 규격에 맞춘 모바일 카메라 바이트 이미지 변환 함수
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
        "success": (response.statusCode == 200 && data['isSuccess'] == true),
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
