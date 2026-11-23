import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/settings_manager.dart';
import '../ytmusic/ytmusic.dart';

Box _box = Hive.box('SETTINGS');
DateTime _lastTrim = DateTime.fromMillisecondsSinceEpoch(0);

/// Android's "History duration (months)": drop local history entries older
/// than the configured window. Runs at most once an hour so adding a song
/// never pays the full scan cost.
Future<void> trimLocalHistory() async {
  final now = DateTime.now();
  if (now.difference(_lastTrim).inHours < 1) return;
  _lastTrim = now;
  final months = GetIt.I<SettingsManager>().historyDuration.round();
  final cutoff = DateTime(now.year, now.month - months, now.day)
      .millisecondsSinceEpoch;
  final box = Hive.box('SONG_HISTORY');
  final stale = <String>[];
  for (final entry in box.toMap().entries) {
    final ts = entry.value is Map ? entry.value['updatedAt'] : null;
    if (ts is int && ts < cutoff) stale.add(entry.key.toString());
  }
  if (stale.isNotEmpty) await box.deleteAll(stale);
}

Future<void> addHistory(Map song) async {
  if (_box.get('PLAYBACK_HISTORY', defaultValue: true)) {
    await addLocalHistory(song);
    unawaited(trimLocalHistory());
  }
  if (_box.get('PERSONALISED_CONTENT', defaultValue: true) &&
      song['status'] != 'DOWNLOADED') {
    GetIt.I<YTMusic>().addYoutubeHistory(song['videoId']);
  }
}

Future<void> addLocalHistory(Map song) async {
  Box box = Hive.box('SONG_HISTORY');
  Map? oldState = box.get(song['videoId']);
  int timestamp = DateTime.now().millisecondsSinceEpoch;
  if (oldState != null) {
    await box.put(song['videoId'],
        {...oldState, 'plays': oldState['plays'] + 1, 'updatedAt': timestamp});
  } else {
    await box.put(song['videoId'],
        {...song, 'plays': 1, 'CreatedAt': timestamp, 'updatedAt': timestamp});
  }
}
