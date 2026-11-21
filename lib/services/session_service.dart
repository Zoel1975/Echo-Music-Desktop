import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';

import 'account_refresh.dart';
import 'cookie_store.dart';
import 'google_login_service.dart';
import '../ytmusic/mixins/browsing.dart';
import '../ytmusic/ytmusic.dart';

/// Desktop port of Android's `App.forgetAccount()`.
///
/// Android removes the persisted session (`InnerTubeCookieKey`,
/// `VisitorDataKey`, `DataSyncIdKey`, account name/email/handle), resets
/// `YouTube.cookie/visitorData/dataSyncId`, notifies the app and clears the
/// WebView cookies. This class does the same for the desktop app so "Sign out"
/// actually removes every trace of the session.
class SessionService {
  SessionService({
    Future<void> Function()? clearBrowserProfile,
    Future<void> Function()? refreshClient,
  })  : _clearBrowserProfile =
            clearBrowserProfile ?? GoogleLoginService.clearProfile,
        _refreshClient = refreshClient ?? _defaultRefreshClient;

  final Future<void> Function() _clearBrowserProfile;
  final Future<void> Function() _refreshClient;

  static Future<void> _defaultRefreshClient() async {
    final yt = GetIt.I<YTMusic>();
    await yt.resetVisitorId();
    await yt.refreshHeaders();
  }

  /// Signs out completely and bumps [accountEpoch] so every data screen
  /// refetches anonymously.
  Future<void> signOut() async {
    await CookieStore.instance.clear();
    await CookieStore.instance.clearAccount();
    if (Hive.isBoxOpen('SETTINGS')) {
      // Android removes DataSyncIdKey and VisitorDataKey.
      await Hive.box('SETTINGS').delete('VISITOR_ID');
    }
    await CookieStore.instance.saveDataSyncId(null);
    BrowsingMixin.clearPlaylistCache();
    try {
      await _refreshClient();
    } catch (_) {
      // Network hiccup must never block a sign-out.
    }
    await _clearBrowserProfile();
    notifyAccountChanged();
  }
}
