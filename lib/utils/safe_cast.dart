/// YTMusic JSON comes from `jsonDecode`, so nested lists are `List<dynamic>`
/// even when every element is a `Map`. A direct `as List<Map<String, dynamic>>`
/// throws at runtime; use this converter instead.
List<Map<String, dynamic>> safeMapList(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  final out = <Map<String, dynamic>>[];
  for (final item in value) {
    if (item is Map) out.add(Map<String, dynamic>.from(item));
  }
  return out;
}
