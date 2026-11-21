import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:Echo/services/cookie_store.dart';
import 'package:Echo/services/session_service.dart';
import '../../../core/widgets/back_button.dart';

/// Desktop port of `ui/screens/AccountScreen.kt`: shows the signed-in account
/// and offers "Sign out" / "Close". When logged out it offers "Sign in"
/// instead. On desktop the WebView login happens on `/login`
/// (`lib/screens/login/login_page.dart`).
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  /// Port of Android `App.forgetAccount()`; see `SessionService.signOut()`.
  Future<void> _signOut(BuildContext context) async {
    await SessionService().signOut();
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: echoBackButton(context),
        title: const Text('Account'), centerTitle: true),
      body: Builder(builder: (context) {
        final account = CookieStore.instance.account;
        final name = account['name']?.toString();
        final email = account['email']?.toString();
        final handle = account['channelHandle']?.toString();
        final avatar = account['avatarUrl']?.toString();
        // Android shows "Sign out" whenever any session data exists, even if
        // the account-name lookup failed — so the user is never stuck logged in.
        final hasAccount = CookieStore.instance.cookieHeader != null ||
            account.isNotEmpty;

        return ListView(
          children: [
            if (hasAccount) ...[
              ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: avatar == null
                      ? const Icon(Icons.account_circle, size: 56)
                      : Image.network(avatar, width: 56, height: 56, fit: BoxFit.cover),
                ),
                title: Text(name ?? 'YouTube Music',
                    style: const TextStyle(fontSize: 16)),
                subtitle: Text([email, handle]
                    .where((s) => s != null && s.isNotEmpty)
                    .join(' • ')),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () => _signOut(context),
              ),
              const Divider(),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 48),
                child: Text(
                  'Not signed in',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const Divider(),
            ListTile(
              leading: const Icon(Icons.login),
              title: const Text('Sign in with Google'),
              onTap: () => context.go('/login'),
            ),
            ListTile(
              leading: const Icon(Icons.cast),
              title: const Text('Riproduci su TV / speaker (Cast)'),
              subtitle: const Text('Scegli dove riprodurre, come YouTube Music'),
              onTap: () => context.go('/cast'),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Close'),
              onTap: () => context.go('/'),
            ),
          ],
        );
      }),
    );
  }
}
