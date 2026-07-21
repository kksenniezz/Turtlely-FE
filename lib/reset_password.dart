import 'package:flutter/material.dart';
import 'style.dart';
import 'services/mypage_service.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final MyPageService _myPageService = MyPageService();

  final TextEditingController _currentPwController = TextEditingController();
  final TextEditingController _newPwController = TextEditingController();
  final TextEditingController _confirmPwController = TextEditingController();

  bool _isCurrentPwVerified = false; // 현재 비밀번호 검증 성공 여부
  bool _showCurrentPwError = false; // '현재 비밀번호를 다시 확인해 주세요' 에러 표시

  // 새 비밀번호 관련 상태 메시지 및 색상 변수 추가
  String _pwMessage = "영문, 숫자, 특수문자 포함 8자 이상";
  Color _pwColor = TColor.gray;

  bool _isObscureCurrent = true;
  bool _isObscureNew = true;
  bool _isObscureConfirm = true;

  bool _isLoading = false; // 상단 [저장] 버튼 전용 로딩

  @override
  void initState() {
    super.initState();
    _currentPwController.addListener(_checkButtonStatus);
    _newPwController.addListener(_checkButtonStatus);
    _confirmPwController.addListener(_checkButtonStatus);
  }

  bool get _isSaveButtonEnabled {
    return _isCurrentPwVerified &&
        _newPwController.text.trim().isNotEmpty &&
        _confirmPwController.text.trim().isNotEmpty &&
        !_isLoading;
  }

  void _checkButtonStatus() {
    setState(() {});
  }

  @override
  void dispose() {
    _currentPwController.dispose();
    _newPwController.dispose();
    _confirmPwController.dispose();
    super.dispose();
  }

  // 비밀번호 정규식 (영문, 숫자, 특수문자 포함 8자 이상)
  bool _validatePassword(String pw) {
    const pwPattern =
        r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$';
    return RegExp(pwPattern).hasMatch(pw);
  }

  // 1. 현재 비밀번호 [확인] 버튼 클릭 시 연동 검증
  Future<void> _verifyCurrentPassword() async {
    final currentPassword = _currentPwController.text.trim();
    if (currentPassword.isEmpty) return;

    // 서버에 현재 비밀번호 검증 요청
    final isSuccess = await _myPageService.updatePassword(
      currentPassword: currentPassword,
      newPassword: currentPassword,
    );

    if (!mounted) return;

    setState(() {
      if (isSuccess) {
        _isCurrentPwVerified = true;
        _showCurrentPwError = false;
      } else {
        _isCurrentPwVerified = false;
        _showCurrentPwError = true;
      }
    });
  }

  // 2. 상단 [저장] 버튼 클릭 시 최종 연동 및 유효성 검사
  Future<void> _handleSave() async {
    if (!_isSaveButtonEnabled) return;

    final currentPw = _currentPwController.text.trim();
    final newPassword = _newPwController.text.trim();
    final confirmPw = _confirmPwController.text.trim();

    // 1) 비밀번호 조건 체크
    if (!_validatePassword(newPassword)) {
      setState(() {
        _pwMessage = "영문, 숫자, 특수문자 포함 8자 이상을 입력해 주세요";
        _pwColor = TColor.red; // 에러 색상 (레드)
      });
      return;
    }

    // 2) 새 비밀번호와 새 비밀번호 확인 일치 여부 체크
    if (newPassword != confirmPw) {
      setState(() {
        _pwMessage = "새 비밀번호를 다시 확인해 주세요";
        _pwColor = TColor.red; // 에러 색상 (레드)
      });
      return;
    }

    setState(() {
      _pwMessage = "영문, 숫자, 특수문자 포함 8자 이상";
      _pwColor = const Color(0xFF828282); // 기본 회색
      _isLoading = true;
    });

    // 비밀번호 최종 변경 API 호출
    final success = await _myPageService.updatePassword(
      currentPassword: currentPw,
      newPassword: newPassword,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (success) {
      _showCompleteDialog(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("비밀번호 변경에 실패했습니다 다시 시도해 주세요")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColor.white,
      appBar: AppBar(
        backgroundColor: TColor.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "비밀번호 재설정",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          GestureDetector(
            onTap: _isSaveButtonEnabled ? _handleSave : null,
            child: Container(
              alignment: Alignment.center,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: TColor.buttonGreen,
                      ),
                    )
                  : Text(
                      "저장",
                      style: TextStyle(
                        color: _isSaveButtonEnabled
                            ? TColor.darkGreen
                            : TColor.gray,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            // --- 1. 현재 비밀번호 입력창 + 확인 버튼 ---
            TextField(
              controller: _currentPwController,
              obscureText: _isObscureCurrent,
              onChanged: (_) {
                if (_isCurrentPwVerified || _showCurrentPwError) {
                  setState(() {
                    _isCurrentPwVerified = false;
                    _showCurrentPwError = false;
                  });
                }
              },
              decoration: InputDecoration(
                hintText: "현재 비밀번호",
                hintStyle: const TextStyle(color: TColor.gray),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _verifyCurrentPassword,
                        child: Container(
                          width: 64,
                          height: 40,
                          decoration: BoxDecoration(
                            color: TColor.darkGreen,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            "확인",
                            style: TextStyle(
                              color: Color(0xFF235E26),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // 불일치 시 에러 문구
            if (_showCurrentPwError)
              const Padding(
                padding: EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  '현재 비밀번호를 다시 확인해 주세요',
                  style: TextStyle(color: TColor.red, fontSize: 12),
                ),
              ),

            if (_isCurrentPwVerified)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  '비밀번호가 인증되었습니다',
                  style: TextStyle(color: TColor.buttonGreen, fontSize: 12),
                ),
              ),

            const SizedBox(height: 20),

            // --- 2. 새 비밀번호 ---
            TextField(
              controller: _newPwController,
              obscureText: _isObscureNew,
              onChanged: (_) {
                if (_pwColor == TColor.red) {
                  setState(() {
                    _pwMessage = "영문, 숫자, 특수문자 포함 8자 이상";
                    _pwColor = TColor.gray;
                  });
                }
              },
              decoration: InputDecoration(
                hintText: "새 비밀번호",
                hintStyle: const TextStyle(color: TColor.gray),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isObscureNew
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: TColor.gray,
                  ),
                  onPressed: () =>
                      setState(() => _isObscureNew = !_isObscureNew),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // --- 3. 새 비밀번호 확인 ---
            TextField(
              controller: _confirmPwController,
              obscureText: _isObscureConfirm,
              onChanged: (_) {
                if (_pwColor == TColor.red) {
                  setState(() {
                    _pwMessage = "영문, 숫자, 특수문자 포함 8자 이상";
                    _pwColor = TColor.gray;
                  });
                }
              },
              decoration: InputDecoration(
                hintText: "새 비밀번호 확인",
                hintStyle: const TextStyle(color: TColor.gray),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD9D9D9)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Colors.black),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isObscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: TColor.gray,
                  ),
                  onPressed: () =>
                      setState(() => _isObscureConfirm = !_isObscureConfirm),
                ),
              ),
            ),

            // 비밀번호 조건 및 에러 안내 문구
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                _pwMessage,
                style: TextStyle(color: _pwColor, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 변경 완료 다이얼로그
  void _showCompleteDialog(BuildContext context) {
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
                    '비밀번호가 변경되었습니다',
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
                    Navigator.pop(context);
                  },
                  child: Container(
                    width: 286,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0x4D235E26),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      "확인",
                      style: TextStyle(
                        color: Color(0xFF235E26),
                        fontSize: 13,
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
