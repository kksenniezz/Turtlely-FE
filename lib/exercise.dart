import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'guide.dart';
import 'collection.dart';
import 'posture_api_service.dart';
import 'exercise_onboarding_dialog.dart';

// ★ 온보딩 스팟라이트 위치 자동 추적용 GlobalKey ★
final GlobalKey exerciseBookmarkKey = GlobalKey();
final GlobalKey exerciseFabKey = GlobalKey();

class ExerciseView extends StatefulWidget {
  const ExerciseView({super.key});

  @override
  _ExerciseViewState createState() => _ExerciseViewState();
}

class _ExerciseViewState extends State<ExerciseView> {
  String selectedType = "유형";
  String selectedBody = "운동 종류";
  String selectedTime = "시간";
  String _searchQuery = "";

  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVideos();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ExerciseOnboardingDialog.checkAndShow(
        context,
        userName: "사용자",
        onComplete: () {
          debugPrint("운동존 온보딩 완료!");
        },
      );
    });
  }

  String _toPostureType(String v) {
    switch (v) {
      case '거북목':
        return 'TURTLE_NECK';
      case '일자목':
        return 'STRAIGHT_NECK';
      case '역C자목':
        return 'REVERSE_C';
      default:
        return 'ALL';
    }
  }

  String _toCategory(String v) {
    switch (v) {
      case '스트레칭':
        return 'STRETCHING';
      case '도수치료':
        return 'PHYSICAL_THERAPY';
      case '헬스':
        return 'FITNESS';
      default:
        return 'ALL';
    }
  }

  int? _toDurationMinutes(String v) {
    switch (v) {
      case '3분':
        return 3;
      case '10분':
        return 10;
      case '20분':
        return 20;
      default:
        return null;
    }
  }

  Future<void> _fetchVideos() async {
    setState(() => _isLoading = true);
    final api = ApiService();
    final result = await api.getExerciseVideos(
      postureType: _toPostureType(selectedType),
      category: _toCategory(selectedBody),
      durationMinutes: _toDurationMinutes(selectedTime),
      keyword: _searchQuery.isNotEmpty ? _searchQuery : null,
    );
    setState(() {
      _videos = List<Map<String, dynamic>>.from(result);
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredVideos {
    if (_searchQuery.isEmpty) return _videos;
    return _videos
        .where((v) => v['title'].toString().contains(_searchQuery))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: SizedBox(
        key: exerciseFabKey, // ★ 플로팅 버튼 위치 추적 키 연결
        width: 60,
        height: 60,
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const GuideView()),
            );
          },
          backgroundColor: const Color(0xFFE8F1DE),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.accessibility_new,
            color: Color(0xFF3B5524),
            size: 30,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 고정 헤더
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "EXERCISE ZONE",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "거북목 완화에 도움이 되는 영상이에요!",
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      IconButton(
                        key: exerciseBookmarkKey, // ★ 헤더 북마크 버튼 위치 추적 키 연결
                        icon: const Icon(
                          Icons.bookmark,
                          color: Color(0xFF3B5524),
                          size: 28,
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CollectionView(),
                            ),
                          );
                          _fetchVideos();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 검색창
                  TextField(
                    onChanged: (v) {
                      setState(() => _searchQuery = v);
                      _fetchVideos();
                    },
                    decoration: InputDecoration(
                      hintText: '검색어를 입력하세요',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 필터 드롭다운
                  Row(
                    children: [
                      Expanded(
                        child: _buildFilter(
                          ["유형", "전체", "거북목", "일자목", "역C자목"],
                          selectedType,
                          (v) {
                            setState(() => selectedType = v!);
                            _fetchVideos();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFilter(
                          ["운동 종류", "전체", "스트레칭", "도수치료", "헬스"],
                          selectedBody,
                          (v) {
                            setState(() => selectedBody = v!);
                            _fetchVideos();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFilter(
                          ["시간", "전체", "3분", "10분", "20분"],
                          selectedTime,
                          (v) {
                            setState(() => selectedTime = v!);
                            _fetchVideos();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 영상 리스트
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: Column(
                          children: [
                            if (_filteredVideos.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 40),
                                  child: Text("해당하는 영상이 없습니다."),
                                ),
                              )
                            else
                              ..._filteredVideos
                                  .map((v) => _buildVideoCard(v))
                                  .toList(),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilter(
    List<String> items,
    String current,
    Function(String?) onSelect,
  ) {
    return PopupMenuButton<String>(
      onSelected: onSelect,
      color: const Color(0xFFEDF1E9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (c) => items
          .skip(1)
          .map((i) => PopupMenuItem(value: i, child: Text(i)))
          .toList(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEDF1E9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                current,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF3B5524),
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: Color(0xFF3B5524)),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> v) {
    final isBookmarked =
        v['is_bookmarked'] == true || v['isBookmarked'] == true;
    final thumbnailUrl = v['thumbnailUrl'] as String? ?? '';
    final youtubeKey = v['youtubeVideoKey'] as String? ?? '';
    final duration = v['durationMinutes'] ?? v['duration_minutes'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: () => _launchYoutube(youtubeKey),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: thumbnailUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        height: 190,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          height: 190,
                          color: const Color(0xFFF0F4F0),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          height: 190,
                          color: const Color(0xFFF0F4F0),
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_fill,
                              size: 56,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        height: 190,
                        color: const Color(0xFFF0F4F0),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            size: 56,
                            color: Colors.white70,
                          ),
                        ),
                      ),
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                onTap: () => _launchYoutube(youtubeKey),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.black.withOpacity(0.1),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      size: 56,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: GestureDetector(
                onTap: () => _toggleBookmark(v),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: const Color(0xFF3B5524),
                    size: 24,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${duration}분",
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          v['title'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // 북마크 API 연동
  Future<void> _toggleBookmark(Map<String, dynamic> v) async {
    final rawId = v['videoId'] ?? v['video_id'] ?? v['id'];

    setState(() {
      final current = v['isBookmarked'] == true || v['is_bookmarked'] == true;
      v['isBookmarked'] = !current;
      v['is_bookmarked'] = !current;
    });

    if (rawId == null) return;
    final int videoId = rawId is int ? rawId : int.parse(rawId.toString());

    try {
      dynamic apiInstance = ApiService();
      var response = await apiInstance.toggleBookmark(videoId);
      if (response != null && response is bool && mounted) {
        setState(() {
          v['isBookmarked'] = response;
          v['is_bookmarked'] = response;
        });
      }
    } catch (_) {}
  }

  void _launchYoutube(String videoKey) async {
    if (videoKey.isEmpty) return;
    final Uri url = Uri.parse("https://www.youtube.com/watch?v=$videoKey");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("유튜브 실행 실패");
    }
  }
}
