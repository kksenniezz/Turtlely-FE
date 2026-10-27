import 'package:flutter/material.dart';

// 1. 공통 컬러
class TColor {
  static const black = Color(0xFF1E1E1E);
  static const gray = Color(0xFF818181);
  static const white = Color(0xFFFAFAFA);
  static const buttonGreen = Color(0xFF235E26);
  static const darkGreen = Color(0xFF143601);
  static const lightGreen = Color(0xFFEBF2E7);
  static const red = Color(0xFFF05650);
  static const blue = Color(0xFF5151F8);
  static const pink = Color(0xFFFF2D94);
}

// 2. 공통 텍스트 스타일 (8배수/4배수 반영)
class TText {
  static const logo = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: TColor.darkGreen,
  );
  static const title = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: TColor.black,
  );
  static const body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: TColor.black,
  );
  static const button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: TColor.white,
  );
  static const caption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: TColor.gray,
  );
  static const nav = TextStyle(fontSize: 12, fontWeight: FontWeight.w400);
}

// 3. 공통 버튼 스타일 (324x56)
final ButtonStyle T_MainButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: TColor.buttonGreen,
  minimumSize: const Size(324, 56),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  elevation: 0,
);
