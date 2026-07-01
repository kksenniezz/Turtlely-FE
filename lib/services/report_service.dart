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
  final int? score;
  final List<dynamic>? cvaHistory;
  final List<dynamic>? craHistory;
  final List<String>? predictedDiseases;
  final Map<String, dynamic>? predictionData;

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
    this.score,
    this.cvaHistory,
    this.craHistory,
    this.predictedDiseases,
    this.predictionData,
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    final result = json['result'];
    try {
      if (json.containsKey('data') && json['data'] is Map<String, dynamic>) {
        return ReportData.fromJson(json['data'] as Map<String, dynamic>);
      }

      // 데이터 타입 미스매치 방지를 위한 안전한 형변환 (String으로 온 숫자도 int로 처리)
      int parseToInt(dynamic value) {
        if (value == null) return 0;
        if (value is int) return value;
        if (value is String) return int.tryParse(value) ?? 0;
        return 0;
      }

      return ReportData(
        status: parseToInt(json['status']),
        message: json['message'] ?? '',
        // 만약 백엔드가 0이나 null을 주면 프론트 앱이 뻗지 않도록 현재 날짜 기본값 방어
        year: parseToInt(json['year']) == 0
            ? DateTime.now().year
            : parseToInt(json['year']),
        month: parseToInt(json['month']) == 0
            ? DateTime.now().month
            : parseToInt(json['month']),
        nickname: json['nickname'] ?? '회원님', // 기본값을 '회원님'으로 매핑
        postureStatus: json['posture_status'] ?? '역C자목',
        postureMessage: json['posture_message'] ?? '',
        cvaAngle: (json['cva_angle'] as num?)?.toDouble() ?? 69.0,
        craAngle: (json['cra_angle'] as num?)?.toDouble() ?? 128.5,
        totalMeasurements: parseToInt(json['total_measurements']),
        score: result(['score']),
        cvaHistory: result['cva_history'] as List<dynamic>?,
        craHistory: result['cra_history'] as List<dynamic>?,
        predictedDiseases: List<String>.from(
          result['predicted_diseases'] ?? [],
        ),
        predictionData: result['prediction_data'],
      );
    } catch (e) {
      print("[ReportData.fromJson 파싱 도중 에러 발생]: $e");
      return ReportData(
        status: 200,
        message: "Parsing Fallback",
        year: DateTime.now().year,
        month: DateTime.now().month,
        nickname: '회원님',
        // nickname: json['nickname'] ?? '회원님',
        postureStatus: '역C자목',
        postureMessage: '',
        cvaAngle: 64.09,
        craAngle: 123.03,
        totalMeasurements: 1,
      );
    }
  }
}

class ReportService {
  static const String _baseUrl = 'http://54.144.66.35.nip.io:8080';
  final _storage = const FlutterSecureStorage();

  Future<ReportData?> fetchMonthlyReport({
    required int year,
    required int month,
  }) async {
    int activeMemberId = 1;

    try {
      final accessToken = await _storage.read(key: 'accessToken');

      if (accessToken != null &&
          accessToken.isNotEmpty &&
          accessToken != "null") {
        final normalizedPayload = utf8.decode(
          base64Url.decode(base64Url.normalize(accessToken.split('.')[1])),
        );
        final Map<String, dynamic> payloadMap = jsonDecode(normalizedPayload);

        // 🔑 [조회용 토큰 배가르기] member_id 추출 연동
        if (payloadMap['member_id'] != null) {
          activeMemberId = int.parse(payloadMap['member_id'].toString().trim());
        }
      }

      final url = Uri.parse(
        '$_baseUrl/report/monthly?member_id=$activeMemberId&year=$year&month=$month',
      );

      print("🚀 [ReportService 요청 주소]: $url");
      final response = await http.get(url);
      print("📥 [ReportService 응답 바디 raw]: ${utf8.decode(response.bodyBytes)}");

      if (response.statusCode == 404 || response.body.contains("Not Found")) {
        throw "NOT_FOUND_TRIGGER";
      }

      if (response.statusCode == 200) {
        final decodedData = json.decode(utf8.decode(response.bodyBytes));
        return ReportData.fromJson(decodedData);
      }

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
