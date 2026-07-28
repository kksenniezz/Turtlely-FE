import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'posture_api_service.dart';

class CollectionView extends StatefulWidget {
  const CollectionView({super.key});

  @override
  State<CollectionView> createState() => _CollectionViewState();
}

class _CollectionViewState extends State<CollectionView> {
  List<Map<String, dynamic>> _bookmarkedVideos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBookmarkedVideos();
  }

  // 서버로부터 저장된 영상 목록 가져오기
  Future<void> _fetchBookmarkedVideos() async {
    setState(() => _isLoading = true);
    final list = await ApiService().getBookmarkedVideos();
    if (mounted) {
      setState(() {
        _bookmarkedVideos = List<Map<String, dynamic>>.from(list);
        _isLoading = false;
      });
    }
  }

  // 북마크 삭제/토글 처리
  Future<void> _removeBookmark(Map<String, dynamic> video, int index) async {
    final rawId = video['video_id'] ?? video['videoId'] ?? video['id'];
    if (rawId == null) return;

    final int videoId = rawId is int ? rawId : int.parse(rawId.toString());

    // 먼저 UI에서 삭제 처리
    setState(() {
      _bookmarkedVideos.removeAt(index);
    });

    final resultState = await ApiService().toggleBookmark(videoId);

    // 만약 삭제 실패하여 여전히 북마크 상태라면 목록 다시 불러오기
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "저장한 영상",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookmarkedVideos.isEmpty
          ? const Center(child: Text("저장된 영상이 없습니다."))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _bookmarkedVideos.length,
              itemBuilder: (context, index) {
                final v = _bookmarkedVideos[index];
                final youtubeKey =
                    (v['youtube_video_key'] ?? v['youtubeVideoKey'] ?? '')
                        as String;
                final title = (v['title'] ?? '') as String;
                final duration =
                    v['duration_minutes'] ?? v['durationMinutes'] ?? 0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () => _launchYoutube(youtubeKey),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 100,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                color: Color(0xFF3B5524),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "$duration분 영상",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _removeBookmark(v, index),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(
                                Icons.bookmark,
                                color: Color(0xFF3B5524),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
