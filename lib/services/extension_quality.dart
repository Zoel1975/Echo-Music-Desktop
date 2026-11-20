/// Pure quality resolution for the Android `ExtensionManager` "high quality
/// (320 kbps)" switch. When the extension toggle is on, streaming is forced to
/// the highest available bitrate; Data Saver still wins (user's explicit
/// bandwidth preference).
class ExtensionQuality {
  ExtensionQuality._();

  static String resolve({
    required bool dataSaver,
    required bool highQuality,
    required String configured,
  }) {
    if (dataSaver) return 'low';
    if (highQuality) return 'high';
    return configured;
  }
}
