//media pipe
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MediaPipeService {
  static String loginId = "";
  final String baseUrl = "http://54.144.66.35:8080";
  final storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> coordinateBatch = [];

  bool isCapturing = false;
  int _frameCounter = 0;
  Offset? _lastEyePoint;
  CameraController? cameraController;
  bool isInitialized = false;

  final StreamController<Map<String, Offset>> _poseStreamController =
      StreamController<Map<String, Offset>>.broadcast();
  Stream<Map<String, Offset>> get poseStream => _poseStreamController.stream;

  Future<void> initializeCamera() async {
    // 비전 기능 임시 비활성화 (모바일 테스트용)
    isInitialized = false;
  }

  void _dispatchCoordinates({
    required double eyeX, required double eyeY,
    required double earX, required double earY,
    required double c7X,  required double c7Y,
    required double rawEyeX, required double rawEyeY,
    required double rawEarX, required double rawEarY,
    required double rawC7X,  required double rawC7Y,
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
    });

    if (isCapturing) {
      _frameCounter++;
      if (_frameCounter % 2 == 0) {
        coordinateBatch.add({
          "c7_x": rawC7X, "c7_y": rawC7Y,
          "eye_x": rawEyeX, "eye_y": rawEyeY,
          "tragus_x": rawEarX, "tragus_y": rawEarY,
        });
      }
    }
  }

  void start3SecondCapture() {
    coordinateBatch.clear();
    _lastEyePoint = null;
    _frameCounter = 0;
    isCapturing = true;
  }

  Future<bool> sendBatchVisionData() async {
    isCapturing = false;
    if (coordinateBatch.isEmpty) return false;

    String userIdToSend = MediaPipeService.loginId;
    if (userIdToSend.isEmpty || userIdToSend == "null") {
      final savedId = await storage.read(key: 'savedLoginId');
      if (savedId != null && savedId.isNotEmpty) {
        userIdToSend = savedId;
        MediaPipeService.loginId = savedId;
      }
    }
    if (userIdToSend.isEmpty || userIdToSend == "null") {
      userIdToSend = "guest@turtlely.com";
    }

    final Map<String, dynamic> requestPayload = {
      "frames": coordinateBatch.map((frame) => {
        "c7_x": double.parse(frame["c7_x"].toString()),
        "c7_y": double.parse(frame["c7_y"].toString()),
        "eye_x": double.parse(frame["eye_x"].toString()),
        "eye_y": double.parse(frame["eye_y"].toString()),
        "tragus_x": double.parse(frame["tragus_x"].toString()),
        "tragus_y": double.parse(frame["tragus_y"].toString()),
      }).toList(),
      "login_id": userIdToSend.trim(),
    };

    final response = await _postRequest("/report/analyze", requestPayload);
    return response['success'] == true;
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
    _poseStreamController.close();
  }
}