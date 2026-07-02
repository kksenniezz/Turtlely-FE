import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// 📦 백엔드 DB 구조 및 연동 명세 데이터 모델
class ReportData {
  final String message;
  final String dataStatus;
  final int year;
  final int month;
  final String nickname;
  final String postureStatus;
  final double cvaAngle;
  final double craAngle;
  final int? score;
  final List<dynamic>? cvaHistory;
  final List<dynamic>? craHistory;
  final List<String>? predictedDiseases;
  final Map<String, dynamic>? predictionData;

  ReportData({
    required this.message,
    required this.dataStatus,
    required this.year,
    required this.month,
    required this.nickname,
    required this.postureStatus,
    required this.cvaAngle,
    required this.craAngle,
    this.score,
    this.cvaHistory,
    this.craHistory,
    this.predictedDiseases,
    this.predictionData,
  });

  factory ReportData.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>;
    try {
      return ReportData(
        message: json['message'] ?? '',
        dataStatus: result['data_status'] ?? 'NOT_YET',
        year: result['report_year'] ?? DateTime.now().year,
        month: result['report_month'] ?? DateTime.now().month,
        nickname: result['nickname'] ?? '회원',

        postureStatus: result['posture_type'] ?? '데이터 없음',

        cvaAngle: (result['cva_angle'] as num?)?.toDouble() ?? 0,
        craAngle: (result['cra_angle'] as num?)?.toDouble() ?? 0,

        score: result['score'] == null
            ? null
            : int.parse(result['score'].toString()),

        cvaHistory: result['cva_history'] ?? [],
        craHistory: result['cra_history'] ?? [],

        predictedDiseases: List<String>.from(
          result['predicted_diseases'] ?? [],
        ),

        predictionData:
            result['prediction_data'] as Map<String, dynamic>? ?? {},
      );
    } catch (e) {
      print("[ReportData.fromJson 파싱 오류] $e");
      rethrow;
    }
  }
}

class ReportService {
  static const String _baseUrl = 'http://54.144.66.35.nip.io:8080';
  final _storage = const FlutterSecureStorage();

  Future<ReportData?> fetchMonthlyReport({required int monthlyId}) async {
    try {
      final accessToken = await _storage.read(key: 'accessToken');
      final url = Uri.parse('$_baseUrl/api/monthly/$monthlyId');
      print("🚀 [ReportService 요청 주소]: $url");

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      Map<String, dynamic> decodedData = {};

      if (response.body.isNotEmpty) {
        decodedData = json.decode(utf8.decode(response.bodyBytes));
      }

      if (response.statusCode == 200) {
        print(decodedData["code"]);
        return ReportData.fromJson(decodedData);
      }

      if (response.statusCode == 202) {
        print("AI 분석이 아직 완료되지 않았습니다.");
        return null;
      }

      if (response.statusCode == 404) {
        print(decodedData["code"]); // REPORT_NOT_FOUND
        print("리포트를 찾을 수 없습니다.");
        return null;
      }

      if (response.statusCode == 500) {
        print(decodedData["code"]); // LLM_SERVER_ERROR
        print("AI 서버 연산 중 오류가 발생했습니다.");
        return null;
      }

      if (response.statusCode == 400) {
        print(decodedData["code"]); // INVALID_REPORT_ID
        print("잘못된 리포트 ID입니다.");
        return null;
      }

      if (response.statusCode == 401) {
        print(decodedData["code"]); // AUTH_TOKEN_INVALID
        print("인증에 실패했습니다.");
        return null;
      }

      print("예상하지 못한 응답: ${response.statusCode}");
      return null;
    } catch (e) {
      print("[ReportService 통신 에러 진짜 원인]: $e");
      if (e is String) rethrow;
      throw '네트워크 연결이 원활하지 않습니다. 인터넷 연결을 확인해 주세요.';
    }
  }
}
