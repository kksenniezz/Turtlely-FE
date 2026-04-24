import 'package:flutter/material.dart';
import 'style.dart';

class FindPassword extends StatefulWidget {
  const FindPassword({super.key});

  @override
  _FindPasswordState createState() => _FindPasswordState();
}

class _FindPasswordState extends State<FindPassword> {
  int _step = 0; // 0: 정보입력, 1: 인증번호입력, 2: 비밀번호재설정
  bool _isCodeSent = false;
  bool _isVerified = false;
  
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  String _message = "";
  Color _messageColor = Colors.red;

  // 인증번호 전송
  void _sendVerification() {
    setState(() {
      if (_idController.text.isNotEmpty && _phoneController.text.length >= 10) {
        _isCodeSent = true;
        _message = "인증번호가 전송되었습니다.";
        _messageColor = Colors.green;
      } else {
        _message = "아이디와 전화번호를 정확히 입력해주세요.";
        _messageColor = Colors.red;
      }
    });
  }

  // 인증번호 확인
  void _verifyCode() {
    setState(() {
      if (_codeController.text == "123456") {
        _isVerified = true;
        _message = "인증이 완료되었습니다.";
        _messageColor = Colors.green;
      } else {
        _message = "인증번호가 일치하지 않습니다.";
        _messageColor = Colors.red;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColor.white,
      appBar: AppBar(
        backgroundColor: TColor.white, elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("비밀번호 찾기", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            
            // 1단계: 아이디/전화번호 입력
            _buildInputStep(),
            
            // 2단계: 인증번호 확인
            if (_isCodeSent) ...[
              const SizedBox(height: 20),
              _buildVerifyStep(),
            ],

            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16, left: 4),
                child: Text(_message, style: TextStyle(color: _messageColor, fontSize: 12)),
              ),
            
            const Spacer(),
            
            // 다음 버튼 (인증 완료 시 활성화)
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                style: _isVerified ? T_MainButtonStyle : T_MainButtonStyle.copyWith(
                  backgroundColor: MaterialStateProperty.all(Colors.grey)
                ),
                onPressed: _isVerified ? () { setState(() => _step = 2); } : null,
                child: const Text("다음", style: TText.button),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // 1단계 UI
  Widget _buildInputStep() {
    return Column(
      children: [
        TextField(controller: _idController, decoration: const InputDecoration(hintText: "아이디")),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(child: TextField(controller: _phoneController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "전화번호"))),
            const SizedBox(width: 10),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _isCodeSent ? null : _sendVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isCodeSent ? Colors.grey : TColor.buttonGreen,
                  foregroundColor: Colors.white,
                ),
                child: _isCodeSent ? const Icon(Icons.check, size: 20) : const Text("인증"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 2단계 UI
  Widget _buildVerifyStep() {
    return Row(
      children: [
        Expanded(child: TextField(controller: _codeController, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "인증번호 입력"))),
        const SizedBox(width: 10),
        SizedBox(
          height: 50,
          child: ElevatedButton(
            onPressed: _isVerified ? null : _verifyCode,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isVerified ? Colors.grey : TColor.buttonGreen,
              foregroundColor: Colors.white,
            ),
            child: _isVerified ? const Icon(Icons.check, size: 20) : const Text("확인"),
          ),
        ),
      ],
    );
  }
}