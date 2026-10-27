import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'style.dart';
import 'main.dart'; // localNotifications, hasUnreadNotification 연동

class AlarmView extends StatefulWidget {
  const AlarmView({super.key});

  @override
  State<AlarmView> createState() => _AlarmViewState();
}

class _AlarmViewState extends State<AlarmView> {
  final _storage = const FlutterSecureStorage();
  static const String springUrl = "http://54.144.66.35.nip.io:8080";

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<String> _getToken() async {
    return await _storage.read(key: 'accessToken') ?? '';
  }

  void _updateUnreadBadgeStatus() {
    final hasUnread = _notifications.any((n) => n['is_read'] != true);
    hasUnreadNotification.value = hasUnread;
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse("$springUrl/api/notifications?page=0&size=50"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );
      
      List<Map<String, dynamic>> serverList = [];
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final list = json['result']['notification_list'] as List<dynamic>;
        serverList = List<Map<String, dynamic>>.from(list);
      }

      setState(() {
        _notifications = [...localNotifications, ...serverList];
        _isLoading = false;
      });
      _updateUnreadBadgeStatus();
    } catch (e) {
      debugPrint("❌ 알림 조회 실패: $e");
      setState(() {
        _notifications = [...localNotifications];
        _isLoading = false;
      });
      _updateUnreadBadgeStatus();
    }
  }

  Future<void> _markAsRead(int notificationId, int index) async {
    try {
      final token = await _getToken();
      
      final target = _notifications[index];
      if (localNotifications.contains(target)) {
        target['is_read'] = true;
      } else {
        await http.patch(
          Uri.parse("$springUrl/api/notifications/$notificationId/read"),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Bearer $token",
          },
        );
      }

      setState(() {
        _notifications[index]['is_read'] = true;
      });
      _updateUnreadBadgeStatus();
    } catch (e) {
      debugPrint("❌ 읽음 처리 실패: $e");
    }
  }

  Future<void> _deleteAll() async {
    try {
      final token = await _getToken();
      await http.delete(
        Uri.parse("$springUrl/api/notifications"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );
      
      localNotifications.clear();

      setState(() => _notifications = []);
      _updateUnreadBadgeStatus();
    } catch (e) {
      debugPrint("❌ 전체 삭제 실패: $e");
    }
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "알림을 전체 삭제하시겠습니까?",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("취소", style: TextStyle(color: Colors.grey, fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TColor.buttonGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _deleteAll();
            },
            child: const Text("확인", style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // ★ [시계 아이콘 수정] 슬림한 모던 타이머(Icons.timer_outlined)로 변경 ★
  IconData _getIcon(String type, String content) {
    final text = content.toLowerCase();

    // 1. 배터리 알림 ➔ 배터리 아이콘
    if (text.contains('배터리')) {
      return Icons.battery_alert_rounded;
    }
    
    // 2. 월간 리포트 ➔ 차트 아이콘
    if (text.contains('월간')) {
      return Icons.insert_chart_outlined;
    }

    // 3. 일간 리포트 ➔ 캘린더 아이콘
    if (text.contains('일간') || text.contains('일일')) {
      return Icons.calendar_today_rounded;
    }

    // 4. 교정 시간 / 측정 시간 / 시간 관련 알림 ➔ 모던 타이머 시계 아이콘!
    if (text.contains('시간') || text.contains('분')) {
      return Icons.timer_outlined;
    }

    // 5. 공지사항 ➔ 공지 아이콘
    if (text.contains('공지') || text.contains('점검')) {
      return Icons.notifications_active_rounded;
    }

    // 6. 스트레칭, 거북목 자세 경고, 기본 알림 ➔ 사람 모양 아이콘
    return Icons.accessibility_new_rounded;
  }

  String _formatDate(String createdAt) {
    if (createdAt.isEmpty) return '';
    try {
      String isoStr = createdAt.replaceAll(" ", "T");
      if (!isoStr.endsWith("Z") && !isoStr.contains("+")) {
        isoStr += "Z";
      }
      final dt = DateTime.parse(isoStr).toLocal();

      final month = dt.month.toString().padLeft(2, '0');
      final day = dt.day.toString().padLeft(2, '0');
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');

      return "$month/$day $hour:$minute";
    } catch (e) {
      debugPrint("❌ 날짜 변환 에러: $e");
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "알림",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.black),
              onPressed: _showDeleteDialog,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text("알림이 없어요", style: TextStyle(color: Colors.grey)))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  itemBuilder: (context, index) {
                    final n       = _notifications[index];
                    final isRead  = n['is_read'] == true;
                    final type    = n['type'] as String? ?? '';
                    final content = n['content'] as String? ?? '';
                    final id      = n['notification_id'] as int;

                    return GestureDetector(
                      onTap: () {
                        if (!isRead) _markAsRead(id, index);
                      },
                      child: Container(
                        color: isRead ? Colors.white : const Color(0xFFF6F9F5),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: isRead ? Colors.grey.shade100 : const Color(0xFFE8F5E9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getIcon(type, content),
                                color: isRead ? Colors.grey : TColor.buttonGreen,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    content,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                      color: isRead ? Colors.grey.shade700 : Colors.black,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _formatDate(n['created_at'] ?? ''),
                                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                  ),
                                ],
                              ),
                            ),
                            if (!isRead)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, left: 8),
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: TColor.buttonGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}