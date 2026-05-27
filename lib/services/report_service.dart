import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// 📦 백엔드 DB 구조 및 연동 명세 데이터 모델
class ReportData {
  final int status;
  final String message;
  final int year;
  final int month;
  final String nickname;
  final String postureStatus;
  final String postureMessage;
  final double cvaAngle;
  final double craAngle;
  final int totalMeasurements;

  ReportData({
    required this.status,
    required this.message,
    required this.year,
    required this.month,
    required this.nickname,
    required this.postureStatus,
    required this.postureMessage,
    required this.cvaAngle,
    required this.craAngle,
    required this.totalMeasurements,
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    return ReportData(
      status: json['status'] ?? 0,
      message: json['message'] ?? '',
      year: json['year'] ?? 0,
      month: json['month'] ?? 0,
      nickname: json['nickname'] ?? '사용자',
      postureStatus: json['posture_status'] ?? '',
      postureMessage: json['posture_message'] ?? '',
      cvaAngle: (json['cva_angle'] as num?)?.toDouble() ?? 0.0,
      craAngle: (json['cra_angle'] as num?)?.toDouble() ?? 0.0,
      totalMeasurements: json['total_measurements'] ?? 0,
    );
  }
}

class ReportService {
  static const String _baseUrl = 'http://54.144.66.35.nip.io:8000';

  // 💡 [MediaPipeService 문법] 시큐어 스토리지 연동
  final _storage = const FlutterSecureStorage();

  Future<ReportData?> fetchMonthlyReport({
    required int year,
    required int month,
  }) async {
    String userIdToSend = "guest@turtlely.com"; // 기본값 지정

    try {
      // 💡 [MediaPipeService 문법] 저장된 accessToken 확보
      final accessToken = await _storage.read(key: 'accessToken');

      if (accessToken != null &&
          accessToken.isNotEmpty &&
          accessToken != "null") {
        // 토큰의 배를 슥 갈라서 유저 ID(sub) 추출
        final normalizedPayload = utf8.decode(
          base64Url.decode(base64Url.normalize(accessToken.split('.')[1])),
        );
        final Map<String, dynamic> payloadMap = jsonDecode(normalizedPayload);

        if (payloadMap['sub'] != null) {
          userIdToSend = payloadMap['sub'].toString().trim();
        }
      }

      // 🎯 동적으로 확보한 userIdToSend를 쿼리스트링에 안전하게 매핑
      final url = Uri.parse(
        '$_baseUrl/report?login_id=$userIdToSend&year=$year&month=$month',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes));
        return ReportData.fromJson(decodedData);
      }

      // 500 에러 가공 및 throw 처리
      if (response.statusCode == 500) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes));
        final String errorCode = decodedData['errorCode'] ?? '';

        if (errorCode == "DATABASE_ERROR") {
          throw "데이터베이스 연결에 실패했습니다. 관리자에게 문의하세요.";
        } else if (errorCode == "SERVER_INTERNAL_ERROR") {
          throw "서버 내부 로직 오류가 발생했습니다. 시스템팀이 확인 중입니다.";
        } else {
          throw "알 수 없는 서버 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.";
        }
      }

      return null;
    } catch (e) {
      print("🚨 [ReportService 통신 에러 진짜 원인]: $e");

      if (e is String) rethrow;
      throw '네트워크 연결이 원활하지 않습니다. 인터넷 연결을 확인해 주세요.';
    }
  }
}
