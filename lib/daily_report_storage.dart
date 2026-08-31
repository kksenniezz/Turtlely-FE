import 'package:hive_flutter/hive_flutter.dart';

class DailyReportStorage {
  static const String _boxName = 'daily_report';

  static Future<void> saveHistory({
    required String date,
    required List<double> cvaHistory,
    required List<String> timeHistory,
    required List<String> postureHistory,
    required double avgCva,
    required int warningCount,
    required int cautionCount,
    required int duration,
    required int normalDuration,
    List<double>? accXHistory,
    List<double>? accYHistory,
    List<double>? accZHistory,
    List<String>? rawTimeHistory,
    List<double>? cvaRawHistory,
    List<String>? postureRawHistory,
    // ✅ 추가: 각 cvaHistory 포인트가 "새 측정 세션의 첫 포인트"인지 표시하는 배열.
    //    cvaHistory/timeHistory/postureHistory와 길이·순서가 항상 1:1로 대응됨.
    //    그래프에서 서로 다른 측정 세션이 시간상 가깝다는 이유로 하나로
    //    뭉개지는 문제를 막기 위해 사용됨 (report_view.dart의 _processGraphData 참고).
    List<bool>? sessionStartHistory,
    // ✅ 추가: "자세 유지 점수"의 로컬 폴백 값.
    //    실제 서비스 흐름(home.dart의 실측정 저장)에서는 채우지 않아도 됨 —
    //    점수는 원래 서버(api.getDailyReport)에서만 오기 때문.
    //    다만 더미 데이터 등 서버 리포트가 없는 날짜를 위해 로컬에도
    //    폴백 점수를 저장할 수 있게 필드만 추가해둠 (report_view.dart 참고).
    int? postureScore,
  }) async {
    final box = await Hive.openBox(_boxName);
    await box.put(date, {
      'cvaHistory'          : cvaHistory,
      'timeHistory'         : timeHistory,
      'postureHistory'      : postureHistory,
      'avgCva'              : avgCva,
      'warningCount'        : warningCount,
      'cautionCount'        : cautionCount,
      'duration'            : duration,
      'normalDuration'      : normalDuration,
      'accXHistory'         : accXHistory       ?? [],
      'accYHistory'         : accYHistory       ?? [],
      'accZHistory'         : accZHistory       ?? [],
      'rawTimeHistory'      : rawTimeHistory    ?? [],
      'cvaRawHistory'       : cvaRawHistory     ?? [],
      'postureRawHistory'   : postureRawHistory ?? [],
      // ✅ 없으면(과거 데이터) 빈 리스트로 저장 → report_view.dart 쪽에서
      //    길이 불일치 시 자동으로 "세션 마커 없음"으로 처리하고 기존 시간차 로직으로 폴백함
      'sessionStartHistory' : sessionStartHistory ?? [],
      'postureScore'        : postureScore, // null 가능 (실제 데이터는 서버 점수를 우선 사용)
      'savedAt'             : DateTime.now().toIso8601String(),
    });
  }

  static Future<Map<String, dynamic>?> loadHistory(String date) async {
    final box = await Hive.openBox(_boxName);
    final data = box.get(date);
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  // ✅ 추가: 특정 날짜의 저장된 기록을 완전히 삭제.
  //    더미 데이터로 덮어쓰기 전에 이전(특히 버그 있던 시절의 실측정) 데이터가
  //    확실히 지워지도록 디버그 유틸리티에서 사용.
  static Future<void> deleteHistory(String date) async {
    final box = await Hive.openBox(_boxName);
    await box.delete(date);
  }

  static Future<void> _deleteOldData(Box box) async {
    final twoDaysAgo = DateTime.now().subtract(const Duration(days: 730));
    final keysToDelete = <String>[];
    for (final key in box.keys) {
      final data = box.get(key) as Map?;
      if (data == null) continue;
      final savedAt = DateTime.tryParse(data['savedAt'] ?? '');
      if (savedAt != null && savedAt.isBefore(twoDaysAgo)) {
        keysToDelete.add(key.toString());
      }
    }
    for (final key in keysToDelete) {
      await box.delete(key);
    }
  }

  static Future<List<String>> getSavedDates() async {
    final box = await Hive.openBox(_boxName);
    return box.keys.map((k) => k.toString()).toList();
  }
}