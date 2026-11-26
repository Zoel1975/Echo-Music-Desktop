import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:Echo/services/update_service/models/update_info.dart';
import 'package:Echo/services/update_service/widgets/update_checking.dart';
import 'package:Echo/services/update_service/widgets/update_dialog.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';

/// Update checks talk to THIS project's GitHub releases, not to the upstream
/// Android repository. The old upstream JSON manifest URL returned 404, so the
/// auto-check never found anything and the manual check always claimed the app
/// was up to date.
class UpdateService {
  static const String owner = 'ItsZale0';
  static const String repo = 'Echo-Music-Desktop';
  static const String latestReleaseApi =
      'https://api.github.com/repos/$owner/$repo/releases/latest';
  static const String releasesPage =
      'https://github.com/$owner/$repo/releases';
  static const String installerAsset = 'EchoMusicSetup.exe';

  /* ─────────────────────────────────────────────
   * 1️⃣ PURE UPDATE CHECK (NO UI)
   * ───────────────────────────────────────────── */
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final package = await PackageInfo.fromPlatform();
      final currentVersion = Version.parse(package.version);

      final response = await http.get(
        Uri.parse(latestReleaseApi),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'Echo-Music-Desktop-update-check',
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return fromReleaseJson(data, currentVersion);
    } catch (e) {
      debugPrint('Error checking for update: $e');
      return null;
    }
  }

  /// Pure version/asset parser, unit-testable without network or PackageInfo.
  static UpdateInfo? fromReleaseJson(
      Map<String, dynamic> data, Version currentVersion) {
    final tag = data['tag_name']?.toString() ?? '';
    // GitHub tags are normally "v1.0.0"; semver needs "1.0.0".
    final cleanTag = tag.startsWith('v') ? tag.substring(1) : tag;
    Version? remoteVersion;
    try {
      remoteVersion = Version.parse(cleanTag);
    } catch (_) {
      return null;
    }
    // Equal or older tags are not an update (prevents a false prompt from an
    // old release, a draft or build metadata).
    if (remoteVersion <= currentVersion) return null;

    String downloadUrl = releasesPage;
    final assets = data['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is Map && asset['name']?.toString() == installerAsset) {
          downloadUrl = asset['browser_download_url']?.toString() ?? releasesPage;
          break;
        }
      }
    }

    return UpdateInfo(
      version: remoteVersion,
      name: data['name']?.toString() ?? 'New update available',
      body: data['body']?.toString() ??
          'A new version of Echo Music Desktop is available.',
      publishedAt: data['published_at']?.toString() ?? '',
      downloadUrl: downloadUrl,
    );
  }

  /* ─────────────────────────────────────────────
   * 2️⃣ AUTO CHECK (NO LOADER)
   * ───────────────────────────────────────────── */
  static Future<void> autoCheck(BuildContext context) async {
    final update = await checkForUpdate();
    if (update == null || !context.mounted) return;

    await showUpdateDialog(context, update);
  }

  /* ─────────────────────────────────────────────
   * 3️⃣ MANUAL CHECK (SHOW LOADER)
   * ───────────────────────────────────────────── */
  static Future<void> manualCheck(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: false,
      builder: (_) => const UpdateCheckingDialog(),
    );

    final update = await checkForUpdate();

    if (!context.mounted) return;
    Navigator.pop(context); // close loader

    if (update != null) {
      await showUpdateDialog(context, update);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already on the latest version')),
      );
    }
  }

  /* ─────────────────────────────────────────────
   * 4️⃣ DIALOG
   * ───────────────────────────────────────────── */
  static Future<void> showUpdateDialog(
    BuildContext context,
    UpdateInfo info,
  ) {
    return showDialog(
      context: context,
      useRootNavigator: false,
      builder: (_) => UpdateDialog(info),
    );
  }
}
