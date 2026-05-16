import 'dart:convert';
import 'package:http/http.dart' as http;

class MediaPipeService {
  // 1. 서버 주소랑 좌표 바구니 선언
  final String baseUrl = "http://54.144.66.35.nip.io:8080";
  List<Map<String, double>> coordinateBatch = [];

  // 2. 3초 끝나면 이 함수를 호출해서 백엔드로 쏩니다.
  Future<bool> sendVisionData() async {
    if (coordinateBatch.isEmpty) return false;

    // 공통 로직 호출
    final response = await _postRequest(
      "/api/vision/measurement",
      coordinateBatch,
    ); // /api/vision/measurement는 임의 경로
    return response['success'] == true;
  }

  // 3. 공통 로직
  Future<Map<String, dynamic>> _postRequest(String path, dynamic body) async {
    final url = Uri.parse('$baseUrl$path');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      print("통신 주소: $url");
      print("응답 데이터: $data");

      return {
        "success": (response.statusCode == 200 && data['isSuccess'] == true),
        "message": data['message'] ?? "에러가 발생했습니다.",
        "result": data['result'],
      };
    } catch (e) {
      print("통신 에러: $e");
      return {"success": false, "message": "네트워크 연결을 확인해주세요."};
    }
  }
}
