/// Pure helper for Android `DetailedListeningHistoryScreen.kt`: groups local
/// history entries by day and computes replay counts. No Flutter dependency.
class HistoryDetail {
  HistoryDetail._();

  static String dayKey(dynamic updatedAt) {
    if (updatedAt is! num || updatedAt <= 0) return 'Unknown';
    final dt = DateTime.fromMillisecondsSinceEpoch(updatedAt.toInt());
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  static Map<String, List<Map<String, dynamic>>> groupByDay(
    Iterable<dynamic> entries,
  ) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final e in entries) {
      if (e is! Map) continue;
      final key = dayKey(e['updatedAt']);
      grouped.putIfAbsent(key, () => []).add(Map<String, dynamic>.from(e));
    }
    // Most recent day first.
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final k in keys) k: grouped[k]!};
  }

  static int totalPlays(Iterable<dynamic> entries) => entries
      .whereType<Map>()
      .fold<int>(0, (sum, e) => sum + ((e['plays'] as num?)?.toInt() ?? 1));
}
