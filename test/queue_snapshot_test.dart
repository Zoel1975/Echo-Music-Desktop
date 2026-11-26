import 'package:Echo/services/queue_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QueueSnapshot', () {
    const snapshot = QueueSnapshot(
      songs: [
        {'videoId': 'a', 'title': 'First'},
        {'videoId': 'b', 'title': 'Second'},
      ],
      index: 1,
      positionMs: 42000,
      wasPlaying: true,
    );

    test('round-trips through Hive-compatible maps', () {
      final restored = QueueSnapshot.fromMap(snapshot.toMap());
      expect(restored.songs.length, 2);
      expect(restored.songs.last['videoId'], 'b');
      expect(restored.index, 1);
      expect(restored.positionMs, 42000);
      expect(restored.wasPlaying, isTrue);
      expect(restored.isValid, isTrue);
    });

    test('rejects an out-of-range index', () {
      expect(
        QueueSnapshot.fromMap({
          'songs': [
            {'videoId': 'a'}
          ],
          'index': 5,
        }).isValid,
        isFalse,
      );
    });

    test('handles an empty or malformed snapshot', () {
      final empty = QueueSnapshot.fromMap({});
      expect(empty.isValid, isFalse);
      expect(empty.index, 0);
      expect(empty.positionMs, 0);
      expect(empty.wasPlaying, isFalse);
    });
  });
}
