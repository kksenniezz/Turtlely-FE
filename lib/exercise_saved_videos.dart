import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

class ExerciseSavedVideosView extends StatefulWidget {
  final DateTime month;
  const ExerciseSavedVideosView({super.key, required this.month});

  @override
  State<ExerciseSavedVideosView> createState() => _ExerciseSavedVideosViewState();
}

class _ExerciseSavedVideosViewState extends State<ExerciseSavedVideosView> {
  static const String _baseUrl = "http://54.144.66.35.nip.io:8080";
  static const Color _primaryGreen = Color(0xFF3B5524);
  static const Color _lightBg = Color(0xFFEDF1E9);

  final _storage = const FlutterSecureStorage();

  bool _isLoading = true;
  String? _errorMessage;

  // 날짜(yyyy-MM-dd) → 그날 북마크한 영상들
  Map<String, List<Map<String, dynamic>>> _grouped = {};
  List<String> _days = []; // 최신 날짜가 위로 오게 정렬
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
      final response = await http.get(
        Uri.parse("$_baseUrl/api/exercise/bookmarks"),
        headers: {
          "Content-Type": "application/json",
          if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(utf8.decode(response.bodyBytes));
        final result = Map<String, dynamic>.from(jsonResponse['result'] ?? {});
        final list = (result['bookmark_list'] as List? ?? []);

        final monthPrefix =
            "${widget.month.year}-${widget.month.month.toString().padLeft(2, '0')}";

        final Map<String, List<Map<String, dynamic>>> grouped = {};
        int total = 0;
        for (final e in list) {
          final item = Map<String, dynamic>.from(e);
          final at = (item['bookmarked_at'] as String? ?? '');
          if (at.length < 10) continue;
          final day = at.substring(0, 10);
          if (!day.startsWith(monthPrefix)) continue; // 선택한 달만
          grouped.putIfAbsent(day, () => []).add(item);
          total++;
        }

        final days = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        if (!mounted) return;
        setState(() {
          _grouped = grouped;
          _days = days;
          _total = total;
        });
      } else if (response.statusCode == 401) {
        setState(() => _errorMessage = "로그인이 만료되었어요. 다시 로그인해 주세요.");
      } else {
        setState(() => _errorMessage = "북마크한 영상을 불러오지 못했습니다.");
      }
    } catch (e) {
      debugPrint("북마크 영상 목록 조회 오류: $e");
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
          "북마크한 영상",
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
                "이 달에 북마크한 영상이 없어요.",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ),
        for (final day in _days) ...[
          Text(
            _dayLabel(day),
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
                for (int i = 0; i < _grouped[day]!.length; i++) ...[
                  _buildVideoItem(_grouped[day]![i]),
                  if (i != _grouped[day]!.length - 1)
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
                    "${duration}분",
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}