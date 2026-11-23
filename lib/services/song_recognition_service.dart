import 'dart:io';
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'beat_analysis.dart';
import 'local_song_scanner.dart';

class RecognitionHit {
  RecognitionHit({
    required this.title,
    required this.artist,
    required this.score,
    required this.path,
  });

  final String title;
  final String artist;
  final double score;
  final String path;
}

/// Functional offline song recognition: records the microphone via FFmpeg
/// dshow, extracts a spectral landmark fingerprint and matches it against an
/// index of the user's local music. No keys, no external service; it can only
/// identify songs that were indexed (clearly stated in the UI).
class SongRecognitionService {
  SongRecognitionService._();

  static final SongRecognitionService instance = SongRecognitionService._();

  static const boxIndex = 'RECOGNITION_INDEX';
  static const boxHistory = 'RECOGNITION_HISTORY';
  static const sampleRate = 16000;
  static const recordSeconds = 8;

  Future<String?> _findMicrophone() async {
    try {
      final session = await FFmpegKit.execute(
          '-hide_banner -f dshow -list_devices true -i dummy');
      final logs = await session.getLogsAsString();
      final match = RegExp(r'"([^"]+)"\s*\(audio').firstMatch(logs);
      return match?.group(1);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _recordMic() async {
    final device = await _findMicrophone();
    if (device == null) return null;
    final dir = await Directory.systemTemp.createTemp('echo_rec_');
    final out = '${dir.path}${Platform.pathSeparator}mic.pcm';
    try {
      final session = await FFmpegKit.executeWithArguments([
        '-hide_banner',
        '-loglevel',
        'error',
        '-f',
        'dshow',
        '-i',
        'audio=$device',
        '-t',
        '$recordSeconds',
        '-ac',
        '1',
        '-ar',
        '$sampleRate',
        '-f',
        's16le',
        out,
      ]);
      if (!ReturnCode.isSuccess(await session.getReturnCode())) return null;
      final file = File(out);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    } finally {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  Future<Uint8List?> decodeFile(String path, {int seconds = 25}) async {
    final dir = await Directory.systemTemp.createTemp('echo_rec_dec_');
    final out = '${dir.path}${Platform.pathSeparator}sample.pcm';
    try {
      final session = await FFmpegKit.executeWithArguments([
        '-hide_banner',
        '-loglevel',
        'error',
        '-y',
        '-i',
        path,
        '-t',
        '$seconds',
        '-ac',
        '1',
        '-ar',
        '$sampleRate',
        '-f',
        's16le',
        out,
      ]);
      if (!ReturnCode.isSuccess(await session.getReturnCode())) return null;
      final file = File(out);
      if (!await file.exists()) return null;
      return await file.readAsBytes();
    } catch (_) {
      return null;
    } finally {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }

  /// Spectral landmark set: top bins per frame, paired inside 0.64 s buckets.
  static Set<int> fingerprint(Uint8List pcm) {
    final result = <int>{};
    const frame = 1024;
    const hop = 512;
    final samples = pcm.length ~/ 2;
    if (samples < frame * 8) return result;
    final data = ByteData.sublistView(pcm);
    for (var start = 0; start + frame <= samples; start += hop) {
      final re = List<double>.filled(frame, 0.0);
      final im = List<double>.filled(frame, 0.0);
      for (var i = 0; i < frame; i++) {
        re[i] = data.getInt16((start + i) * 2, Endian.little) / 32768.0;
      }
      fft(re, im);
      final magnitudes = List<double>.filled(frame ~/ 2, 0.0);
      for (var i = 1; i < frame ~/ 2; i++) {
        magnitudes[i] = re[i] * re[i] + im[i] * im[i];
      }
      final top = <int>[];
      for (var i = 8; i < frame ~/ 2 && top.length < 6; i++) {
        var insertAt = top.length;
        for (var j = 0; j < top.length; j++) {
          if (magnitudes[i] > magnitudes[top[j]]) {
            insertAt = j;
            break;
          }
        }
        if (insertAt < top.length) {
          top.insert(insertAt, i);
          if (top.length > 6) top.removeLast();
        }
      }
      final bucket = (start ~/ hop) ~/ 20;
      for (var i = 0; i < top.length; i++) {
        for (var j = i + 1; j < top.length; j++) {
          final pair = (top[i] << 8) | top[j];
          result.add((pair << 8) | (bucket & 0xff));
        }
      }
    }
    return result;
  }

  int get indexedCount =>
      Hive.isBoxOpen(boxIndex) ? Hive.box(boxIndex).length : 0;

  Future<int> indexLibrary({void Function(int done, int total)? onProgress}) async {
    if (!Hive.isBoxOpen(boxIndex)) await Hive.openBox(boxIndex);
    final dir = await Directory(
      '${Platform.environment['USERPROFILE'] ?? Directory.systemTemp.path}\\Music',
    ).exists()
        ? Directory(
            '${Platform.environment['USERPROFILE'] ?? Directory.systemTemp.path}\\Music')
        : Directory.systemTemp;
    final songs = await LocalSongScanner().scan(dir);
    final box = Hive.box(boxIndex);
    var done = 0;
    for (final song in songs) {
      final path = song['path']?.toString();
      if (path == null) continue;
      final pcm = await decodeFile(path);
      if (pcm != null) {
        final hashes = fingerprint(pcm).toList();
        if (hashes.isNotEmpty) {
          await box.put(path, {
            'title': song['title'],
            'artist': song['artists'] is List && song['artists'].isNotEmpty
                ? song['artists'].first['name']
                : '',
            'hashes': hashes,
          });
        }
      }
      done++;
      onProgress?.call(done, songs.length);
    }
    return box.length;
  }

  Future<RecognitionHit?> recognize() async {
    if (!Hive.isBoxOpen(boxIndex)) await Hive.openBox(boxIndex);
    final box = Hive.box(boxIndex);
    if (box.isEmpty) return null;
    final mic = await _recordMic();
    if (mic == null) return null;
    final query = fingerprint(mic);
    if (query.isEmpty) return null;

    RecognitionHit? best;
    for (final entry in box.toMap().entries) {
      final map = entry.value;
      if (map is! Map) continue;
      final stored = (map['hashes'] as List?)?.toSet() ?? <int>{};
      if (stored.isEmpty) continue;
      final intersection = query.intersection(stored).length;
      final score = intersection / (query.length + stored.length - intersection);
      if (score <= 0 || (best != null && score <= best.score)) continue;
      best = RecognitionHit(
        title: map['title']?.toString() ?? 'Sconosciuto',
        artist: map['artist']?.toString() ?? '',
        score: score,
        path: entry.key.toString(),
      );
    }
    return best;
  }

  Future<void> saveHistory(RecognitionHit hit) async {
    if (!Hive.isBoxOpen(boxHistory)) await Hive.openBox(boxHistory);
    await Hive.box(boxHistory).add({
      'title': hit.title,
      'artist': hit.artist,
      'score': hit.score,
      'path': hit.path,
      'recognizedAt': DateTime.now().toIso8601String(),
    });
  }
}
