import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// The sections a user can put on the Home screen, in any order.
/// Android shows a fixed home feed; on desktop we let the user choose between
/// the YouTube Music feed, Billboard charts, liked songs and own playlists.
enum HomeSectionKind { charts, playlists, likedSongs, feed }

extension HomeSectionKindX on HomeSectionKind {
  String get key => switch (this) {
        HomeSectionKind.charts => 'charts',
        HomeSectionKind.playlists => 'playlists',
        HomeSectionKind.likedSongs => 'likedSongs',
        HomeSectionKind.feed => 'feed',
      };

  String get label => switch (this) {
        HomeSectionKind.charts => 'Classifiche Billboard',
        HomeSectionKind.playlists => 'Le tue playlist',
        HomeSectionKind.likedSongs => 'Brani preferiti',
        HomeSectionKind.feed => 'Scoperta YouTube Music',
      };

  IconData get icon => switch (this) {
        HomeSectionKind.charts => Icons.bar_chart,
        HomeSectionKind.playlists => Icons.queue_music,
        HomeSectionKind.likedSongs => Icons.favorite,
        HomeSectionKind.feed =>Icons.explore,
      };

  static HomeSectionKind? fromKey(String key) {
    for (final value in HomeSectionKind.values) {
      if (value.key == key) return value;
    }
    return null;
  }
}

@immutable
class HomeSectionsConfig {
  const HomeSectionsConfig(this.order);

  /// Defaults: your music first, then the YouTube Music feed. Charts are
  /// still available, just not forced at the top of the home screen.
  static const defaults = HomeSectionsConfig([
    HomeSectionKind.likedSongs,
    HomeSectionKind.playlists,
    HomeSectionKind.feed,
  ]);

  final List<HomeSectionKind> order;

  static const storageKey = 'HOME_SECTIONS';

  static HomeSectionsConfig decode(dynamic raw) {
    if (raw is! List) return defaults;
    final parsed = <HomeSectionKind>[];
    for (final value in raw) {
      final kind = HomeSectionKindX.fromKey(value.toString());
      if (kind != null && !parsed.contains(kind)) parsed.add(kind);
    }
    // Always keep the feed available if the saved list omitted every section.
    if (parsed.isEmpty) return defaults;
    return HomeSectionsConfig(parsed);
  }

  List<String> encode() => order.map((k) => k.key).toList();

  bool isEnabled(HomeSectionKind kind) => order.contains(kind);

  HomeSectionsConfig toggle(HomeSectionKind kind) {
    final next = List<HomeSectionKind>.from(order);
    if (next.contains(kind)) {
      next.remove(kind);
    } else {
      next.add(kind);
    }
    return HomeSectionsConfig(next.isEmpty ? [kind] : next);
  }

  HomeSectionsConfig move(HomeSectionKind kind, int delta) {
    final next = List<HomeSectionKind>.from(order);
    final i = next.indexOf(kind);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= next.length) return this;
    next
      ..removeAt(i)
      ..insert(j, kind);
    return HomeSectionsConfig(next);
  }

  static HomeSectionsConfig load() {
    try {
      if (!Hive.isBoxOpen('SETTINGS')) return defaults;
      return decode(Hive.box('SETTINGS').get(storageKey));
    } catch (_) {
      return defaults;
    }
  }

  Future<void> save() async {
    try {
      if (!Hive.isBoxOpen('SETTINGS')) return;
      await Hive.box('SETTINGS').put(storageKey, encode());
    } catch (_) {}
  }
}
