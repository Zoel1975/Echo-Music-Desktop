import 'package:hive_flutter/hive_flutter.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

/// Desktop equivalent of Android's InnerTube cookie handling
/// (`InnerTube.initializeHeaders` + `CookieManager`).
///
/// Cookies entered through the WebView login screen are stored in the Hive
/// box `COOKIES` and merged into every `YTClient` request by
/// `YTClient.sendRequest` / `sendGetRequest`. The authenticated account info
/// (name/email/channel handle/avatar) is stored in the Hive box `ACCOUNT`.
class CookieStore {
  CookieStore._();

  static final CookieStore _instance = CookieStore._();

  /// Stored cookies, keyed by cookie name.
  static Box get _box => Hive.box('COOKIES');

  /// The authenticated account info, as returned by `getAccountInfo`.
  static Box get _accountBox => Hive.box('ACCOUNT');

  static CookieStore get instance => _instance;

  /// Builds a `Cookie` request header string from `name=value` pairs.
  static String buildCookieHeader(Map<String, String> cookies) {
    if (cookies.isEmpty) return '';
    return cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  /// The `Cookie` header to merge into requests, or `null` when logged out.
  String? get cookieHeader {
    final cookies = Map<String, String>.from(_box.toMap());
    if (cookies.isEmpty) return null;
    return buildCookieHeader(cookies);
  }

  /// All stored cookies as `name -> value`.
  Map<String, String> get cookies => Map<String, String>.from(_box.toMap());

  /// Reads the cookies the user has (after Google/YouTube login completes)
  /// from the WebView and stores them.
  Future<void> captureFromWebView(
    WebviewController controller, {
    String uri = 'https://music.youtube.com/',
  }) async {
    final cookies = await controller.getCookies(uri);
    for (final cookie in cookies) {
      _box.put(cookie.name, cookie.value);
    }
  }

  /// Account info saved by the login flow.
  Map<String, dynamic> get account =>
      Map<String, dynamic>.from(_accountBox.toMap());

  /// Persists the account info (name, email, channel handle, avatar).
  Future<void> saveAccount(Map<String, dynamic> account) {
    return _accountBox.put('info', account);
  }

  Future<void> clearAccount() => _accountBox.clear();

  Future<void> clear() => _box.clear();

  Future<void> delete(String name) => _box.delete(name);
}
