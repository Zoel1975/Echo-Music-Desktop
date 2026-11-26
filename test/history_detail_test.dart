import 'package:flutter_test/flutter_test.dart';

import 'package:Echo/services/history_detail.dart';

void main() {
  test('groups history entries by day, most recent first', () {
    final entries = [
      {'title': 'A', 'updatedAt': DateTime(2026, 1, 1).millisecondsSinceEpoch},
      {'title': 'B', 'updatedAt': DateTime(2026, 1, 2).millisecondsSinceEpoch},
      {'title': 'C', 'updatedAt': DateTime(2026, 1, 2).millisecondsSinceEpoch},
    ];
    final grouped = HistoryDetail.groupByDay(entries);
    expect(grouped.keys.toList(), ['2026-01-02', '2026-01-01']);
    expect(grouped['2026-01-02']!.length, 2);
    expect(grouped['2026-01-01']!.length, 1);
  });

  test('counts total plays (falls back to 1)', () {
    final entries = [
      {'plays': 5},
      {'plays': 2},
      {'title': 'no plays field'},
    ];
    expect(HistoryDetail.totalPlays(entries), 8);
  });

  test('unknown timestamps go to Unknown bucket', () {
    final grouped = HistoryDetail.groupByDay([{'title': 'x'}]);
    expect(grouped.containsKey('Unknown'), isTrue);
  });
}
