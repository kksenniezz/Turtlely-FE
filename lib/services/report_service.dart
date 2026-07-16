import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class MonthlyListItem {
  final int monthlyId;
  final int year;
  final int month;
  final DateTime measuredAt;
  final bool isVirtual;

  MonthlyListItem({
    required this.monthlyId,
    required this.year,
    required this.month,
    required this.measuredAt,
    this.isVirtual = false,
  });

  factory MonthlyListItem.fromJson(Map<String, dynamic> json) {
    return MonthlyListItem(
      monthlyId: json['monthlyId'] ?? 0,
      year: json['reportYear'] ?? DateTime.now().year,
      month: json['reportMonth'] ?? DateTime.now().month,
      measuredAt: json['measuredAt'] != null
          ? DateTime.tryParse(json['measuredAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

// 백엔드 DB 구조 및 연동 명세 데이터 모델
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
  final List<Map<String, dynamic>> predictedDiseases;
  final Map<String, dynamic>? predictionData;
  final bool measurementAlarm;
  final bool reportAlarm;
  final DateTime? measuredAt;

  ReportData({
    required this.message,
    required this.dataStatus,
    required this.year,
    required this.month,
    required this.nickname,
    required this.postureStatus,
    required this.cvaAngle,
    required this.craAngle,
    required this.score,
    required this.cvaHistory,
    required this.craHistory,
    required this.predictedDiseases,
    required this.predictionData,
    required this.measurementAlarm,
    required this.reportAlarm,
    required this.measuredAt,
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

        predictedDiseases:
            (result['predicted_diseases'] as List?)?.map((e) {
              final map = e as Map<String, dynamic>;

              return {
                "name": map['name'] ?? '',
                "score": (map['score'] as num?)?.toDouble() ?? 0.0,
              };
            }).toList() ??
            [],
        predictionData: Map<String, dynamic>.from(
          result['prediction_data'] ?? {},
        ),

        measurementAlarm: result['measurement_alarm'] ?? false,
        reportAlarm: result['report_alarm'] ?? false,
        measuredAt: result['measured_at'] == null
            ? null
            : DateTime.tryParse(result['measured_at']) ?? DateTime.now(),
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

  // 1. 월간 리포트 조회
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
        ReportData.fromJson(decodedData);
      }

      if (response.statusCode == 202) {
        print("AI 분석이 아직 완료되지 않았습니다.");
        return null;
      }

      if (response.statusCode == 404) {
        print("리포트를 찾을 수 없습니다.");
        return null;
      }

      if (response.statusCode == 500) {
        print("AI 서버 연산 중 오류가 발생했습니다.");
        return null;
      }

      if (response.statusCode == 400) {
        print("잘못된 리포트 ID입니다.");
        return null;
      }

      if (response.statusCode == 401) {
        print("인증에 실패했습니다.");
        return null;
      }
      return null;
    } catch (e) {
      print("[ReportService 통신 에러 진짜 원인]: $e");
      throw '네트워크 연결이 원활하지 않습니다. 인터넷 연결을 확인해 주세요.';
    }
  }

  // 2. 월 목록 조회 (드롭다운 시)
  Future<List<MonthlyListItem>> fetchMonthlyList() async {
    try {
      final accessToken = await _storage.read(key: 'accessToken');
      final url = Uri.parse('$_baseUrl/api/monthly/list');

      print("🚀 [Monthly List 요청]: $url");

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) return [];

      final decoded = json.decode(utf8.decode(response.bodyBytes));
      print("🚀 [서버 응답 구조 확인]: $decoded");

      if (decoded is List) {
        return decoded.map((e) => MonthlyListItem.fromJson(e)).toList();
      }
      // 2. 만약 응답이 Map인데 내부에 result 리스트가 있다면 (수정된 방식)
      else if (decoded is Map && decoded.containsKey('result')) {
        return (decoded['result'] as List)
            .map((e) => MonthlyListItem.fromJson(e))
            .toList();
      }

      return [];
    } catch (e) {
      print("[fetchMonthlyList 에러]: $e");
      return [];
    }
  }

  // 3. 월간 알림 설정
  Future<bool> registerMonthlyAlarm({required String alarmType}) async {
    try {
      final accessToken = await _storage.read(key: 'accessToken');

      final url = Uri.parse('$_baseUrl/api/monthly/alarm');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"alarmType": alarmType}),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(utf8.decode(response.bodyBytes));
        return decoded["isSuccess"] == true;
      }

      print("알림 설정 실패 : ${response.body}");
      return false;
    } catch (e) {
      print("[registerMonthlyAlarm 오류] $e");
      return false;
    }
  }
}
