/// Pure helpers for the YouTube Music session, ported from the Android app.
///
/// Android (`LoginScreen.kt` + `App.kt`) keeps three values for a signed-in
/// session and every InnerTube request depends on all of them:
///
/// * the cookie string read from `https://music.youtube.com`
/// * `VISITOR_DATA` from `window.yt.config_`
/// * `DATASYNC_ID` from `window.yt.config_` (the account-scoped id)
///
/// This class holds the pure part so it can be unit-tested without a browser.
class YtSession {
  const YtSession({this.visitorData, this.dataSyncId, this.signedIn});

  final String? visitorData;

  /// Account id from `DATASYNC_ID`. Android stores `substringBefore("||")`.
  final String? dataSyncId;

  /// `window.yt.config_.LOGGED_IN` from the page, when available.
  final bool? signedIn;

  bool get isEmpty =>
      (visitorData == null || visitorData!.isEmpty) &&
      (dataSyncId == null || dataSyncId!.isEmpty);

  /// Parses the JSON payload returned by the login browser's
  /// `Runtime.evaluate` call on music.youtube.com.
  ///
  /// Accepts both the raw config shape (`{"VISITOR_DATA": ...,`
  /// `"DATASYNC_ID": ...}`) and the short keys used by our own probe.
  static YtSession fromBrowserConfig(Map<String, dynamic> json) {
    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = json[k]?.toString().trim();
        if (v != null && v.isNotEmpty && v != 'null') return v;
      }
      return null;
    }

    final raw = pick(['dataSyncId', 'DATASYNC_ID']);
    return YtSession(
      visitorData: pick(['visitorData', 'VISITOR_DATA']),
      dataSyncId: raw?.split('||').first,
      signedIn: json['LOGGED_IN'] is bool ? json['LOGGED_IN'] as bool : null,
    );
  }

  /// `DATASYNC_ID` is `<id>||<something>`; Android keeps only `<id>`.
  static String? normalizeDataSyncId(String? raw) {
    if (raw == null) return null;
    final value = raw.split('||').first.trim();
    return value.isEmpty ? null : value;
  }
}
