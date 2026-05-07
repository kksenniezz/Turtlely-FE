import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CollectionView extends StatefulWidget {
  final List<Map<String, dynamic>> savedVideos;

  const CollectionView({super.key, required this.savedVideos});

  @override
  State<CollectionView> createState() => _CollectionViewState();
}

class _CollectionViewState extends State<CollectionView> {
  
  void _launchYoutube(String videoId) async {
    final Uri url = Uri.parse("https://www.youtube.com/watch?v=$videoId");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("유튜브 실행 실패");
    }
  }

  @override
  Widget build(BuildContext context) {
    // 실시간으로 북마크된 항목만 필터링
    final bookmarkedList = widget.savedVideos.where((v) => v['isBookmarked'] == true).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("저장한 영상", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: bookmarkedList.isEmpty
          ? const Center(child: Text("저장된 영상이 없습니다."))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: bookmarkedList.length,
              itemBuilder: (context, index) {
                final v = bookmarkedList[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InkWell( 
                    onTap: () => _launchYoutube(v['videoId']), // 💡 칸 누르면 유튜브 재생
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
                            width: 100, height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F4F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(child: Icon(Icons.play_circle_outline, color: Color(0xFF3B5524))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(v['title'], 
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1, overflow: TextOverflow.ellipsis
                                ),
                                const SizedBox(height: 4),
                                Text(v['subtitle'], 
                                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  maxLines: 1, overflow: TextOverflow.ellipsis
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                v['isBookmarked'] = false; // 💡 여기서 삭제하면 외부 static 리스트도 연동됨
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.bookmark, color: Color(0xFF3B5524)),
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