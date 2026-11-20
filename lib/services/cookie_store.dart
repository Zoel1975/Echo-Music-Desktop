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

  /// Parses a `Cookie:` header copied from the browser DevTools into
  /// `name=value` pairs.
  static Map<String, String> parseCookieHeader(String header) {
    final result = <String, String>{};
    for (final part in header.split(';')) {
      final i = part.indexOf('=');
      if (i <= 0) continue;
      final name = part.substring(0, i).trim();
      final value = part.substring(i + 1).trim();
      if (name.isNotEmpty && value.isNotEmpty) result[name] = value;
    }
    return result;
  }

  /// Imports cookies copied from a signed-in browser session.
  Future<int> importCookieHeader(String header) async {
    final cookies = parseCookieHeader(header);
    for (final entry in cookies.entries) {
      _box.put(entry.key, entry.value);
    }
    return cookies.length;
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
  ///
  /// [saveAccount] persists the map under the `info` key, so unwrap it here:
  /// callers use `account['name']`, `account['email']`, etc. directly. Falls
  /// back to the raw box for older installs that stored fields flat.
  Map<String, dynamic> get account {
    final saved = _accountBox.get('info');
    if (saved is Map) return Map<String, dynamic>.from(saved);
    return Map<String, dynamic>.from(_accountBox.toMap());
  }

  /// Persists the account info (name, email, channel handle, avatar).
  Future<void> saveAccount(Map<String, dynamic> account) {
    return _accountBox.put('info', account);
  }

  Future<void> clearAccount() => _accountBox.clear();

  Future<void> clear() => _box.clear();

  Future<void> delete(String name) => _box.delete(name);
}
