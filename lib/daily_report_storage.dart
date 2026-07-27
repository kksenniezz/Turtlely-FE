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
  }) async {
    final box = await Hive.openBox(_boxName);
    await box.put(date, {
      'cvaHistory'        : cvaHistory,
      'timeHistory'       : timeHistory,
      'postureHistory'    : postureHistory,
      'avgCva'            : avgCva,
      'warningCount'      : warningCount,
      'cautionCount'      : cautionCount,
      'duration'          : duration,
      'normalDuration'    : normalDuration,
      'accXHistory'       : accXHistory       ?? [],
      'accYHistory'       : accYHistory       ?? [],
      'accZHistory'       : accZHistory       ?? [],
      'rawTimeHistory'    : rawTimeHistory    ?? [],
      'cvaRawHistory'     : cvaRawHistory     ?? [],
      'postureRawHistory' : postureRawHistory ?? [],
      'savedAt'           : DateTime.now().toIso8601String(),
    });
  }

  static Future<Map<String, dynamic>?> loadHistory(String date) async {
    final box = await Hive.openBox(_boxName);
    final data = box.get(date);
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
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