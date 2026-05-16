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
      cameraController!.startImageStream((CameraImage image) {
        // [TODO] 팀원들과 맞춘 MediaPipe 웹/앱 웹소켓 혹은 로컬 라이브러리로 프레임 전송구역
        // 지금은 카메라가 잘 도는지 확인하기 위해 테스트용 가상 좌표를 계속 쏴줍니다.

        // 예시: 실시간으로 계산된 좌표를 지도처럼 변환했다고 가정
        Offset mockEye = const Offset(150, 200);
        Offset mockEar = const Offset(200, 230);
        Offset mockC7 = const Offset(210, 310);

        // vision.dart 화면으로 좌표 던지기!
        _poseStreamController.add({
          'eye': mockEye,
          'ear': mockEar,
          'c7': mockC7,
        });

        // 3단계(측정중)일 때 바구니에 데이터 담기
        // (이 로직은 vision.dart의 step 상태와 연동하여 제어 가능)
      });
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
