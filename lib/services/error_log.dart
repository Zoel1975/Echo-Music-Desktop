import 'dart:io';

/// Persistent, append-only error log for diagnosing runtime failures in the
/// installed app (release builds have no console). Written to
/// `%LOCALAPPDATA%/com.echo/Echo Music/error.log`.
class ErrorLog {
  ErrorLog._();

  static String get _path {
    final base = Platform.environment['LOCALAPPDATA'] ??
        Directory.systemTemp.path;
    return '$base\\com.echo\\Echo Music\\error.log';
  }

  static void write(String text) {
    try {
      final file = File(_path);
      final dir = file.parent;
      if (!dir.existsSync()) dir.createSync(recursive: true);
      file.writeAsStringSync(
        '${DateTime.now().toIso8601String()} $text\n---\n',
        mode: FileMode.append,
      );
    } catch (_) {}
  }

  /// Most recent [maxChars] of the log, for a diagnostic probe/UI.
  static String read({int maxChars = 8000}) {
    try {
      final file = File(_path);
      if (!file.existsSync()) return '';
      final text = file.readAsStringSync();
      return text.length <= maxChars
          ? text
          : text.substring(text.length - maxChars);
    } catch (_) {
      return '';
    }
  }

  static void clear() {
    try {
      final file = File(_path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }
}
