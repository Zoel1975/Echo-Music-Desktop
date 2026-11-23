import 'dart:io';

import 'package:flutter/foundation.dart';

import 'beat_analysis.dart';

class AutomixLogEntry {
  const AutomixLogEntry({
    required this.time,
    required this.message,
    this.level = 'INFO',
  });

  final DateTime time;
  final String message;
  final String level;

  String get formatted =>
      '${time.toIso8601String().substring(11, 23)} [$level] $message';
}

/// Mirrors Android's `MusicService.AutomixDebugInfo` plus a rolling log, so the
/// whole transition can be inspected from the Player settings screen.
class AutomixDebug extends ChangeNotifier {
  AutomixDebug._();

  static final AutomixDebug instance = AutomixDebug._();

  final List<AutomixLogEntry> _entries = <AutomixLogEntry>[];

  String status = 'IDLE';
  bool crossfadeEnabled = false;
  bool automixEnabled = false;
  bool preArmed = false;
  bool handoffRunning = false;
  bool fading = false;
  int? leadMs;
  int? blendMs;
  int? triggerTimeMs;
  int? incomingStartMs;
  double? tempoRatio;
  double mainVolume = 0;
  double outVolume = 0;
  BeatAnalysisResult? outBeat;
  BeatAnalysisResult? inBeat;
  String? lastError;
  String? harmonicChoice;
  double? harmonicScore;

  List<AutomixLogEntry> get entries => List.unmodifiable(_entries);

  void log(String message, {String level = 'INFO'}) {
    final entry = AutomixLogEntry(
      time: DateTime.now(),
      message: message,
      level: level,
    );
    _entries.insert(0, entry);
    if (_entries.length > 150) _entries.removeLast();
    _writeFile(entry.formatted);
    notifyListeners();
  }

  void set({
    String? status,
    bool? crossfadeEnabled,
    bool? automixEnabled,
    bool? preArmed,
    bool? handoffRunning,
    bool? fading,
    int? leadMs,
    int? blendMs,
    int? triggerTimeMs,
    int? incomingStartMs,
    double? tempoRatio,
    double? mainVolume,
    double? outVolume,
    BeatAnalysisResult? outBeat,
    BeatAnalysisResult? inBeat,
    String? lastError,
    String? harmonicChoice,
    double? harmonicScore,
  }) {
    this.status = status ?? this.status;
    this.crossfadeEnabled = crossfadeEnabled ?? this.crossfadeEnabled;
    this.automixEnabled = automixEnabled ?? this.automixEnabled;
    this.preArmed = preArmed ?? this.preArmed;
    this.handoffRunning = handoffRunning ?? this.handoffRunning;
    this.fading = fading ?? this.fading;
    this.leadMs = leadMs ?? this.leadMs;
    this.blendMs = blendMs ?? this.blendMs;
    this.triggerTimeMs = triggerTimeMs ?? this.triggerTimeMs;
    this.incomingStartMs = incomingStartMs ?? this.incomingStartMs;
    this.tempoRatio = tempoRatio ?? this.tempoRatio;
    this.mainVolume = mainVolume ?? this.mainVolume;
    this.outVolume = outVolume ?? this.outVolume;
    this.outBeat = outBeat ?? this.outBeat;
    this.inBeat = inBeat ?? this.inBeat;
    this.lastError = lastError ?? this.lastError;
    this.harmonicChoice = harmonicChoice ?? this.harmonicChoice;
    this.harmonicScore = harmonicScore ?? this.harmonicScore;
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    lastError = null;
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
        'status': status,
        'crossfadeEnabled': crossfadeEnabled,
        'automixEnabled': automixEnabled,
        'preArmed': preArmed,
        'handoffRunning': handoffRunning,
        'fading': fading,
        'leadMs': leadMs,
        'blendMs': blendMs,
        'triggerTimeMs': triggerTimeMs,
        'incomingStartMs': incomingStartMs,
        'tempoRatio': tempoRatio,
        'mainVolume': mainVolume,
        'outVolume': outVolume,
        'outBeat': outBeat?.toJson(),
        'inBeat': inBeat?.toJson(),
        'lastError': lastError,
        'harmonicChoice': harmonicChoice,
        'harmonicScore': harmonicScore,
        'log': _entries.take(40).map((e) => e.formatted).toList(),
      };

  void _writeFile(String line) {
    try {
      final base = Platform.environment['LOCALAPPDATA'] ??
          Directory.systemTemp.path;
      final file = File('$base\\com.echo\\Echo Music\\automix.log');
      if (!file.parent.existsSync()) file.parent.createSync(recursive: true);
      file.writeAsStringSync('$line\n', mode: FileMode.append);
    } catch (_) {}
  }
}
