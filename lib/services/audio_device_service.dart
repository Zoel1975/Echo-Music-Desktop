import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A Windows audio output endpoint as reported by WASAPI.
@immutable
class AudioDeviceEntry {
  const AudioDeviceEntry({required this.id, required this.name});
  final String id;
  final String name;

  @override
  String toString() => name;
}

/// Enumerates and selects the system's audio output devices.
///
/// On Windows this talks to a native MethodChannel backed by WASAPI
/// (`IMMDeviceEnumerator`). On other platforms it degrades gracefully to a
/// single "System default" entry. Selection sets the process/system default
/// render endpoint, which just_audio (media_kit) then follows.
class AudioDeviceService {
  static const MethodChannel _channel = MethodChannel('com.echo/audio_devices');
  static const String _autoId = 'auto';
  static const String _autoName = 'System default';

  bool get isSupported => defaultTargetPlatform == TargetPlatform.windows;

  Future<List<AudioDeviceEntry>> listDevices() async {
    if (!isSupported) {
      return const [AudioDeviceEntry(id: _autoId, name: _autoName)];
    }
    try {
      final List<dynamic>? res = await _channel.invokeListMethod<dynamic>('list');
      if (res == null || res.isEmpty) {
        return const [AudioDeviceEntry(id: _autoId, name: _autoName)];
      }
      final devices = <AudioDeviceEntry>[
        const AudioDeviceEntry(id: _autoId, name: _autoName),
      ];
      for (final item in res) {
        if (item is Map) {
          final id = item['id']?.toString() ?? '';
          final name = item['name']?.toString() ?? id;
          if (id.isNotEmpty) devices.add(AudioDeviceEntry(id: id, name: name));
        } else if (item is String && item.isNotEmpty) {
          devices.add(AudioDeviceEntry(id: item, name: item));
        }
      }
      return devices;
    } catch (e) {
      debugPrint('[audio_devices] list failed: $e');
      return const [AudioDeviceEntry(id: _autoId, name: _autoName)];
    }
  }

  Future<void> selectDevice(String id) async {
    if (!isSupported || id == _autoId) return;
    try {
      await _channel.invokeMethod<void>('select', <String, dynamic>{'id': id});
    } catch (e) {
      debugPrint('[audio_devices] select failed: $e');
    }
  }
}
