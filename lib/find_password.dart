import 'package:flutter/material.dart';
import 'dart:async';
import 'style.dart';

class FindPassword extends StatefulWidget {
  const FindPassword({super.key});

  @override
  _FindPasswordState createState() => _FindPasswordState();
}

class _FindPasswordState extends State<FindPassword> {
  int _step = 0; // 0: 아이디 및 인증, 1: 새 비밀번호 설정

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _authCodeController = TextEditingController();

  bool _isAuthSent = false;
  bool _isTimeOut = false;
  String _authStatusMessage = "";

  Timer? _timer;
  int _secondsRemaining = 300;

  @override
  void dispose() {
    _idController.dispose();
    _phoneController.dispose();
    _authCodeController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = 300;
    _isTimeOut = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
          _isTimeOut = true;
          _authStatusMessage = "인증 시간이 초과되었습니다 다시 시도해 주세요";
        }
      });
    });
  }

  void _handleAuthRequest() {
    if (_phoneController.text.isEmpty) {
      setState(() {
        _isAuthSent = false;
        _authStatusMessage = "전화번호를 확인해 주세요";
      });
      return;
    }
    setState(() {
      _isAuthSent = true;
      _isTimeOut = false;
      _authStatusMessage = "인증번호가 발송되었습니다";
      _startTimer();
    });
  }

  String _formatTime(int seconds) {
    int min = seconds ~/ 60;
    int sec = seconds % 60;
    return "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    bool isStep0Valid =
        _idController.text.isNotEmpty &&
        _isAuthSent &&
        _authCodeController.text.length == 4 &&
        !_isTimeOut;

    return Scaffold(
      backgroundColor: TColor.white,
      appBar: AppBar(
        backgroundColor: TColor.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "비밀번호 찾기",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 60),
              if (_step == 0) _buildAuthStep(),
              if (_step == 1) _buildResetResultStep(),

              if (_step == 0) ...[
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      if (!isStep0Valid) return;

                      if (_idController.text.isEmpty ||
                          _authCodeController.text.isEmpty) {
                        setState(() {
                          _authStatusMessage = "아이디 또는 인증번호를 다시 확인해 주세요";
                        });
                        return;
                      }
                      setState(() {
                        _timer?.cancel();
                        _step = 1; // 다음 단계로 이동
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isStep0Valid
                          ? TColor.buttonGreen
                          : TColor.gray,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text("다음", style: TText.button),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- Step 0: 인증 화면 ---
  Widget _buildAuthStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 아이디 입력칸
        TextField(
          controller: _idController,
          onChanged: (value) => setState(() {}),
          decoration: InputDecoration(
            hintText: "아이디",
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
        const SizedBox(height: 16),

        // 2. 전화번호 입력칸
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          onChanged: (value) => setState(() {}),
          decoration: InputDecoration(
            hintText: "전화번호",
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
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isAuthSent)
                    Text(
                      _formatTime(_secondsRemaining),
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _handleAuthRequest,
                    child: Container(
                      width: 64,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0x4D235E26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _isAuthSent ? "재발송" : "인증",
                        style: const TextStyle(
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

        // 메시지 영역 (에러 메시지 포함)
        if (_authStatusMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              _authStatusMessage,
              style: TextStyle(
                color:
                    (_isTimeOut ||
                        _authStatusMessage == "전화번호를 확인해 주세요" ||
                        _authStatusMessage == "아이디 또는 인증번호를 다시 확인해 주세요")
                    ? Colors.red
                    : const Color(0xFF235E26),
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 16),

        // 3. 인증번호 입력칸
        TextField(
          controller: _authCodeController,
          keyboardType: TextInputType.phone,
          maxLength: 4,
          onChanged: (value) => setState(() {}),
          decoration: InputDecoration(
            hintText: "인증번호",
            counterText: "",
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
    );
  }

  // --- STEP 1: 결과 및 안내 화면 ---
  Widget _buildResetResultStep() {
    return Column(
      children: [
        const Text(
          "입력한 전화번호로 임시 비밀번호를 전송했습니다",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Image.asset(
          'assets/normal_turtle.png',
          width: 150,
          errorBuilder: (context, error, stackTrace) {
            return const Text("이미지 로드 실패 (assets 경로 확인)");
          },
        ),
        const SizedBox(height: 16),
        const Text(
          "로그인 후 비밀번호를 재설정하세요",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          "MyPage → 비밀번호 재설정",
          style: TextStyle(
            fontSize: 14,
            color: TColor.buttonGreen,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: TColor.buttonGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: const Text("로그인하러 가기", style: TText.button),
          ),
        ),
      ],
    );
  }
}
