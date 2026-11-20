/// Pure helpers for Android `QueueExt` / `RadioQueuePageFilter`: filter and
/// de-duplicate the playback queue. No Flutter dependency, unit-testable.
class QueueFilter {
  QueueFilter._();

  /// Remove duplicate tracks by videoId, keeping the first occurrence.
  static List<T> dedupe<T>(List<T> items, String Function(T) idOf) {
    final seen = <String>{};
    return items.where((item) {
      final id = idOf(item);
      if (seen.contains(id)) return false;
      seen.add(id);
      return true;
    }).toList();
  }

  /// Filter by a case-insensitive query against title/artist getters.
  static List<T> search<T>(
    List<T> items,
    String query, {
    required String Function(T) titleOf,
    String Function(T)? artistOf,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List<T>.from(items);
    return items.where((item) {
      final title = titleOf(item).toLowerCase();
      final artist = (artistOf?.call(item) ?? '').toLowerCase();
      return title.contains(q) || artist.contains(q);
    }).toList();
  }

  /// Radio filter: keep only items from a given source (e.g. similar content).
  static List<T> bySource<T>(
    List<T> items,
    String? source, {
    required String? Function(T) sourceOf,
  }) {
    if (source == null || source.isEmpty) return List<T>.from(items);
    return items.where((item) => sourceOf(item) == source).toList();
  }
}
