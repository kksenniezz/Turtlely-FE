import 'package:flutter/material.dart';
import 'dart:async';
import 'style.dart';
import 'services/auth_service.dart';

class FindId extends StatefulWidget {
  const FindId({super.key});

  @override
  _FindIdState createState() => _FindIdState();
}

class _FindIdState extends State<FindId> {
  int _step = 0; // 0: 전화번호 입력, 1: 아이디 확인 결과
  String _foundId = ""; 

  final AuthService _authService = AuthService(); 
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _authCodeController = TextEditingController();

  bool _isAuthSent = false;
  bool _isTimeOut = false;
  String _authStatusMessage = "";

  Timer? _timer;
  int _secondsRemaining = 300;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _authCodeController.dispose();
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

  // 1. 인증번호 요청 핸들러 (아이디 찾기 전용)
  void _handleAuthRequest() async {
    if (_phoneController.text.isEmpty) {
      setState(() => _authStatusMessage = "전화번호를 확인해 주세요");
      return;
    }

    // 💡 [수정] 아이디 찾기 전용 함수인 sendSmsForFindId를 호출합니다.
    final result = await _authService.sendSmsForFindId(_phoneController.text);

    setState(() {
      // 서버 메시지("가입된 번호가 없습니다" 등)를 화면에 띄웁니다.
      _authStatusMessage = result['message'];

      if (result['success'] == true) {
        _isAuthSent = true;
        _isTimeOut = false;
        _startTimer();
      } else {
        _isAuthSent = false;
      }
    });
  }

  // 2. 인증 및 아이디 찾기 최종 핸들러
  void _verifyAndFindId() async {
    // 공통 인증번호 확인 함수 호출
    bool isCodeCorrect = await _authService.verifyCode(
      _phoneController.text, 
      _authCodeController.text
    );

    if (isCodeCorrect) { 
      // 인증 성공 시 -> 서버에서 아이디 결과 가져오기
      String? resultId = await _authService.findIdResult(_phoneController.text);

      setState(() {
        if (resultId != null && resultId.isNotEmpty) {
          _timer?.cancel();
          _foundId = resultId;
          _step = 1; 
        } else {
          _authStatusMessage = "해당 번호로 가입된 회원이 없습니다.";
        }
      });
    } else {
      setState(() {
        _authStatusMessage = "인증번호가 일치하지 않습니다.";
      });
    }
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
              SizedBox(height: _step == 0 ? 60 : 56),
              if (_step == 0) _buildPhoneAuthStep(),
              if (_step == 1) _buildIdResultStep(),
              const SizedBox(height: 40),
              if (_step < 2)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_step == 0) {
                        if (!isStep0Valid) return;
                        _verifyAndFindId();
                      } else {
                        Navigator.pop(context); // 로그인 화면으로 돌아가기
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _step == 1
                          ? TColor.buttonGreen
                          : (isStep0Valid ? TColor.buttonGreen : TColor.gray),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  Widget _buildPhoneAuthStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          onChanged: (value) => setState(() {}),
          decoration: InputDecoration(
            hintText: "전화번호",
            hintStyle: const TextStyle(color: TColor.gray),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14), 
              borderSide: const BorderSide(color: Color(0xFFE0E0E0))
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14), 
              borderSide: const BorderSide(color: Colors.black)
            ),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isAuthSent)
                    Text(_formatTime(_secondsRemaining), style: const TextStyle(color: Colors.red, fontSize: 12)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _handleAuthRequest,
                    child: Container(
                      width: 64, height: 40,
                      decoration: BoxDecoration(color: const Color(0x4D235E26), borderRadius: BorderRadius.circular(10)),
                      alignment: Alignment.center,
                      child: Text(_isAuthSent ? "재발송" : "인증", style: const TextStyle(color: Color(0xFF235E26), fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_authStatusMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              _authStatusMessage,
              style: TextStyle(
                // 💡 발송 성공 메시지일 때만 초록색, 그 외 모든 에러는 빨간색!
                color: _authStatusMessage.contains("성공") || _authStatusMessage.contains("발송되었습니다")
                    ? const Color(0xFF235E26)
                    : Colors.red,
                fontSize: 12,
              ),
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _authCodeController,
          keyboardType: TextInputType.phone,
          maxLength: 4,
          onChanged: (value) => setState(() {}),
          decoration: InputDecoration(
            hintText: "인증번호", counterText: "",
            hintStyle: const TextStyle(color: TColor.gray),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14), 
              borderSide: const BorderSide(color: Color(0xFFE0E0E0))
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14), 
              borderSide: const BorderSide(color: Colors.black)
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdResultStep() {
    return Column(
      children: [
        const Text("전화번호와 일치하는 아이디입니다", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 96),
        Text(_foundId, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 128),
      ],
    );
  }
}