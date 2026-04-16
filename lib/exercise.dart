import 'package:flutter/material.dart';
import 'style.dart';

class ExerciseView extends StatefulWidget {
  @override
  _ExerciseViewState createState() => _ExerciseViewState();
}

class _ExerciseViewState extends State<ExerciseView> {
  String selectedType = "전체";
  String selectedBody = "스트레칭";
  String selectedTime = "3분";

  final List<Map<String, dynamic>> _exerciseVideos = [
    {
      "title": "10분 거북목 교정 루틴",
      "subtitle": "딱 10분! 거북목, 버섯증후군이 있다면 이 운동 제발...",
      "image": "assets/exercise_sample.png",
      "isBookmarked": false,
    },
    {
      "title": "목, 어깨 아픈 곳을 시원하게...",
      "subtitle": "재활의학과 전문의가 알려주는 10분 스트레칭",
      "image": "assets/exercise_sample2.png",
      "isBookmarked": false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // 1. 헤더 영역
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("EXERCISE ZONE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: TColor.black)),
                      const SizedBox(height: 4),
                      Text("@@님의 거북목 완화에 도움이 되는 영상이에요!", style: TextStyle(color: TColor.gray, fontSize: 12)),
                    ],
                  ),
                  // 상단 북마크: 민영님 요청대로 항상 색칠된(Icons.bookmark) 상태로 고정!
                  GestureDetector(
                    onTap: () {
                      // 누르면 '저장한 영상' 페이지(CollectionView)로 이동
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CollectionView()),
                      );
                    },
                    child: const Icon(
                      Icons.bookmark, // 항상 채워진 아이콘
                      color: TColor.darkGreen, 
                      size: 28
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // 2. 검색창 (생략)
              TextField(
                decoration: InputDecoration(
                  hintText: '검색어를 입력하세요',
                  prefixIcon: const Icon(Icons.search, color: TColor.gray),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),

              // 3. 필터 영역 (생략)
              Row(
                children: [
                  _buildDropdownFilter("거북목 유형", ["전체", "거북목", "일자목", "역C자목"], selectedType, (val) => setState(() => selectedType = val)),
                  const SizedBox(width: 8),
                  _buildDropdownFilter("운동 종류", ["스트레칭", "도수치료", "헬스"], selectedBody, (val) => setState(() => selectedBody = val)),
                  const SizedBox(width: 8),
                  _buildDropdownFilter("시간", ["3분", "10분", "20분"], selectedTime, (val) => setState(() => selectedTime = val)),
                ],
              ),
              const SizedBox(height: 24),

              // 4. 영상 리스트
              ..._exerciseVideos.asMap().entries.map((entry) {
                int index = entry.key;
                var video = entry.value;
                return _buildExerciseCard(
                  index: index,
                  title: video['title'],
                  subtitle: video['subtitle'],
                  imagePath: video['image'],
                  isBookmarked: video['isBookmarked'],
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleBookmark(int index) {
    setState(() {
      _exerciseVideos[index]['isBookmarked'] = !_exerciseVideos[index]['isBookmarked'];
    });
  }

  Widget _buildExerciseCard({required int index, required String title, required String subtitle, required String imagePath, required bool isBookmarked}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFFF0F4F0),
                image: DecorationImage(image: AssetImage(imagePath), fit: BoxFit.cover),
              ),
            ),
            Positioned(
              right: 12, bottom: 12,
              child: GestureDetector(
                onTap: () => _toggleBookmark(index),
                child: CircleAvatar(
                  backgroundColor: Colors.white.withOpacity(0.9),
                  radius: 18,
                  child: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    size: 20,
                    color: TColor.darkGreen,
                  ),
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: TColor.gray, fontSize: 13)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDropdownFilter(String label, List<String> items, String currentVal, Function(String) onSelected) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => items.map((item) => PopupMenuItem(value: item, child: Text(item))).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFF0F4F0), borderRadius: BorderRadius.circular(20)),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 13, color: TColor.darkGreen, fontWeight: FontWeight.w600)),
            const Icon(Icons.arrow_drop_down, color: TColor.darkGreen),
          ],
        ),
      ),
    );
  }
}

// --- 새 파일로 만드셔도 되고, exercise.dart 맨 아래 붙여넣으셔도 됩니다 ---
class CollectionView extends StatelessWidget {
  const CollectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("저장한 영상", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: const Center(child: Text("저장된 영상이 여기에 나타납니다!")),
    );
  }
}