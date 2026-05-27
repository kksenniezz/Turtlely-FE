import 'dart:convert';
import 'package:http/http.dart' as http;

// 📦 [모델 내장] 백엔드 응답 규격 데이터 모델 DTO
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

// 🌐 네트워크 통신 및 에러 텍스트 가공 서비스
class ReportService {
  static const String _baseUrl = 'http://localhost:8000/api';

  Future<ReportData?> fetchMonthlyReport({
    required String loginId,
    required int year,
    required int month,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/report?login_id=$loginId&year=$year&month=$month',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes));
        return ReportData.fromJson(decodedData);
      }

      // 🚨 500 에러 처리: 백엔드 에러코드를 유저 친화적인 메시지로 변환해 throw
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
      // 이미 정제된 한글 에러 메시지는 그대로 패스
      if (e is String) rethrow;
      throw '네트워크 연결이 원활하지 않습니다. 인터넷 연결을 확인해 주세요.';
    }
  }
}
