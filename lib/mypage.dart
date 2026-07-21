import 'package:flutter/material.dart';
import 'style.dart';
import 'splash.dart';
import 'login_selection.dart';
import 'edit_nickname.dart';
import 'reset_password.dart';
import 'services/mypage_service.dart';

class MyPageView extends StatefulWidget {
  const MyPageView({super.key});

  @override
  State<MyPageView> createState() => _MyPageViewState();
}

class _MyPageViewState extends State<MyPageView> {
  final MyPageService _myPageService = MyPageService();

  String nickname = "불러오는 중...";
  String userId = "불러오는 중...";
  double vibrationValue = 0.5;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  // 1. 프로필 정보(닉네임/아이디) 조회
  Future<void> _loadUserProfile() async {
    final profile = await _myPageService.fetchUserProfile();
    if (mounted) {
      setState(() {
        if (profile != null) {
          nickname = profile.nickname;
          userId = profile.loginId;
        } else {
          nickname = "사용자";
          userId = "정보를 불러올 수 없음";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            // 1. 프로필 영역 (사진 + 닉네임)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: TColor.buttonGreen, width: 2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: TColor.lightGreen,
                    child: Icon(
                      Icons.person,
                      color: TColor.buttonGreen,
                      size: 40,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nickname,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        userId,
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // 2. 설정 리스트
            _buildMenuItem(context, "닉네임 변경", () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EditNicknamePage(),
                ),
              );

              if (result == true) {
                _loadUserProfile();
              }
            }),
            _buildMenuItem(context, "비밀번호 재설정", () {
              if (userId.contains('@')) {
                _showSocialUserNoticeDialog(context);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ResetPasswordPage(),
                  ),
                );
              }
            }),
            //_buildMenuItem(context, "앱 권한", () {}),

            // 3. 진동 세기 조절 (슬라이더)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "진동",
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                  ),
                  Slider(
                    value: vibrationValue,
                    activeColor: TColor.buttonGreen,
                    inactiveColor: TColor.lightGreen,
                    onChanged: (value) {
                      setState(() {
                        vibrationValue = value;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            // 4. 로그아웃 / 탈퇴
            _buildSimpleTextButton("로그아웃", () {
              _showLogoutDialog(context);
            }),
            _buildSimpleTextButton("탈퇴하기", () {
              _showDeleteDialog(context);
            }),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // 다이얼로그
  void _showLogoutDialog(BuildContext context) {
    final parentContext = context;
    showDialog(
      context: context,
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
                    '로그아웃 하시겠습니까?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _dialogButton(
                      "취소",
                      const Color(0xFFD9D9D9),
                      () => Navigator.pop(dialogContext),
                    ),
                    _dialogButton("확인", const Color(0x7F235E26), () async {
                      Navigator.pop(dialogContext);
                      await _myPageService.logout();

                      if (parentContext.mounted) {
                        _showLogoutCompleteDialog(parentContext);
                      }
                    }),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutCompleteDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => Center(
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
                    '로그아웃 되었습니다',
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
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginSelection(),
                      ),
                      (route) => false,
                    );
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

  void _showDeleteDialog(BuildContext context) {
    final parentContext = context;
    showDialog(
      context: context,
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
                  padding: EdgeInsets.only(top: 50, left: 20, right: 20),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '정말 탈퇴하시겠습니까?\n',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            height: 3.0,
                          ),
                        ),
                        TextSpan(
                          text: '탈퇴 시 모든 데이터가 삭제됩니다',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _dialogButton(
                      "계속 사용하기",
                      const Color(0xFFD9D9D9),
                      () => Navigator.pop(dialogContext),
                    ),
                    _dialogButton(
                      "네, 탈퇴할게요",
                      const Color(0x7F235E26),
                      () async {
                        Navigator.pop(dialogContext);
                        await _myPageService.withdraw();

                        if (parentContext.mounted) {
                          _showDeleteCompleteDialog(parentContext);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteCompleteDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => Center(
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
                  padding: EdgeInsets.only(top: 50, left: 20, right: 20),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '탈퇴가 완료되었습니다\n',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            height: 1.5,
                          ),
                        ),
                        TextSpan(
                          text:
                              '그동안 Turtlely를 이용해 주셔서 감사합니다\n더욱 노력하고 발전하는 Turtlely가 되겠습니다',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const Splash()),
                      (route) => false,
                    );
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

  Widget _dialogButton(String label, Color color, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 135,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // 비밀번호 재설정 시 구글 로그인 예외 처리
  void _showSocialUserNoticeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 336,
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 50, left: 20, right: 20),
                  child: Text(
                    '구글 로그인 시\n비밀번호 재설정이 불가능합니다',
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
                  onTap: () => Navigator.pop(dialogContext),
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 메뉴 아이템 위젯 빌더
  Widget _buildMenuItem(
    BuildContext context,
    String title,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }

  // 하단 텍스트 버튼
  Widget _buildSimpleTextButton(String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
