import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

// 운동 존 화면(exercise.dart)의 오른쪽 하단 버튼을 통해 진입하는
// "운동 리포트" 화면. GET /api/exercise/history/monthly(year, month)를 호출해서
// - 이번 달 이용 기록(시청 횟수/시청한 영상/저장한 영상)
// - 가장 많이 본 영상
// - 다음 달 추천 영상(비슷한 영상 / 새로운 영상)
// 을 표시한다.
class ExerciseReportView extends StatefulWidget {
  const ExerciseReportView({super.key});

  @override
  State<ExerciseReportView> createState() => _ExerciseReportViewState();
}

class _ExerciseReportViewState extends State<ExerciseReportView> {
  static const String _baseUrl = "http://54.144.66.35.nip.io:8080";
  static const Color _primaryGreen = Color(0xFF3B5524);
  static const Color _lightBg = Color(0xFFEDF1E9);

  final _storage = const FlutterSecureStorage();

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic> _usageSummary = {};
  Map<String, dynamic>? _mostWatchedVideo;
  List<Map<String, dynamic>> _similarVideos = [];
  List<Map<String, dynamic>> _newVideos = [];

  // ✅ 연도 드롭다운 후보. 기록이 있는 연도만 서버에서 별도로 내려주지 않는 한,
  //    현재 연도 기준 최근 3개년을 기본 후보로 노출함.
  late final List<int> _availableYears;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _availableYears = List.generate(3, (i) => now.year - i);
    _fetchMonthlyStats();
  }

  Future<void> _fetchMonthlyStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _storage.read(key: 'accessToken');
      final uri = Uri.parse(
        "$_baseUrl/api/exercise/history/monthly"
        "?year=${_selectedMonth.year}&month=${_selectedMonth.month}",
      );

      final response = await http.get(
        uri,
        headers: {
          "Content-Type": "application/json",
          if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final result = Map<String, dynamic>.from(jsonResponse['result'] ?? {});

        final recommendations = Map<String, dynamic>.from(
          result['recommendations'] ?? {},
        );

        setState(() {
          _usageSummary = Map<String, dynamic>.from(
            result['usage_summary'] ?? {},
          );
          _mostWatchedVideo = result['most_watched_video'] != null
              ? Map<String, dynamic>.from(result['most_watched_video'])
              : null;
          _similarVideos = List<Map<String, dynamic>>.from(
            (recommendations['similar_videos'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e)),
          );
          _newVideos = List<Map<String, dynamic>>.from(
            (recommendations['new_videos'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e)),
          );
        });
      } else if (response.statusCode == 400) {
        setState(() {
          _errorMessage = "잘못된 연도 또는 월입니다.";
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _errorMessage = "로그인이 만료되었어요. 다시 로그인해 주세요.";
        });
      } else {
        setState(() {
          _errorMessage = "운동 리포트를 불러오지 못했습니다.";
        });
      }
    } catch (e) {
      debugPrint("운동 가이드 월별 통계 조회 오류: $e");
      setState(() {
        _errorMessage = "네트워크 연결을 확인해 주세요.";
      });
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

  Future<void> _pickMonth() async {
    int selectedYear = _selectedMonth.year;
    int selectedMonthValue = _selectedMonth.month;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "조회할 연월 선택",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        DropdownButton<int>(
                          value: selectedYear,
                          items: _availableYears
                              .map((y) => DropdownMenuItem(
                                    value: y,
                                    child: Text("$y년"),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedYear = v!),
                        ),
                        const SizedBox(width: 20),
                        DropdownButton<int>(
                          value: selectedMonthValue,
                          items: List.generate(12, (i) => i + 1)
                              .map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text("$m월"),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => selectedMonthValue = v!),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text("취소"),
                          ),
                        ),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(dialogContext);
                              setState(() {
                                _selectedMonth =
                                    DateTime(selectedYear, selectedMonthValue);
                              });
                              _fetchMonthlyStats();
                            },
                            child: const Text(
                              "확인",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
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
          "운동 리포트",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
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
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMonthSelector(),
                      const SizedBox(height: 20),
                      const Text(
                        "이번 달 이용 기록",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      _buildUsageSummaryCard(),
                      const SizedBox(height: 28),
                      if (_mostWatchedVideo != null) ...[
                        const Text(
                          "가장 많이 본 영상",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        _buildMostWatchedCard(_mostWatchedVideo!),
                        const SizedBox(height: 28),
                      ],
                      const Text(
                        "다음 달 추천 영상",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      if (_similarVideos.isNotEmpty) ...[
                        const Text(
                          "자주 본 영상과 비슷한 영상",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        _buildRecommendationBox(_similarVideos),
                        const SizedBox(height: 20),
                      ],
                      if (_newVideos.isNotEmpty) ...[
                        const Text(
                          "새로운 운동도 해보세요",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        _buildRecommendationBox(_newVideos),
                      ],
                      if (_similarVideos.isEmpty && _newVideos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            "추천할 영상이 아직 없어요.",
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  // 연/월 선택 영역
  Widget _buildMonthSelector() {
    return Row(
      children: [
        _buildMonthChip("${_selectedMonth.year}년"),
        const SizedBox(width: 8),
        _buildMonthChip("${_selectedMonth.month}월"),
      ],
    );
  }

  Widget _buildMonthChip(String label) {
    return GestureDetector(
      onTap: _pickMonth,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _lightBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: _primaryGreen,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: _primaryGreen, size: 20),
          ],
        ),
      ),
    );
  }

  // "이번 달 이용 기록" 카드 (흰 배경 + 초록 테두리, 점선 리더 스타일)
  Widget _buildUsageSummaryCard() {
    final totalWatch = _usageSummary['total_watch_count'] ?? 0;
    final watchedCount = _usageSummary['watched_video_count'] ?? 0;
    final savedCount = _usageSummary['saved_video_count'] ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryGreen, width: 1.2),
      ),
      child: Column(
        children: [
          _buildDottedRow("영상 시청 횟수", "$totalWatch회"),
          const SizedBox(height: 10),
          _buildDottedRow("시청한 영상", "$watchedCount개"),
          const SizedBox(height: 10),
          // ✅ 변경: "저장한 영상" → "북마크한 영상"
          _buildDottedRow("북마크한 영상", "$savedCount개"),
        ],
      ),
    );
  }

  Widget _buildDottedRow(String label, String value) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "·" * 60,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: const TextStyle(color: Color(0xFFBFC7BB), letterSpacing: 1),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primaryGreen),
        ),
      ],
    );
  }

  // "가장 많이 본 영상" 카드 (흰 배경 + 초록 테두리)
  Widget _buildMostWatchedCard(Map<String, dynamic> video) {
    final thumbnailUrl = video['thumbnail_url'] as String? ?? '';
    final youtubeKey = video['youtube_video_key'] as String? ?? '';
    final title = video['title'] as String? ?? '';
    final category = video['category'] as String? ?? '';
    final watchCount = video['watch_count'] ?? 0;

    return GestureDetector(
      onTap: () => _launchYoutube(youtubeKey),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _primaryGreen, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        height: 180,
                        color: const Color(0xFFF0F4F0),
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        height: 180,
                        color: const Color(0xFFF0F4F0),
                        child: const Center(
                          child: Icon(Icons.play_circle_fill, size: 48, color: Colors.white70),
                        ),
                      ),
                    )
                  : Container(
                      height: 180,
                      color: const Color(0xFFF0F4F0),
                      child: const Center(
                        child: Icon(Icons.play_circle_fill, size: 48, color: Colors.white70),
                      ),
                    ),
            ),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              "카테고리: #$category",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              "이번 달 시청: $watchCount회",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ 추가: "자주 본 영상과 비슷한 영상" / "새로운 운동" 섹션을 각각
  //    영상마다 따로 박스를 만들지 않고, 섹션당 흰 배경+초록 테두리 박스
  //    하나 안에 영상들을 구분선으로 나눠서 함께 담음.
  Widget _buildRecommendationBox(List<Map<String, dynamic>> videos) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _primaryGreen, width: 1.2),
      ),
      child: Column(
        children: [
          for (int i = 0; i < videos.length; i++) ...[
            _buildRecommendationItem(videos[i]),
            if (i != videos.length - 1)
              const Divider(height: 1, thickness: 1, color: Color(0xFFEFF3EC)),
          ],
        ],
      ),
    );
  }

  // 박스 안에 들어가는 영상 한 줄(썸네일 + 텍스트). 자체 테두리는 없고
  // _buildRecommendationBox가 감싸는 흰 박스 안에서 구분선으로만 구분됨.
  Widget _buildRecommendationItem(Map<String, dynamic> video) {
    final thumbnailUrl = video['thumbnail_url'] as String? ?? '';
    final youtubeKey = video['youtube_video_key'] as String? ?? '';
    final title = video['title'] as String? ?? '';
    final category = video['category'] as String? ?? '';
    final duration = video['duration_minutes'] ?? 0;

    return GestureDetector(
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
                      placeholder: (_, __) => Container(
                        width: 88,
                        height: 60,
                        color: const Color(0xFFF0F4F0),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 88,
                        height: 60,
                        color: const Color(0xFFF0F4F0),
                        child: const Icon(Icons.play_circle_fill, color: Colors.white70),
                      ),
                    )
                  : Container(
                      width: 88,
                      height: 60,
                      color: const Color(0xFFF0F4F0),
                      child: const Icon(Icons.play_circle_fill, color: Colors.white70),
                    ),
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
                    "#$category · ${duration}분",
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