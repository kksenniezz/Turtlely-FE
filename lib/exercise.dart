import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'style.dart';
import 'collection.dart';
import 'guide.dart';

class ExerciseView extends StatefulWidget {
  const ExerciseView({super.key});

  static List<Map<String, dynamic>> exerciseVideos = [
    {
      "title": "딱 10분! 거북목, 버섯증후군이 있다면 이 운동 제발...",
      "subtitle": "거북목 완화에 도움이 되는 루틴이에요.",
      "image": "assets/exercise_sample.png",
      "isBookmarked": false,
      "videoId": "dQw4w9WgXcQ", 
      "type": "거북목", "body": "스트레칭", "time": "10분"
    },
    {
      "title": "목, 어깨 아픈 곳을 시원하게... (재활전문의 추천)",
      "subtitle": "재활의학과 전문의가 알려주는 10분 스트레칭",
      "image": "assets/exercise_sample2.png",
      "isBookmarked": false,
      "videoId": "wW7SFFpU91o",
      "type": "일자목", "body": "도수치료", "time": "20분"
    },
  ];

  @override
  _ExerciseViewState createState() => _ExerciseViewState();
}

class _ExerciseViewState extends State<ExerciseView> {
  String selectedType = "거북목 유형";
  String selectedBody = "운동 종류";
  String selectedTime = "시간";
  String _searchQuery = "";

  List<Map<String, dynamic>> get _filteredVideos {
    return ExerciseView.exerciseVideos.where((v) {
      final titleMatch = v['title'].contains(_searchQuery);
      final typeMatch = selectedType == "거북목 유형" || selectedType == "전체" || v['type'] == selectedType;
      final bodyMatch = selectedBody == "운동 종류" || selectedBody == "전체" || v['body'] == selectedBody;
      final timeMatch = selectedTime == "시간" || selectedTime == "전체" || v['time'] == selectedTime;
      return titleMatch && typeMatch && bodyMatch && timeMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // --- 상단 완전 고정 영역 (타이틀 & 가이드 가기 버튼) ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("EXERCISE ZONE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          SizedBox(height: 4),
                          Text("거북목 완화에 도움이 되는 영상이에요!", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.bookmark, color: Color(0xFF3B5524), size: 28),
                        onPressed: () async {
                          await Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => CollectionView(savedVideos: ExerciseView.exerciseVideos))
                          );
                          setState(() {}); 
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GuideView())),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFEDF1E9)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: const Text("거북목 교정 스트레칭 가이드 >", style: TextStyle(color: Color(0xFF3B5524), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            // --- 하단 스크롤 영역 (검색창 + 필터 + 영상 리스트) ---
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      // 💡 검색창 (리스트와 함께 스크롤되어 올라감)
                      TextField(
                        onChanged: (v) => setState(() => _searchQuery = v),
                        decoration: InputDecoration(
                          hintText: '검색어를 입력하세요',
                          prefixIcon: const Icon(Icons.search),
                          filled: true, fillColor: const Color(0xFFF5F5F5),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // 💡 필터 영역 (리스트와 함께 스크롤되어 올라감)
                      Row(
                        children: [
                          _buildFilter(["전체", "거북목", "일자목", "역C자목"], selectedType, 115, (v) => setState(() => selectedType = v!)),
                          const SizedBox(width: 8),
                          _buildFilter(["전체", "스트레칭", "도수치료", "헬스"], selectedBody, 105, (v) => setState(() => selectedBody = v!)),
                          const SizedBox(width: 8),
                          _buildFilter(["전체", "3분", "10분", "20분"], selectedTime, 85, (v) => setState(() => selectedTime = v!)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // 영상 리스트들
                      if (_filteredVideos.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.only(top: 40), child: Text("해당하는 영상이 없습니다.")))
                      else
                        ..._filteredVideos.map((v) => _buildVideoCard(v)).toList(),
                      const SizedBox(height: 50),
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

  // --- 기존 필터 및 카드 위젯 함수들 동일 ---
  Widget _buildFilter(List<String> items, String current, double width, Function(String?) onSelect) {
    return PopupMenuButton<String>(
      onSelected: onSelect,
      color: const Color(0xFFEDF1E9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (c) => items.map((i) => PopupMenuItem(value: i, child: Text(i))).toList(),
      child: Container(
        width: width, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFFEDF1E9), borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(child: Text(current, style: const TextStyle(fontSize: 13, color: Color(0xFF3B5524), fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            const Icon(Icons.arrow_drop_down, color: Color(0xFF3B5524)),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            GestureDetector(
              onTap: () => _launchYoutube(v['videoId']), 
              child: Container(
                height: 190, width: double.infinity,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: const Color(0xFFF0F4F0)),
                child: const Center(child: Icon(Icons.play_circle_fill, size: 56, color: Colors.white70)),
              ),
            ),
            Positioned(
              right: 12, bottom: 12,
              child: GestureDetector(
                onTap: () => setState(() => v['isBookmarked'] = !v['isBookmarked']),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Icon(v['isBookmarked'] ? Icons.bookmark : Icons.bookmark_border, color: const Color(0xFF3B5524), size: 24),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(v['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 4),
        Text(v['subtitle'], style: const TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 24),
      ],
    );
  }

  void _launchYoutube(String videoId) async {
    final Uri url = Uri.parse("https://www.youtube.com/watch?v=$videoId");
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint("유튜브 실행 실패");
    }
  }
}