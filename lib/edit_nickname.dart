import 'package:flutter/material.dart';
import 'style.dart';
import 'services/mypage_service.dart';

class EditNicknamePage extends StatefulWidget {
  const EditNicknamePage({super.key});

  @override
  State<EditNicknamePage> createState() => _EditNicknamePageState();
}

class _EditNicknamePageState extends State<EditNicknamePage> {
  final MyPageService _myPageService = MyPageService();
  final TextEditingController _nicknameController = TextEditingController();

  bool _isLoading = false;
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(_onNicknameChanged);
  }

  void _onNicknameChanged() {
    final isNotEmpty = _nicknameController.text.trim().isNotEmpty;
    if (_isButtonEnabled != isNotEmpty) {
      setState(() {
        _isButtonEnabled = isNotEmpty;
      });
    }
  }

  @override
  void dispose() {
    _nicknameController.removeListener(_onNicknameChanged);
    _nicknameController.dispose();
    super.dispose();
  }

  // 닉네임 변경 저장 API 실행
  Future<void> _handleSave() async {
    if (!_isButtonEnabled || _isLoading) return; // 비활성화 시 클릭 차단

    final newNickname = _nicknameController.text.trim();

    setState(() {
      _isLoading = true;
    });

    // 닉네임 변경 API 호출
    final success = await _myPageService.updateNickname(newNickname);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      _showEditCompleteDialog(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("닉네임 변경에 실패했습니다 다시 시도해 주세요.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "닉네임 변경",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          GestureDetector(
            onTap: _isButtonEnabled && !_isLoading ? _handleSave : null,
            child: Container(
              alignment: Alignment.center,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: TColor.darkGreen,
                      ),
                    )
                  : Text(
                      "저장",
                      style: TextStyle(
                        color: _isButtonEnabled
                            ? TColor.darkGreen
                            : Colors.grey,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            TextField(
              controller: _nicknameController,
              decoration: InputDecoration(
                hintText: "새 닉네임",
                hintStyle: const TextStyle(color: TColor.gray),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.black),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 변경 완료 안내 다이얼로그
  void _showEditCompleteDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogContext) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 336,
            height: 224,
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 75, left: 20, right: 20),
                  child: Text(
                    '닉네임이 변경되었습니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(dialogContext);
                    Navigator.pop(context, true);
                  },
                  child: Container(
                    width: 286,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x7F235E26),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      "확인",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
