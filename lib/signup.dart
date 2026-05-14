import 'package:flutter/material.dart';
import 'dart:async';
import 'style.dart';
import 'main.dart';
import 'services/auth_service.dart';

class Signup extends StatefulWidget {
  final String? socialId;
  const Signup({super.key, this.socialId});

  @override
  _SignupState createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  int _step = 0; // 0: 전화번호 인증, 1: ID/PW 설정, 2: 닉네임 설정, 3: 가입 완료
  int _idCheckStatus = 0; // 0: 기본, 1: 중복(빨강), 2: 성공(연초록)

  final AuthService _authService = AuthService();
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
  Color _idColor = TColor.gray;

  String _pwMessage = "영문, 숫자, 특수문자 포함 8자 이상";
  Color _pwColor = TColor.gray;

  Timer? _timer;
  int _secondsRemaining = 300;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _authCodeController.dispose();
    _idController.dispose();
    _pwController.dispose();
    _pwConfirmController.dispose();
    _nicknameController.dispose();
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

  // 인증번호 요청 핸들러
  void _handleAuthRequest() async {
    if (_phoneController.text.isEmpty) {
      setState(() => _authStatusMessage = "전화번호를 확인해 주세요");
      return;
    }

    // 💡 [수정됨] AuthService에서 새로 만든 회원가입 전용 함수를 부릅니다.
    final result = await _authService.sendSmsForSignup(_phoneController.text);

    setState(() {
      _authStatusMessage = result['message'];

      if (result['success'] == true) {
        _isAuthSent = true;
        _isTimeOut = false;
        _authStatusMessage = "인증번호가 발송되었습니다";
        _startTimer();
      } else {
        _isAuthSent = false;
      }
    });
  }

  void _checkIdDuplicate() async {
    if (_idController.text.isEmpty) return;

    // 💡 [수정됨] AuthService의 바뀐 함수 이름을 부릅니다.
    bool isAvailable = await _authService.checkIdDuplicate(_idController.text);

    setState(() {
      if (isAvailable) {
        _idMessage = "사용 가능한 아이디입니다";
        _idColor = const Color(0xFF235E26);
        _idCheckStatus = 2;
      } else {
        _idMessage = "이미 존재하는 아이디입니다";
        _idColor = TColor.red;
        _idCheckStatus = 1;
      }
    });
  }

  void _clearStep0() {
    _phoneController.clear();
    _authCodeController.clear();
    _isAuthSent = false;
    _isTimeOut = false;
    _authStatusMessage = "";
    _timer?.cancel();
    _secondsRemaining = 300;
  }

  void _clearStep1() {
    _idController.clear();
    _pwController.clear();
    _pwConfirmController.clear();
    _idCheckStatus = 0;
    _idMessage = "영문, 숫자 포함 6-20자";
    _idColor = TColor.gray;
    _pwMessage = "영문, 숫자, 특수문자 포함 8자 이상";
    _pwColor = TColor.gray;
  }

  void _clearStep2() {
    _nicknameController.clear();
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
    bool isStep1Valid =
        _step == 1 &&
        _idCheckStatus == 2 &&
        _pwController.text.isNotEmpty &&
        _pwConfirmController.text.isNotEmpty;
    bool isStep2Valid = _step == 2 && _nicknameController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: TColor.white,
      appBar: AppBar(
        backgroundColor: TColor.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            setState(() {
              if (_step == 0) {
                Navigator.pop(context);
              } else if (_step == 2 && widget.socialId != null) {
                _step = 0;
              } else if (_step == 1) {
                _clearStep1();
                _clearStep0();
                _step = 0;
              } else if (_step == 2) {
                _clearStep2();
                _clearStep1();
                _step = 1;
              } else
                _step--;
            });
          },
        ),
        title: const Text(
          "회원가입",
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

              if (_step == 0) _buildPhoneAuthStep(),
              if (_step == 1) _buildIdPwStep(),
              if (_step == 2) _buildNicknameStep(),
              if (_step == 3) _buildFinishStep(),

              const SizedBox(height: 40),

              if (_step < 3)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_step == 0) {
                        if (!isStep0Valid) return;
                        // 💡 [수정됨] 공통 인증번호 검증 함수 verifyCode
                        bool isVerify = await _authService.verifyCode(
                          _phoneController.text,
                          _authCodeController.text,
                        );
                        if (isVerify) {
                          setState(() {
                            if (widget.socialId != null) {
                              _step = 2;
                            } else {
                              _clearStep1();
                              _step = 1;
                            }
                          });
                        } else {
                          setState(
                            () => _authStatusMessage = "인증번호가 일치하지 않습니다",
                          );
                        }
                      } else if (_step == 1) {
                        final pwPattern =
                            r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[@$!%*#?&])[A-Za-z\d@$!%*#?&]{8,}$';
                        if (!RegExp(pwPattern).hasMatch(_pwController.text)) {
                          setState(() {
                            _pwMessage = "조건에 맞게 입력해 주세요";
                            _pwColor = TColor.red;
                          });
                          return;
                        }
                        if (_pwController.text != _pwConfirmController.text) {
                          setState(() {
                            _pwMessage = "비밀번호가 일치하지 않습니다";
                            _pwColor = TColor.red;
                          });
                          return;
                        }
                        setState(() {
                          _clearStep2();
                          _step = 2;
                        });
                      } else if (_step == 2) {
                        if (!isStep2Valid) return;
                        // 💡 [수정됨] 최종 가입 함수 signupFinal

                        bool isSignupSuccess = await _authService.signupFinal(
                          nickname: _nicknameController.text,
                          loginId: widget.socialId != null
                              ? null
                              : _idController.text,
                          password: widget.socialId != null
                              ? null
                              : _pwController.text,
                          phoneNumber: _phoneController.text,
                          socialId: widget.socialId,
                        );

                        if (isSignupSuccess) {
                          setState(() => _step = 3);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("회원가입 처리 중 에러가 발생했습니다."),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          ((_step == 0 && isStep0Valid) ||
                              (_step == 1 && isStep1Valid) ||
                              (_step == 2 && isStep2Valid))
                          ? TColor.buttonGreen
                          : TColor.gray,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      _step == 2 ? "가입하기" : "다음",
                      style: TText.button,
                    ),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // --- 단계별 위젯들 (민영님 디자인 그대로) ---

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
        if (_authStatusMessage.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              _authStatusMessage,
              style: TextStyle(
                color: (_authStatusMessage == "인증번호가 발송되었습니다")
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

  Widget _buildIdPwStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _idController,
          onChanged: (value) => setState(() {
            _idCheckStatus = 0;
            _idMessage = "영문, 숫자 포함 6-20자";
            _idColor = TColor.gray;
          }),
          decoration: InputDecoration(
            hintText: "아이디",
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
              child: GestureDetector(
                onTap: _checkIdDuplicate,
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
        TextField(
          controller: _pwController,
          obscureText: _isObscurePw,
          onChanged: (value) => setState(() {}),
          decoration: InputDecoration(
            hintText: "비밀번호",
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
        TextField(
          controller: _pwConfirmController,
          obscureText: _isObscurePwConfirm,
          onChanged: (value) => setState(() {}),
          decoration: InputDecoration(
            hintText: "비밀번호 확인",
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
          onChanged: (value) => setState(() {}),
          decoration: InputDecoration(
            hintText: "닉네임",
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

  Widget _buildFinishStep() {
    return Column(
      children: [
        const SizedBox(height: 50),
        Text(
          "안녕하세요 ${_nicknameController.text}님!",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
