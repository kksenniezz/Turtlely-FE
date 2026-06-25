import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = "http://54.144.66.35.nip.io:8001";

  final _storage = const FlutterSecureStorage();

  // 💡 저장소에서 액세스 토큰 가져오기
  Future<String> _getToken() async {
    return await _storage.read(key: 'accessToken') ?? '';
  }

  // 💡 [추가] 저장소에서 실제 회원 ID 가져오기 (없으면 기본값 '1')
  Future<int> _getMemberId() async {
    final savedId = await _storage.read(key: 'memberId') ?? '1';
    return int.parse(savedId);
  }

  // 💡 [추가] 저장소에서 실제 월별 기록 ID 가져오기 (없으면 기본값 '1')
  Future<int> _getMonthlyId() async {
    final savedId = await _storage.read(key: 'monthlyId') ?? '1';
    return int.parse(savedId);
  }

  // /api/daily/calibration
  Future<Map<String, dynamic>> sendCalibration(double avgX, double avgY, double avgZ) async {
    try {
      final token = await _getToken();
      final currentMonthlyId = await _getMonthlyId(); // 동적 ID 가져오기

      final response = await http.post(
        Uri.parse("$baseUrl/api/daily/calibration"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "monthly_id"      : currentMonthlyId,
          "current_accel_x" : avgX,
          "current_accel_y" : avgY,
          "current_accel_z" : avgZ,
        }),
      );
      debugPrint("📡 캘리브레이션 응답 코드: ${response.statusCode}");
      debugPrint("📡 캘리브레이션 응답 바디: ${response.body}");
      return {
        "statusCode": response.statusCode,
        "body": response.body,
        "token": token,
      };
    } catch (e) {
      debugPrint("❌ 일일 캘리브레이션 오류: $e");
      return {"statusCode": 0, "body": e.toString(), "token": ""};
    }
  }

  // /api/daily
  // /api/daily - bool 대신 Map으로 반환
  Future<Map<String, dynamic>> sendDaily({
    required double accX,
    required double accY,
    required double accZ,
    required String level,
  }) async {
    try {
      final token = await _getToken();
      final currentMonthlyId = await _getMonthlyId();

      final response = await http.post(
        Uri.parse("$baseUrl/api/daily"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "monthly_id"      : currentMonthlyId,
          "current_accel_x" : accX,
          "current_accel_y" : accY,
          "current_accel_z" : accZ,
          "level"           : level,
        }),
      );
      if (response.statusCode == 200) {
        final body = response.body.trim();
        debugPrint("📥 /api/daily 응답: $body");
        final json = jsonDecode(body);
        final postureResult = json["posture_result"] ?? "normal";
        final estimatedCva  = (json["estimated_cva"] ?? 0.0).toDouble();
        return {
          "isWarning"    : postureResult == "warning",
          "estimatedCva" : estimatedCva,
        };
      }
    } catch (e) {
      debugPrint("❌ /api/daily 실패: $e");
    }
    return {"isWarning": false, "estimatedCva": 0.0};
  }

  // /api/daily/report
  Future<Map<String, dynamic>> saveReport({
    required bool isBadPosture,
    required int monitoringSeconds,
    required String level,
    required double angle,
  }) async {
    try {
      final token = await _getToken();
      final realMemberId = await _getMemberId(); // 💡 실제 로그인한 유저 ID 가져오기!

      final response = await http.post(
        Uri.parse("$baseUrl/api/daily/report"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "member_id"           : realMemberId, // 💡 고정값 '1' 탈출 완료!
          "angle"               : angle,
          "postureStatus"       : isBadPosture ? 'warning' : 'normal',
          "notificationTrigger" : isBadPosture ? 1 : 0, // 서버 외래키 오류 방지용 int 변환
          "duration"            : monitoringSeconds,
          "level"               : level,
          "batteryLevel"        : 85,
        }),
      );
      debugPrint("📡 리포트 응답 코드: ${response.statusCode}");
      debugPrint("📡 리포트 응답 바디: ${response.body}");
      return {
        "statusCode": response.statusCode,
        "body": response.body,
        "token": token,
      };
    } catch (e) {
      debugPrint("❌ DB 저장 오류: $e");
      return {"statusCode": 0, "body": e.toString(), "token": ""};
    }
  }
}