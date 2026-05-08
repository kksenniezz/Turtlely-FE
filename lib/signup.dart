import 'package:flutter/material.dart';
import 'dart:async'; // 타이머 추가
import 'style.dart';
import 'main.dart';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  _SignupState createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  int _step = 0; // 0: 전화번호 인증, 1: ID/PW 설정, 2: 닉네임 설정, 3: 가입 완료
  int _idCheckStatus = 0; // 0: 기본(기존색), 1: 중복(빨강), 2: 성공(연회색)

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _authCodeController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final TextEditingController _pwConfirmController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();

  bool _isObscurePw = true;
  bool _isObscurePwConfirm = true;
  bool _isAuthSent = false;
  bool _isTimeOut = false;

  String _authStatusMessage = "";

  String _idMessage = "영문, 숫자 포함 6-20자";
  Color _idColor = TColor.gray; // 초기 색상 회색

  String _pwMessage = "영문, 숫자, 특수문자 포함 8자 이상";
  Color _pwColor = TColor.gray; // 초기 색상 회색

  Timer? _timer;
  int _secondsRemaining = 300;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = 300;
    _isTimeOut = false; // 타이머 시작 시 초기화
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
          _isTimeOut = true; // 시간 초과
          _authStatusMessage = "인증 시간이 초과되었습니다 다시 시도해 주세요"; // 빨간 메시지로 활용
        }
      });
    });
  }

  void _handleAuthRequest() {
    setState(() {
      _isAuthSent = true;
      _isTimeOut = false; // 재발송 시 타임아웃 해제
      _authStatusMessage = "인증번호가 발송되었습니다";
      _startTimer();
    });
  }

  String _formatTime(int seconds) {
    int min = seconds ~/ 60;
    int sec = seconds % 60;
    return "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
  }

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
        // 성공 시 파란색으로 나오게 하고 싶다고 하셨으니 Colors.blue로 변경!
        _idMessage = "사용 가능한 아이디입니다.";
        _idColor = Colors.blue;
        _idCheckStatus = 2;
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            if (_step == 0) {
              Navigator.pop(context);
            } else {
              setState(() {
                _step--;
              });
            }
          },
        ),
        title: const Text(
          "회원가입",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        // 키보드가 올라올 때 화면 스크롤이 가능하게 함
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 60),

              // 단계별 위젯 호출
              if (_step == 0) _buildPhoneAuthStep(),
              if (_step == 1) _buildIdPwStep(),
              if (_step == 2) _buildNicknameStep(),
              if (_step == 3) _buildFinishStep(),

              const SizedBox(height: 40),

              // [수정된 다음 버튼 섹션]
              if (_step < 3)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      // 활성화 조건 변수화 (가독성)
                      bool isStep0Valid =
                          _step == 0 &&
                          _authCodeController.text.length == 4 &&
                          !_isTimeOut;
                      bool isStep1Valid = _step == 1 && _idCheckStatus == 2;

                      // 현재 단계가 유효하지 않으면 클릭 차단
                      if (_step == 0 && !isStep0Valid) return;
                      if (_step == 1 && !isStep1Valid) return;

                      if (_step == 1) {
                        setState(() {
                          final pwPattern =
                              r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$';
                          final regExp = RegExp(pwPattern);

                          if (!regExp.hasMatch(_pwController.text)) {
                            _pwMessage = "영문, 숫자, 특수문자 포함 8자 이상을 입력해 주세요";
                            _pwColor = Colors.red;
                          } else if (_pwController.text !=
                              _pwConfirmController.text) {
                            _pwMessage = "비밀번호가 일치하지 않습니다. 다시 확인해 주세요.";
                            _pwColor = Colors.red;
                          } else {
                            _pwMessage = "비밀번호가 일치합니다.";
                            _pwColor = Colors.blue;
                            _step++;
                          }
                        });
                      } else {
                        setState(() => _step++);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      // 배경색 결정 로직
                      backgroundColor:
                          (_step == 0 &&
                                  _authCodeController.text.length == 4 &&
                                  !_isTimeOut) ||
                              (_step == 1 && _idCheckStatus == 2) ||
                              (_step == 2)
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
              const SizedBox(height: 20), // 하단 여백
            ],
          ),
        ),
      ),
    );
  }

  // --- 단계별 위젯들 ---

  // STEP 0: 전화번호 인증
  Widget _buildPhoneAuthStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 전화번호 입력칸
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: "전화번호",
            hintStyle: const TextStyle(color: TColor.gray),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
              horizontal: 20,
            ),
            // 로그인 화면과 동일한 테두리 및 곡률(14) 적용
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.black),
            ),
            // 우측 인증 버튼 섹션
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
                      height: 40, // 버튼 높이 살짝 조정
                      decoration: BoxDecoration(
                        color: const Color(0x4D235E26), // 연한 초록 배경
                        borderRadius: BorderRadius.circular(10), // 버튼 자체 곡률
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

        // 안내 메시지
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text(
            _authStatusMessage,
            style: TextStyle(
              color: _isTimeOut ? Colors.red : const Color(0xFF235E26),
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
          onChanged: (value) {
            setState(() {});
          },
          decoration: InputDecoration(
            hintText: "인증번호",
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

  // STEP 1: 아이디/비밀번호 설정
  Widget _buildIdPwStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. 아이디 입력칸 (전화번호 인증칸과 동일한 스타일)
        TextField(
          controller: _idController,
          keyboardType: TextInputType.emailAddress,
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
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: _checkIdDuplicate, // 여기서 함수 이름을 써줘야 비로소 '사용'되는 것입니다!
                    child: Container(
                      width: 75,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0x4D235E26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        "중복 확인",
                        style: TextStyle(
                          color: Color(0xFF235E26),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4, bottom: 20),
          child: Text(
            _idMessage,
            style: TextStyle(color: _idColor, fontSize: 12),
          ),
        ),

        // 2. 비밀번호 입력칸
        TextField(
          controller: _pwController,
          keyboardType: TextInputType.visiblePassword,
          obscureText: _isObscurePw,
          decoration: InputDecoration(
            hintText: "비밀번호",
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
            suffixIcon: IconButton(
              icon: Icon(
                _isObscurePw
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: TColor.gray,
              ),
              onPressed: () => setState(() => _isObscurePw = !_isObscurePw),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 3. 비밀번호 확인 입력칸
        TextField(
          controller: _pwConfirmController,
          keyboardType: TextInputType.visiblePassword,
          obscureText: _isObscurePwConfirm,
          decoration: InputDecoration(
            hintText: "비밀번호 확인",
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
            suffixIcon: IconButton(
              icon: Icon(
                _isObscurePwConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: TColor.gray,
              ),
              onPressed: () =>
                  setState(() => _isObscurePwConfirm = !_isObscurePwConfirm),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text(
            _pwMessage,
            style: TextStyle(color: _pwColor, fontSize: 12),
          ),
        ),
      ],
    );
  }

  // STEP 2: 닉네임 설정
  Widget _buildNicknameStep() {
    return Column(
      children: [
        const Text(
          "터틀리에서 사용할 닉네임을 설정해주세요",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 30),
        TextField(
          controller: _nicknameController,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(hintText: "닉네임"),
        ),
      ],
    );
  }

  // STEP 3: 가입 완료
  Widget _buildFinishStep() {
    return Column(
      children: [
        const SizedBox(height: 50),
        const Text(
          "안녕하세요 @@@님!",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        Image.asset('assets/normal_turtle.png', width: 160),
        const Text("Turtlely", style: TText.logo),
        const SizedBox(height: 10),
        const Text("지금부터 터틀리와 함께 목 건강을 지켜보세요!"),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: T_MainButtonStyle,
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const TurtlelyMainPage()),
            ),
            child: const Text("터틀리 시작하기", style: TText.button),
          ),
        ),
      ],
    );
  }
}
