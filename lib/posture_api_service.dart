import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = "http://54.144.66.35.nip.io:8001";
  static const String springUrl = "http://54.144.66.35.nip.io:8080";

  final _storage = const FlutterSecureStorage();

  Future<String> _getToken() async {
    return await _storage.read(key: 'accessToken') ?? '';
  }

  Future<int> _getMemberId() async {
    final savedId = await _storage.read(key: 'memberId') ?? '1';
    return int.parse(savedId);
  }

  Future<int> _getMonthlyId() async {
    final savedId = await _storage.read(key: 'monthlyId') ?? '1';
    return int.parse(savedId);
  }

  // /api/daily/calibration
  Future<Map<String, dynamic>> sendCalibration(double avgX, double avgY, double avgZ) async {
    try {
      final token = await _getToken();
      final currentMonthlyId = await _getMonthlyId();

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
          "postureResult" : postureResult,
          "estimatedCva"  : estimatedCva,
          "isWarning"     : postureResult == "warning",
        };
      }
    } catch (e) {
      debugPrint("❌ /api/daily 실패: $e");
    }
    return {"postureResult": "normal", "estimatedCva": 0.0, "isWarning": false};
  }

  // /api/daily/report
  // 💡 posture_api_service.dart 파일의 saveReport 함수를 이걸로 통째로 변경해 줘!
  Future<Map<String, dynamic>> saveReport({
    required bool isBadPosture,
    required int monitoringSeconds,
    required String level,
    required double angle,
  }) async {
    try {
      final token = await _getToken();
      final realMemberId = await _getMemberId();

      // 💡 500 에러를 뿜던 http.post를 백엔드 규격에 맞춰 확실하게 http.put으로 변경!
      final response = await http.put(
        Uri.parse("$springUrl/api/daily/report"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "member_id"           : realMemberId,
          "angle"               : angle,
          "postureStatus"       : isBadPosture ? 'warning' : 'normal',
          "notificationTrigger" : isBadPosture ? 1 : 0,
          "duration"            : monitoringSeconds,
          "level"               : level,
          "batteryLevel"        : 85,
        }),
      );

      debugPrint("📡 리포트 응답 코드: ${response.statusCode}");
      debugPrint("📡 리포트 응답 바디: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          "statusCode": response.statusCode,
          "body": response.body,
          "token": token ?? ""
        };
      } else {
        return {
          "statusCode": response.statusCode,
          "body": response.body,
          "token": token ?? ""
        };
      }
    } catch (e) {
      debugPrint("❌ 리포트 저장 중 에러 발생: $e");
      return {"statusCode": 500, "body": e.toString(), "token": ""};
    }
  }
  // /api/daily/cal
  Future<List<dynamic>> getCalendarReports() async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse("$springUrl/api/daily/cal"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );
      debugPrint("📅 캘린더 응답: ${response.body}");
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        
        // 💡 result와 calendarReports가 null인지 안전하게 2중 방어막 확인
        if (json['result'] != null && json['result']['calenderReports'] != null) {
          // 타입을 강제로 맞추지 않고, 있는 그대로의 List로 던져줍니다!
          return json['result']['calendarReports'] as List<dynamic>;
        }
      }
    } catch (e) {
      debugPrint("❌ 캘린더 오류: $e");
    }
    return []; // 에러 나면 안전하게 빈 리스트 뱉기
  }

  // /api/daily/{dailyId}
  Future<Map<String, dynamic>?> getDailyReport(int dailyId) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse("$springUrl/api/daily/$dailyId"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );
      debugPrint("📋 일일 리포트 응답: ${response.body}");
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return Map<String, dynamic>.from(json['result']);
      }
    } catch (e) {
      debugPrint("❌ 일일 리포트 오류: $e");
    }
    return null;
  }
}