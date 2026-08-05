import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'posture_api_service.dart';

class CollectionView extends StatefulWidget {
  const CollectionView({super.key});

  @override
  State<CollectionView> createState() => _CollectionViewState();
}

class _CollectionViewState extends State<CollectionView> {
  List<Map<String, dynamic>> _allBookmarkedVideos = [];
  List<Map<String, dynamic>> _filteredVideos = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchBookmarkedVideos();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // 서버로부터 저장된 영상 목록 가져오기
  Future<void> _fetchBookmarkedVideos() async {
    setState(() => _isLoading = true);
    final list = await ApiService().getBookmarkedVideos();
    if (mounted) {
      setState(() {
        _allBookmarkedVideos = List<Map<String, dynamic>>.from(list);
        _applySearchFilter();
        _isLoading = false;
      });
    }
  }

  // 검색어 필터링 처리
  void _onSearchChanged() {
    setState(() {
      _applySearchFilter();
    });
  }

  void _applySearchFilter() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      _filteredVideos = List.from(_allBookmarkedVideos);
    } else {
      _filteredVideos = _allBookmarkedVideos.where((video) {
        final title = (video['title'] ?? '').toString().toLowerCase();
        return title.contains(query);
      }).toList();
    }
  }

  // 북마크 삭제/토글 처리
  Future<void> _removeBookmark(Map<String, dynamic> video) async {
    final rawId = video['video_id'] ?? video['videoId'] ?? video['id'];
    if (rawId == null) return;

    final int videoId = rawId is int ? rawId : int.parse(rawId.toString());

    // 먼저 UI에서 삭제 처리
    setState(() {
      _allBookmarkedVideos.removeWhere((v) {
        final vId = v['video_id'] ?? v['videoId'] ?? v['id'];
        return vId.toString() == videoId.toString();
      });
      _applySearchFilter();
    });

    final resultState = await ApiService().toggleBookmark(videoId);

    // 삭제 실패 등의 경우 서버 목록 재조회
    if (resultState == true) {
      _fetchBookmarkedVideos();
    }
  }

  void _launchYoutube(String videoId) async {
    if (videoId.isEmpty) return;
    final Uri url = Uri.parse("https://www.youtube.com/watch?v=$videoId");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("유튜브 실행 실패");
    }
  }

  // 날짜 문자열 포맷팅 (2026-03-10 -> 2026년 3월 10일)
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "저장된 영상";
    try {
      final DateTime parsed = DateTime.parse(dateStr);
      return "${parsed.year}년 ${parsed.month}월 ${parsed.day}일";
    } catch (_) {
      return dateStr;
    }
  }

  // 날짜별로 영상 데이터 그룹화
  Map<String, List<Map<String, dynamic>>> _groupVideosByDate(
    List<Map<String, dynamic>> videos,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var video in videos) {
      final dateKey =
          (video['bookmarked_at'] ??
                  video['bookmarkedAt'] ??
                  video['created_at'] ??
                  '기타')
              .toString();
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(video);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedVideos = _groupVideosByDate(_filteredVideos);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "저장한 영상",
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Pretendard',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFD9D9D9), height: 1.0),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // 1. 안내 문구 & 검색창
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        const Text(
                          'EXERCISE ZONE에서 저장한 영상이에요!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF818181),
                            fontSize: 14,
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 검색창
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFF818181)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(fontSize: 15),
                            decoration: const InputDecoration(
                              hintText: '검색어를 입력하세요',
                              hintStyle: TextStyle(
                                color: Color(0xFF818181),
                                fontSize: 15,
                                fontFamily: 'Pretendard',
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Color(0xFF818181),
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // 2. 검색 결과가 없을 때 / 저장된 영상이 없을 때
                if (_filteredVideos.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text(
                        _searchController.text.isEmpty
                            ? "저장된 영상이 없습니다."
                            : "검색 결과가 없습니다.",
                        style: const TextStyle(
                          color: Color(0xFF818181),
                          fontSize: 16,
                          fontFamily: 'Pretendard',
                        ),
                      ),
                    ),
                  )
                else
                  // 3. 날짜별 그룹화 그리드 리스트
                  ...groupedVideos.entries.expand((entry) {
                    final dateString = entry.key;
                    final videosInDate = entry.value;

                    return [
                      // 날짜 헤더
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 20,
                            right: 20,
                            bottom: 12,
                            top: 8,
                          ),
                          child: Text(
                            _formatDate(dateString),
                            style: const TextStyle(
                              color: Color(0xFF7D7D7D),
                              fontSize: 14,
                              fontFamily: 'Pretendard',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      // 2열 그리드 배치
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 14,
                                childAspectRatio: 1.0,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final video = videosInDate[index];
                            return _buildVideoCard(video);
                          }, childCount: videosInDate.length),
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ];
                  }),
              ],
            ),
    );
  }

  // 개별 운동 영상 카드 위젯
  Widget _buildVideoCard(Map<String, dynamic> video) {
    final youtubeKey =
        (video['youtube_video_key'] ?? video['youtubeVideoKey'] ?? '')
            as String;
    final title = (video['title'] ?? '') as String;
    final duration = (video['duration'] ?? video['play_time'] ?? '') as String;

    String thumbnailUrl =
        (video['thumbnail_url'] ?? video['thumbnailUrl'] ?? '') as String;
    if (thumbnailUrl.isEmpty && youtubeKey.isNotEmpty) {
      thumbnailUrl = 'https://img.youtube.com/vi/$youtubeKey/hqdefault.jpg';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 썸네일 영역 + 북마크 아이콘 + 재생시간
        Expanded(
          child: InkWell(
            onTap: () => _launchYoutube(youtubeKey),
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                // 썸네일 이미지
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: const Color(0xFFF0F4F0),
                    child: thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: thumbnailUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => const Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                color: Color(0xFF3B5524),
                                size: 32,
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              color: Color(0xFF3B5524),
                              size: 32,
                            ),
                          ),
                  ),
                ),

                // 중앙 재생 버튼 아이콘
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),

                // 우측 상단 북마크 아이콘
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _removeBookmark(video),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.bookmark,
                        color: Color(0xFF3B5524),
                        size: 18,
                      ),
                    ),
                  ),
                ),

                // 우측 하단 영상 길이 (Duration)
                if (duration.isNotEmpty)
                  Positioned(
                    bottom: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        duration,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        // 제목 (1줄 초과 시 ... 생략 처리)
        InkWell(
          onTap: () => _launchYoutube(youtubeKey),
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontFamily: 'Pretendard',
              fontWeight: FontWeight.w400,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
