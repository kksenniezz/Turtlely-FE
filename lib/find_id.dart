import 'package:flutter/material.dart';
import 'style.dart';

class FindId extends StatefulWidget {
  const FindId({super.key});

  @override
  _FindIdState createState() => _FindIdState();
}

class _FindIdState extends State<FindId> {
  bool _isCodeSent = false;
  bool _isVerified = false; // 인증 완료 여부
  
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  
  String _message = "";
  Color _messageColor = Colors.red;

  void _sendVerificationCode() {
    setState(() {
      if (_phoneController.text.length >= 10) {
        _isCodeSent = true;
        _message = "인증번호가 전송되었습니다.";
        _messageColor = Colors.green;
      } else {
        _message = "올바른 전화번호를 입력해주세요.";
        _messageColor = Colors.red;
      }
    });
  }

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
        title: const Text("아이디 찾기", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("전화번호", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            
            // [1단계] 전화번호 입력 및 인증 버튼
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: TColor.lightGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(border: InputBorder.none, hintText: "'-' 없이 숫자만 입력"),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 50,
                  // [인증 버튼 디자인 통일]
                  child: ElevatedButton(
                    onPressed: _isVerified ? null : _sendVerificationCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isVerified ? Colors.grey : TColor.buttonGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: _isVerified ? const Icon(Icons.check, size: 20) : const Text("인증"),
                  ),
                ),
              ],
            ),
            
            // [2단계] 인증번호 입력칸
            if (_isCodeSent) ...[
              const SizedBox(height: 20),
              const Text("인증번호", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: TColor.lightGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(border: InputBorder.none, hintText: "인증번호 6자리"),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 50,
                    // [확인 버튼 디자인 통일]
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
              ),
            ],

            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(_message, style: TextStyle(color: _messageColor, fontSize: 12)),
              ),
            
            const Spacer(),
            
            // 다음 버튼
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                style: _isVerified ? T_MainButtonStyle : T_MainButtonStyle.copyWith(
                  backgroundColor: MaterialStateProperty.all(Colors.grey)
                ),
                onPressed: _isVerified ? () { /* 다음 화면 연결 */ } : null,
                child: const Text("다음", style: TText.button),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}