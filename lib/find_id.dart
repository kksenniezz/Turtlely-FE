import 'package:flutter/material.dart';
import 'dart:async';
import 'style.dart';

class FindId extends StatefulWidget {
  const FindId({super.key});

  @override
  _FindIdState createState() => _FindIdState();
}

class _FindIdState extends State<FindId> {
  int _step = 0; // 0: 전화번호 입력, 1: 아이디 확인 결과

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _authCodeController = TextEditingController();

  bool _isAuthSent = false;
  bool _isTimeOut = false;
  bool _isAuthConfirmed = false;
  String _authStatusMessage = "";

  Timer? _timer;
  int _secondsRemaining = 300;

  @override
  void dispose() {
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
      _isAuthConfirmed = true;
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
        _step == 0 &&
        _phoneController.text.isNotEmpty &&
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
          onPressed: () {
            if (_step == 1) {
              setState(() {
                _step = 0;
                _isAuthConfirmed = false;
                _phoneController.clear();
                _authCodeController.clear();
                _authStatusMessage = "";
                _isAuthSent = false;
                _timer?.cancel();
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          "아이디 찾기",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              // 0단계: 기존 간격 유지, 1단계: 56px 적용
              SizedBox(height: _step == 0 ? 60 : 56),

              if (_step == 0) _buildPhoneAuthStep(),
              if (_step == 1) _buildIdResultStep(),

              const SizedBox(height: 40),

              // 하단 버튼 섹션
              if (_step < 2)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_step == 0) {
                        if (!isStep0Valid) return;
                        setState(() {
                          _timer?.cancel();
                          _step = 1;
                        });
                      } else {
                        // STEP 1: 로그인하러 가기 클릭 시
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _step == 1
                          ? TColor.buttonGreen
                          : (isStep0Valid ? TColor.buttonGreen : TColor.gray),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _step == 0 ? "다음" : "로그인하러 가기",
                      style: TText.button,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- STEP 0: 휴대폰 인증 위젯 ---
  Widget _buildPhoneAuthStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 전화번호 입력칸
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          readOnly: _isAuthConfirmed,
          onChanged: (value) => setState(() {}),
          decoration: InputDecoration(
            hintText: "전화번호",
            hintStyle: const TextStyle(color: TColor.gray),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 20,
            ),
            filled: _isAuthConfirmed,
            fillColor: _isAuthConfirmed
                ? const Color(0xFFF5F5F5)
                : Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _isAuthConfirmed
                    ? const Color(0xFFF5F5F5)
                    : const Color(0xFFE0E0E0),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _isAuthConfirmed
                    ? const Color(0xFFF5F5F5)
                    : Colors.black,
              ),
            ),
            // 우측 인증 버튼 섹션
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isAuthSent && !_isAuthConfirmed)
                    Text(
                      _formatTime(_secondsRemaining),
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isAuthConfirmed ? null : _handleAuthRequest,
                    child: Container(
                      width: 64,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _isAuthConfirmed
                            ? const Color(0xFFF5F5F5)
                            : const Color(0x4D235E26),
                        borderRadius: BorderRadius.circular(10),
                        border: _isAuthConfirmed
                            ? Border.all(color: const Color(0xFFE0E0E0))
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _isAuthSent ? "재발송" : "인증",
                        style: TextStyle(
                          color: _isAuthConfirmed
                              ? TColor.gray
                              : const Color(0xFF235E26),
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

        // 안내 메시지
        if (_authStatusMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              _authStatusMessage,
              style: TextStyle(
                color: (_isTimeOut || _authStatusMessage == "전화번호를 확인해 주세요")
                    ? Colors.red
                    : const Color(0xFF235E26),
                fontSize: 12,
              ),
            ),
          ),

        const SizedBox(height: 16),

        // 2. 인증번호 입력칸
        TextField(
          controller: _authCodeController,
          keyboardType: TextInputType.phone,
          maxLength: 4, // 인증번호 길이
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

  // --- STEP 1: 아이디 확인 결과 위젯 (요청 디자인 반영) ---
  Widget _buildIdResultStep() {
    return Column(
      children: [
        const Text(
          "전화번호와 일치하는 아이디입니다",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 96), // 96px 간격
        const Text(
          "(아이디)",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 128), // 128px 간격
      ],
    );
  }
}
