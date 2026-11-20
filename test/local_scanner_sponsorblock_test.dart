import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/local_song_scanner.dart';
import 'package:Echo/services/sponsor_block_service.dart';

void main() {
  group('LocalSongScanner', () {
    test('detects audio extensions', () {
      final s = LocalSongScanner();
      expect(s.isAudioFile('song.mp3'), isTrue);
      expect(s.isAudioFile('track.M4A'), isTrue);
      expect(s.isAudioFile('notes.txt'), isFalse);
    });

    test('parses Artist - Title filename', () {
      final s = LocalSongScanner();
      final p = s.parseName('Daft Punk - Around The World.mp3');
      expect(p.artist, 'Daft Punk');
      expect(p.title, 'Around The World');
      final p2 = s.parseName('Untitled.flac');
      expect(p2.title, 'Untitled');
      expect(p2.artist, 'Unknown artist');
    });

    test('scans a real temp folder for audio files', () async {
      final dir = Directory(
          '${Directory.systemTemp.path}/echo_scan_test_${DateTime.now().microsecondsSinceEpoch}');
      dir.createSync(recursive: true);
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      File('${dir.path}/Artist - Song.mp3').writeAsBytesSync([1, 2, 3]);
      File('${dir.path}/ignore.txt').writeAsStringSync('x');

      final songs = await LocalSongScanner().scan(dir);
      expect(songs.length, 1);
      expect(songs.first['title'], 'Song');
      expect(songs.first['status'], 'LOCAL');
      expect(songs.first['path'], contains('.mp3'));
    });
  });

  group('SponsorBlock', () {
    test('segmentAt finds the covering segment', () {
      final segs = [
        const SponsorSegment(start: 10, end: 20, category: 'sponsor'),
        const SponsorSegment(start: 40, end: 45, category: 'outro'),
      ];
      expect(SponsorBlockService.segmentAt(segs, 15)?.category, 'sponsor');
      expect(SponsorBlockService.segmentAt(segs, 42)?.category, 'outro');
      expect(SponsorBlockService.segmentAt(segs, 25), isNull);
    });
  });
}
