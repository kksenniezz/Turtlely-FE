import 'package:google_sign_in/google_sign_in.dart';

class SocialLoginService {
  Future<String?> getGoogleAccessToken() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId:
            "313213943885-9fko3i9flu4p9s2fodn24aigojd67nkt.apps.googleusercontent.com",
        scopes: <String>[
          'email',
          'https://www.googleapis.com/auth/userinfo.profile',
          'openid',
        ],
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final String? accessToken = googleAuth.accessToken;

        print("획득한 accessToken: $accessToken");

        return accessToken;
      } else {
        print("사용자가 로그인을 취소했습니다.");
        return null;
      } // else 블록 끝
    } catch (e) {
      print("구글 로그인 에러: $e");
      return null;
    }
  }
}
