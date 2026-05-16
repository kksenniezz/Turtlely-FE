import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class MediaPipeService {
  // 1. 서버 주소랑 좌표 바구니 선언
  final String baseUrl = "http://54.144.66.35.nip.io:8080";
  List<Map<String, double>> coordinateBatch = [];

  CameraController? cameraController;
  bool isInitialized = false;

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

      // 🔄 실시간 프레임 스트리밍 시작 (여기서 미디어파이프 연동)
      if (cameraController != null && cameraController!.value.isInitialized) {
        cameraController!.startImageStream((CameraImage image) {
          // 실시간으로 변하는 미세 진동 테스트 좌표 생성
          double pulse = (DateTime.now().millisecondsSinceEpoch % 1000) / 100.0;
          Offset liveEye = Offset(150 + pulse, 200 - pulse);
          Offset liveEar = Offset(200 + pulse, 230 + pulse);
          Offset liveC7 = Offset(210 - pulse, 310 + pulse);

          // vision.dart 화면으로 좌표 던지기!
          _poseStreamController.add({
            'eye': liveEye,
            'ear': liveEar,
            'c7': liveC7,
          });

          // 3초 측정 바구니 적재 로직
          if (coordinateBatch.length < 90) {
            coordinateBatch.add({
              "eyeX": liveEye.dx,
              "eyeY": liveEye.dy,
              "earX": liveEar.dx,
              "earY": liveEar.dy,
              "c7X": liveC7.dx,
              "c7Y": liveC7.dy,
            });
          }
        });
      }
    } catch (e) {
      print("서비스 카메라 초기화 에러: $e");
    }
  }

  // 2. 3초 끝나면 이 함수를 호출해서 백엔드로 쏩니다.
  Future<bool> sendVisionData() async {
    if (coordinateBatch.isEmpty) return false;

    // 공통 로직 호출
    final response = await _postRequest(
      "/api/vision/measurement",
      coordinateBatch,
    ); // /api/vision/measurement는 임의 경로
    return response['success'] == true;
  }

  // 3. 공통 로직
  Future<Map<String, dynamic>> _postRequest(String path, dynamic body) async {
    final url = Uri.parse('$baseUrl$path');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      print("통신 주소: $url");
      print("응답 데이터: $data");

      return {
        "success": (response.statusCode == 200 && data['isSuccess'] == true),
        "message": data['message'] ?? "에러가 발생했습니다.",
        "result": data['result'],
      };
    } catch (e) {
      print("통신 에러: $e");
      return {"success": false, "message": "네트워크 연결을 확인해주세요."};
    }
  }

  void dispose() {
    cameraController?.dispose();
    _poseStreamController.close();
  }
}
