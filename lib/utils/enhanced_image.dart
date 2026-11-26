import 'safe_cast.dart';

/// Request a Googleusercontent thumbnail at the pixel size actually needed.
/// YouTube thumbnails come in many encodings (`w60-h60`, `w120-h120`,
/// `=s192`, ...); a fixed list of replacements used to leave small URLs
/// untouched, which is why playlist and album covers looked blurry.
String getEnhancedImage(String imageUrl,
    {String quality = 'high', double? width, double? dp}) {
  final url = imageUrl.trim();
  if (width != null) {
    final size = ((dp ?? 1) * width).ceil().clamp(64, 1600);
    return url
        .replaceAll(RegExp(r'w\d+-h\d+'), 'w$size-h$size')
        .replaceAll(RegExp(r'=s\d+'), '=s$size');
  }
  const sizes = {'high': 800, 'medium': 400, 'low': 120};
  final size = sizes[quality] ?? 800;
  return url
      .replaceAll(RegExp(r'w\d+-h\d+'), 'w$size-h$size')
      .replaceAll(RegExp(r'=s\d+'), '=s$size');
}

/// Pick the largest thumbnail available instead of `thumbnails.first`, which
/// is usually the 60x60 or 120x120 variant.
String? bestThumbnailUrl(dynamic thumbnails, {double? width, double? dp}) {
  final items = safeMapList(thumbnails);
  if (items.isEmpty) return null;
  var best = items.first;
  var bestArea = 0;
  for (final item in items) {
    final w = (item['width'] is num) ? (item['width'] as num).toInt() : 0;
    final h = (item['height'] is num) ? (item['height'] as num).toInt() : 0;
    final area = w * h;
    if (area > bestArea) {
      bestArea = area;
      best = item;
    }
  }
  final url = best['url']?.toString() ?? '';
  if (url.isEmpty) return null;
  return width != null
      ? getEnhancedImage(url, width: width, dp: dp)
      : getEnhancedImage(url);
}
