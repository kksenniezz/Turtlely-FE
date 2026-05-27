import 'dart:convert';
import 'package:http/http.dart' as http;

// 📦 백엔드 응답 규격 데이터 모델
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

      if (response.statusCode == 500) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes));
        throw decodedData['errorCode'] ?? 'SERVER_INTERNAL_ERROR';
      }

      return null;
    } catch (e) {
      if (e is String) rethrow;
      throw 'UNKNOWN_NETWORK_ERROR';
    }
  }
}
