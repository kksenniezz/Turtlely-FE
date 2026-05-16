import 'dart:async';
import 'dart:convert';
import 'dart:math';
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
  List<Map<String, double>> coordinateBatch = [];

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
        // index.html에 정의해둔 자바스크립트 함수 호출하여 웹 비디오 바인딩
        Timer(const Duration(milliseconds: 500), () {
          js.context.callMethod('startWebMediaPipe');
        });

        // 자바스크립트가 꺼내온 좌표 리시버 등록
        js.context['onWebPoseDetected'] = (String jsonPayload) {
          final data = jsonDecode(jsonPayload);
          // 웹 미디어파이프의 해상도 비율 보정 (기본 0~1 사이 소수점이므로 화면 크기에 맞춤)
          double xRatio = 400.0;
          double yRatio = 300.0;

          _dispatchCoordinates(
            data['eyeX'] * xRatio,
            data['eyeY'] * yRatio,
            data['earX'] * xRatio,
            data['earY'] * yRatio,
            data['c7X'] * xRatio,
            data['c7Y'] * yRatio,
          );
        };
      } else {
        // 📱 [스마트폰 모바일 앱 환경 실행]
        cameraController!.startImageStream((CameraImage image) async {
          final inputImage = _convertCameraImageToInputImage(image);
          if (inputImage == null) return;

          final List<Pose> poses = await _poseDetector.processImage(inputImage);

          for (Pose pose in poses) {
            final leftEye = pose.landmarks[PoseLandmarkType.leftEye];
            final leftEar = pose.landmarks[PoseLandmarkType.leftEar];
            final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];

            if (leftEye != null && leftEar != null && leftShoulder != null) {
              _dispatchCoordinates(
                leftEye.x,
                leftEye.y,
                leftEar.x,
                leftEar.y,
                leftShoulder.x,
                leftShoulder.y,
              );
            }
          }
        });
      }
    } catch (e) {
      print("카메라 및 AI 엔진 초기화 에러: $e");
    }
  }

  // 좌표 스트림 전송 및 바구니 적재 공통화 함수
  void _dispatchCoordinates(
    double eyeX,
    double eyeY,
    double earX,
    double earY,
    double c7X,
    double c7Y,
  ) {
    _poseStreamController.add({
      'eye': Offset(eyeX, eyeY),
      'ear': Offset(earX, earY),
      'c7': Offset(c7X, c7Y),
    });

    // 3초 카운트다운 동안 임시 바구니에 로우 데이터 축적 (초당 15프레임 타깃, 최대 45개 내외)
    if (coordinateBatch.length < 50) {
      coordinateBatch.add({
        "eyeX": eyeX,
        "eyeY": eyeY,
        "earX": earX,
        "earY": earY,
        "c7X": c7X,
        "c7Y": c7Y,
      });
    }
  }

  // 🛠️ 알고리즘: 3초간 쌓인 수십 개 좌표 중 '가장 미세 움직임이 적고 안정적인 프레임 딱 1개' 정산 추출
  Map<String, double> _calculateOptimalFrameWithMedian() {
    if (coordinateBatch.isEmpty) return {};

    // 1. 바구니에서 eyeX, eyeY 리스트 추출
    List<double> eyeXList = coordinateBatch.map((f) => f['eyeX']!).toList();
    List<double> eyeYList = coordinateBatch.map((f) => f['eyeY']!).toList();

    // 2. 정렬
    eyeXList.sort();
    eyeYList.sort();

    // 3. 정확히 가운데 위치한 '중앙값(Median)' 획득
    int medianIndex = eyeXList.length ~/ 2;
    double medianEyeX = eyeXList[medianIndex];
    double medianEyeY = eyeYList[medianIndex];

    // 4. 이 중앙값과 가장 가까운 안정적인 프레임 1개 매칭
    Map<String, double> optimalFrame = coordinateBatch.first;
    double minDistance = double.maxFinite;

    for (var frame in coordinateBatch) {
      double distance = sqrt(
        pow(frame['eyeX']! - medianEyeX, 2) +
            pow(frame['eyeY']! - medianEyeY, 2),
      );
      if (distance < minDistance) {
        minDistance = distance;
        optimalFrame = frame;
      }
    }

    // 5. 최종 전송용 데이터 정산 (Key 명칭도 깔끔하게 통일)
    return {
      "eyeX": medianEyeX,
      "eyeY": medianEyeY,
      "earX": optimalFrame['earX']!,
      "earY": optimalFrame['earY']!,
      "c7X": optimalFrame['c7X']!,
      "c7Y": optimalFrame['c7Y']!,
    };
  }

  // 🚀 최종 정산된 1개의 가벼운 JSON Object 오브젝트만 백엔드로 전송!
  Future<bool> sendVisionData() async {
    if (coordinateBatch.isEmpty) return false;

    // 💡 [해결 - 1번 에러] 새로 업데이트된 중앙값 정산 함수명으로 교체 완료!
    Map<String, double> realTargetFrame = _calculateOptimalFrameWithMedian();

    // 2. 단일 객체 전송 (백엔드가 요구하는 포맷 형식)
    final response = await _postRequest(
      "/api/vision/measurement",
      realTargetFrame,
    );
    return response['success'] == true;
  }

  // 🛠️ [해결 - 2, 3, 4, 5번 에러] 최신 Google ML Kit 규격에 최적화된 이미지 변환 함수
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

      // 구글 최신 ML Kit 패키지 스펙에 맞춰 InputImageMetadata 하나로 통합 처리
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
