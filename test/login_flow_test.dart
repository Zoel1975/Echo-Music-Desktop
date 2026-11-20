import 'package:Echo/screens/login/login_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldAutoCompleteLogin', () {
    test('the initial /login page never completes the login', () {
      expect(
        shouldAutoCompleteLogin(Uri.parse('https://music.youtube.com/login')),
        isFalse,
      );
    });

    test('Google sign-in and consent pages never complete the login', () {
      expect(
        shouldAutoCompleteLogin(
          Uri.parse('https://accounts.google.com/v3/signin/challenge'),
        ),
        isFalse,
      );
      expect(
        shouldAutoCompleteLogin(
          Uri.parse('https://consent.youtube.com/m?continue=...'),
        ),
        isFalse,
      );
    });

    test('a normal YouTube Music page can complete the login', () {
      expect(
        shouldAutoCompleteLogin(Uri.parse('https://music.youtube.com/')),
        isTrue,
      );
      expect(
        shouldAutoCompleteLogin(Uri.parse('https://www.youtube.com/')),
        isTrue,
      );
    });
  });
}
