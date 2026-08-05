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
  Future<Map<String, dynamic>> sendCalibration(
    double avgX,
    double avgY,
    double avgZ,
  ) async {
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
          "monthly_id": currentMonthlyId,
          "current_accel_x": avgX,
          "current_accel_y": avgY,
          "current_accel_z": avgZ,
        }),
      );
      debugPrint("캘리브레이션 응답 코드: ${response.statusCode}");
      debugPrint("캘리브레이션 응답 바디: ${response.body}");
      return {
        "statusCode": response.statusCode,
        "body": response.body,
        "token": token,
      };
    } catch (e) {
      debugPrint("캘리브레이션 오류: $e");
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
    debugPrint("sendDaily 호출됨 | accX: $accX, accY: $accY, accZ: $accZ");
    try {
      final token = await _getToken();
      final currentMonthlyId = await _getMonthlyId();
      final currentMemberId = await _getMemberId();

      final response = await http.post(
        Uri.parse("$baseUrl/api/daily"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "monthly_id": currentMonthlyId,
          "member_id": currentMemberId,
          "current_accel_x": accX,
          "current_accel_y": accY,
          "current_accel_z": accZ,
          "level": level,
        }),
      );
      debugPrint("/api/daily 상태코드: ${response.statusCode}");
      debugPrint("/api/daily 응답바디: ${response.body}");
      if (response.statusCode == 200) {
        final body = response.body.trim();
        final json = jsonDecode(body);
        final postureResult = json["posture_result"] ?? "normal";
        final estimatedCva = (json["estimated_cva"] ?? 0.0).toDouble();
        return {
          "postureResult": postureResult,
          "estimatedCva": estimatedCva,
          "isWarning": postureResult == "warning",
        };
      }
    } catch (e) {
      debugPrint("/api/daily 실패: $e");
    }
    return {"postureResult": "normal", "estimatedCva": 0.0, "isWarning": false};
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
        if (json['result'] != null &&
            json['result']['calendarReports'] != null) {
          return json['result']['calendarReports'] as List<dynamic>;
        }
      }
    } catch (e) {
      debugPrint("캘린더 오류: $e");
    }
    return [];
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
      debugPrint("일일 리포트 오류: $e");
    }
    return null;
  }

  // POST /api/monthly/alarm 월간리포트 알림 수신 상태 설정
  Future<Map<String, dynamic>?> setMonthlyAlarm(String alarmType) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse("$springUrl/api/monthly/alarm"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "alarmType": alarmType, // "MEASURE" 또는 "RESULT"
        }),
      );

      debugPrint("🔔 월간 알림 응답 코드: ${response.statusCode}");
      debugPrint("🔔 월간 알림 응답 바디: ${response.body}");

      if (response.statusCode == 200) {
        final decodedData = jsonDecode(utf8.decode(response.bodyBytes));
        return decodedData as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("월간 알림 설정 오류: $e");
    }
    return null;
  }

  // /api/exercise 운동존 영상 목록 조회
  Future<List<dynamic>> getExerciseVideos({
    String? postureType,
    String? category,
    int? durationMinutes,
    String? keyword,
  }) async {
    try {
      final token = await _getToken();
      final queryParams = <String, String>{};
      if (postureType != null && postureType != 'ALL') {
        queryParams['postureType'] = postureType;
      }
      if (category != null && category != 'ALL') {
        queryParams['category'] = category;
      }
      if (durationMinutes != null) {
        queryParams['durationMinutes'] = durationMinutes.toString();
      }
      if (keyword != null && keyword.isNotEmpty) {
        queryParams['keyword'] = keyword;
      }

      final uri = Uri.parse(
        "$springUrl/api/exercise",
      ).replace(queryParameters: queryParams);
      final response = await http.get(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      debugPrint("운동존 응답: ${response.statusCode}");
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final result = json['result'];
        if (result != null && result['videoList'] != null) {
          return result['videoList'] as List<dynamic>;
        }
      }
    } catch (e) {
      debugPrint("운동존 오류: $e");
    }
    return [];
  }

  // POST /api/exercise/{video_id} 북마크 토글
  Future<bool?> toggleBookmark(int videoId) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse("$springUrl/api/exercise/$videoId");

      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      debugPrint("북마크 토글 응답 코드: ${response.statusCode}");
      final String decodedBody = utf8.decode(response.bodyBytes);
      debugPrint("북마크 토글 응답 바디: ${decodedBody}");

      final json = jsonDecode(decodedBody);

      if (response.statusCode == 200 && json['isSuccess'] == true) {
        if (json['result'] != null && json['result']['is_bookmarked'] != null) {
          return json['result']['is_bookmarked'] as bool;
        }
      } else {
        debugPrint("북마크 처리 실패: ${json['message']}");
      }
    } catch (e) {
      debugPrint("북마크 토글 오류: $e");
    }
    return null;
  }

  // GET /api/exercise/bookmarks 북마크한 운동 영상 목록 조회
  Future<List<dynamic>> getBookmarkedVideos() async {
    try {
      final token = await _getToken();
      final uri = Uri.parse("$springUrl/api/exercise/bookmarks");

      final response = await http.get(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      debugPrint("북마크 목록 응답 코드: ${response.statusCode}");
      debugPrint("북마크 목록 응답 바디: ${response.body}");

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['isSuccess'] == true &&
            json['result'] != null &&
            json['result']['bookmark_list'] != null) {
          return json['result']['bookmark_list'] as List<dynamic>;
        }
      }
    } catch (e) {
      debugPrint("북마크 목록 조회 오류: $e");
    }
    return [];
  }
}
