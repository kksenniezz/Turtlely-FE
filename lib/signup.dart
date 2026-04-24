import 'package:flutter/material.dart';
import 'style.dart';
import 'main.dart'; 

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  _SignupState createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  int _step = 0; // 0: ID/PW 설정, 1: 닉네임 설정, 2: 가입 완료
  int _idCheckStatus = 0; // 0: 기본(기존색), 1: 중복(빨강), 2: 성공(연회색)

  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final TextEditingController _pwConfirmController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();

  bool _isObscurePw = true;
  bool _isObscurePwConfirm = true;
  String _idMessage = "영문, 숫자 포함 6-20자"; 
  Color _idColor = TColor.gray;

  void _checkIdDuplicate() {
    setState(() {
      if (_idController.text == "admin") {
        _idMessage = "이미 존재하는 아이디입니다.";
        _idColor = Colors.red;
        _idCheckStatus = 1;
      } else if (_idController.text.isEmpty) {
        _idMessage = "아이디를 입력해주세요.";
        _idColor = Colors.red;
        _idCheckStatus = 0;
      } else {
        _idMessage = "사용 가능한 아이디입니다.";
        _idColor = Colors.green;
        _idCheckStatus = 2; // 성공 상태로 변경 -> 여기서 색상 변경 발생
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColor.white,
      appBar: AppBar(
        backgroundColor: TColor.white, 
        elevation: 0, 
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("회원가입", style: TextStyle(color: Colors.black)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            if (_step == 0) _buildIdPwStep(),
            if (_step == 1) _buildNicknameStep(),
            if (_step == 2) _buildFinishStep(),
            
            const Spacer(),
            
            if (_step < 2) 
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  style: T_MainButtonStyle,
                  onPressed: () => setState(() => _step++),
                  child: const Text("다음", style: TText.button),
                ),
              ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildIdPwStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _idCheckStatus == 1 ? Colors.red : (_idCheckStatus == 2 ? Colors.green : TColor.gray),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _idController,
                  decoration: const InputDecoration(border: InputBorder.none, hintText: "아이디"),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 50,
              // [핵심] 중복 확인 완료(2)면 연회색(Colors.grey)으로 변경, 아니면 기존색
              child: ElevatedButton(
                onPressed: _idCheckStatus == 2 ? null : _checkIdDuplicate, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: _idCheckStatus == 2 ? Colors.grey : TColor.buttonGreen,
                  foregroundColor: Colors.white,
                ),
                // [핵심] 완료되면 글자 없애고 체크 아이콘으로 대체
                child: _idCheckStatus == 2 ? const Icon(Icons.check, size: 20) : const Text("중복 확인"),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text(_idMessage, style: TextStyle(color: _idColor, fontSize: 12)),
        ),
        
        const SizedBox(height: 20),
        TextField(
          controller: _pwController, 
          obscureText: _isObscurePw, 
          decoration: InputDecoration(
            hintText: "비밀번호", 
            suffixIcon: IconButton(
              icon: Icon(_isObscurePw ? Icons.visibility_off : Icons.visibility), 
              onPressed: () => setState(() => _isObscurePw = !_isObscurePw)
            )
          )
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _pwConfirmController, 
          obscureText: _isObscurePwConfirm, 
          decoration: InputDecoration(
            hintText: "비밀번호 확인", 
            suffixIcon: IconButton(
              icon: Icon(_isObscurePwConfirm ? Icons.visibility_off : Icons.visibility), 
              onPressed: () => setState(() => _isObscurePwConfirm = !_isObscurePwConfirm)
            )
          )
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8, left: 4),
          child: Text("영문, 숫자, 특수문자 포함 8자 이상", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildNicknameStep() {
    return Column(
      children: [
        const Text("터틀리에서 사용할 닉네임을 설정해주세요", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 30),
        TextField(controller: _nicknameController, decoration: const InputDecoration(hintText: "닉네임")),
      ],
    );
  }

  Widget _buildFinishStep() {
    return Column(
      children: [
        const SizedBox(height: 50),
        const Text("안녕하세요 @@@님!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Image.asset('assets/normal_turtle.png', width: 160),
        const Text("Turtlely", style: TText.logo),
        const SizedBox(height: 10),
        const Text("지금부터 터틀리와 함께 목 건강을 지켜보세요!"),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity, height: 56,
          child: ElevatedButton(
            style: T_MainButtonStyle,
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TurtlelyMainPage())),
            child: const Text("터틀리 시작하기", style: TText.button),
          ),
        ),
      ],
    );
  }
}