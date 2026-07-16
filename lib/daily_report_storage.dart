import 'package:hive_flutter/hive_flutter.dart';

class DailyReportStorage {
  static const String _boxName = 'daily_report';

  // 오늘 데이터 저장 (3축값 추가)
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
    List<double>? accXHistory,  // ✅ 추가
    List<double>? accYHistory,  // ✅ 추가
    List<double>? accZHistory,  // ✅ 추가
  }) async {
    final box = await Hive.openBox(_boxName);
    await box.put(date, {
      'cvaHistory'     : cvaHistory,
      'timeHistory'    : timeHistory,
      'postureHistory' : postureHistory,
      'avgCva'         : avgCva,
      'warningCount'   : warningCount,
      'cautionCount'   : cautionCount,
      'duration'       : duration,
      'normalDuration' : normalDuration,
      'accXHistory'    : accXHistory ?? [],  // ✅ 추가
      'accYHistory'    : accYHistory ?? [],  // ✅ 추가
      'accZHistory'    : accZHistory ?? [],  // ✅ 추가
      'savedAt'        : DateTime.now().toIso8601String(),
    });
  }

  // 날짜별 데이터 불러오기
  static Future<Map<String, dynamic>?> loadHistory(String date) async {
    final box = await Hive.openBox(_boxName);
    final data = box.get(date);
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  // 이틀 지난 데이터 자동 삭제
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

  // 저장된 날짜 목록
  static Future<List<String>> getSavedDates() async {
    final box = await Hive.openBox(_boxName);
    return box.keys.map((k) => k.toString()).toList();
  }
}