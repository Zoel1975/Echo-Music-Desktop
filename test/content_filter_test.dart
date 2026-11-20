import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:Echo/services/content_filter_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final dir = Directory('${Directory.systemTemp.path}/echo_filter_test');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    Hive.init(dir.path);
    for (final n in ['BLOCKED_ARTISTS', 'DISLIKED_SONGS']) {
      if (!Hive.isBoxOpen(n)) await Hive.openBox(n);
    }
  });

  test('blocked artists and disliked songs persist and query correctly',
      () async {
    final service = ContentFilterService();
    await service.clearBlockedArtists();
    await service.clearDislikedSongs();

    await service.blockArtist('Bad Artist');
    expect(service.isArtistBlocked('bad artist'), isTrue);
    expect(service.blockedArtists, contains('bad artist'));

    await service.dislikeSong('abc123', 'Bad Song');
    expect(service.isSongDisliked('abc123'), isTrue);
    expect(service.dislikedSongs, contains('abc123'));

    await service.unblockArtist('Bad Artist');
    expect(service.isArtistBlocked('bad artist'), isFalse);
    await service.likeSong('abc123');
    expect(service.isSongDisliked('abc123'), isFalse);
  });
}
