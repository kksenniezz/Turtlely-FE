import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

// 운동 리포트의 "시청한 영상"을 누르면 들어오는 화면.
// GET /api/exercise/history/monthly/detail (year, month) 로
// 선택한 달에 시청한 영상을 날짜별로 보여준다.
class ExerciseWatchedVideosView extends StatefulWidget {
  final DateTime month;
  const ExerciseWatchedVideosView({super.key, required this.month});

  @override
  State<ExerciseWatchedVideosView> createState() => _ExerciseWatchedVideosViewState();
}

class _ExerciseWatchedVideosViewState extends State<ExerciseWatchedVideosView> {
  static const String _baseUrl = "http://54.144.66.35.nip.io:8080";
  static const Color _primaryGreen = Color(0xFF3B5524);
  static const Color _lightBg = Color(0xFFEDF1E9);

  final _storage = const FlutterSecureStorage();

  bool _isLoading = true;
  String? _errorMessage;

  // [{ 'date': '2026-08-28', 'videos': [ {...}, ... ] }, ...]  최신 날짜가 위
  List<Map<String, dynamic>> _days = [];
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _storage.read(key: 'accessToken');
      final uri = Uri.parse(
        "$_baseUrl/api/exercise/history/monthly/detail"
        "?year=${widget.month.year}&month=${widget.month.month}",
      );

      final response = await http.get(
        uri,
        headers: {
          "Content-Type": "application/json",
          if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        final result = Map<String, dynamic>.from(jsonResponse['result'] ?? {});
        final historyList = (result['history_list'] as List? ?? []);

        final days = <Map<String, dynamic>>[];
        for (final e in historyList) {
          final day = Map<String, dynamic>.from(e);
          final videos = (day['videos'] as List? ?? [])
              .map((v) => Map<String, dynamic>.from(v))
              .toList();
          // 같은 날 안에서는 최근에 본 것이 위로
          videos.sort((a, b) =>
              (b['watched_at'] as String? ?? '').compareTo(a['watched_at'] as String? ?? ''));
          days.add({
            'date': day['watched_date'] as String? ?? '',
            'videos': videos,
          });
        }
        days.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

        if (!mounted) return;
        setState(() {
          _days = days;
          _total = (result['total_watched_count'] as int?) ??
              days.fold<int>(0, (sum, d) => sum + (d['videos'] as List).length);
        });
      } else if (response.statusCode == 400) {
        setState(() => _errorMessage = "잘못된 연도 또는 월입니다.");
      } else if (response.statusCode == 401) {
        setState(() => _errorMessage = "로그인이 만료되었어요. 다시 로그인해 주세요.");
      } else {
        setState(() => _errorMessage = "시청한 영상을 불러오지 못했습니다.");
      }
    } catch (e) {
      debugPrint("시청 영상 목록 조회 오류: $e");
      if (mounted) setState(() => _errorMessage = "네트워크 연결을 확인해 주세요.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _launchYoutube(String videoKey) async {
    if (videoKey.isEmpty) return;
    final Uri url = Uri.parse("https://www.youtube.com/watch?v=$videoKey");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("유튜브 실행 실패");
    }
  }

  String _dayLabel(String day) {
    final p = day.split('-');
    if (p.length != 3) return day;
    return "${int.parse(p[1])}월 ${int.parse(p[2])}일";
  }

  // "2026-08-28T21:45:00" → "21:45"
  String _timeLabel(String watchedAt) {
    final idx = watchedAt.indexOf('T');
    if (idx == -1 || watchedAt.length < idx + 6) return '';
    return watchedAt.substring(idx + 1, idx + 6);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        title: const Text(
          "시청한 영상",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : _buildList(),
    );
  }

  Widget _buildList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Container(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _lightBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "${widget.month.year}년 ${widget.month.month}월 · $_total개",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _primaryGreen,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_days.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 60),
            child: Center(
              child: Text(
                "이 달에 시청한 영상이 없어요.",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ),
        for (final day in _days) ...[
          Text(
            _dayLabel(day['date'] as String),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _primaryGreen, width: 1.2),
            ),
            child: Column(
              children: [
                for (int i = 0; i < (day['videos'] as List).length; i++) ...[
                  _buildVideoItem((day['videos'] as List)[i] as Map<String, dynamic>),
                  if (i != (day['videos'] as List).length - 1)
                    const Divider(height: 1, thickness: 1, color: Color(0xFFEFF3EC)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Widget _buildVideoItem(Map<String, dynamic> video) {
    final thumbnailUrl = video['thumbnail_url'] as String? ?? '';
    final youtubeKey = video['youtube_video_key'] as String? ?? '';
    final title = video['title'] as String? ?? '';
    final duration = video['duration_minutes'] ?? 0;
    final time = _timeLabel(video['watched_at'] as String? ?? '');
    final isBookmarked = video['is_bookmarked'] == true;

    Widget placeholder() => Container(
          width: 88,
          height: 60,
          color: const Color(0xFFF0F4F0),
          child: const Icon(Icons.play_circle_fill, color: Colors.white70),
        );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _launchYoutube(youtubeKey),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      width: 88,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => placeholder(),
                      errorWidget: (_, __, ___) => placeholder(),
                    )
                  : placeholder(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time.isNotEmpty ? "$time 시청 · ${duration}분" : "${duration}분",
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (isBookmarked)
              const Padding(
                padding: EdgeInsets.only(left: 6, top: 2),
                child: Icon(Icons.bookmark, size: 18, color: _primaryGreen),
              ),
          ],
        ),
      ),
    );
  }
}