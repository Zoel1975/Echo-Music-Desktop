import 'dart:convert';

/// A 10-band parametric EQ preset. Port of Android `axion/AxionEqScreen.kt`
/// presets + AutoEq profile import.
class EqPreset {
  const EqPreset(this.name, this.gains);
  final String name;
  final List<double> gains; // 10 bands, dB

  Map<String, dynamic> toJson() => {'name': name, 'gains': gains};

  factory EqPreset.fromJson(Map<String, dynamic> j) {
    final raw = (j['gains'] as List?) ?? const [];
    return EqPreset(
      j['name']?.toString() ?? 'Imported',
      raw.map((e) => (e is num ? e.toDouble() : 0.0)).toList(),
    );
  }
}

/// Frequencies of the standard 10-band graphic equalizer.
const eqFrequencies = <double>[
  31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
];

/// Heads-up: these are musically-tuned curves, not measured AutoEq profiles.
class AxionEqService {
  AxionEqService._();

  static const presets = [
    EqPreset('Flat', [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]),
    EqPreset('Bass Boost', [6, 5, 4, 2, 0, 0, 0, 0, 0, 0]),
    EqPreset('Vocal', [-2, -1, 0, 2, 4, 5, 4, 2, 0, -1]),
    EqPreset('Electronic', [4, 3, 0, -1, 0, 2, 3, 3, 2, 1]),
    EqPreset('Acoustic', [-1, 0, 1, 2, 2, 1, 1, 2, 2, 1]),
  ];

  /// Pure: parse an AutoEq-style profile from text (`Preamp: -x dB` +
  /// `Filter N: ... Gain -x dB ...`). Returns a 10-band gain list.
  static List<double> parseAutoEqProfile(String text) {
    final gains = List<double>.filled(10, 0.0);
    for (final line in text.split(RegExp(r'[\r\n]+'))) {
      final gainMatch = RegExp(r'Gain\s*([-+]?\d+(?:\.\d+)?)\s*dB',
              caseSensitive: false)
          .firstMatch(line);
      if (gainMatch == null) continue;
      final freqMatch =
          RegExp(r'Fc\s*(\d+(?:\.\d+)?)\s*Hz', caseSensitive: false)
              .firstMatch(line);
      if (freqMatch == null) continue;
      final freq = double.tryParse(freqMatch.group(1)!) ?? 0;
      final gain = double.tryParse(gainMatch.group(1)!) ?? 0;
      var idx = 0;
      var best = double.infinity;
      for (var i = 0; i < eqFrequencies.length; i++) {
        final d = (eqFrequencies[i] - freq).abs();
        if (d < best) {
          best = d;
          idx = i;
        }
      }
      gains[idx] = gain.clamp(-12.0, 12.0);
    }
    return gains;
  }

  /// Pure: serialize a preset to AutoEq-style text (for export).
  static String toAutoEqText(EqPreset preset) {
    final sb = StringBuffer('Preamp: 0 dB\n');
    for (var i = 0; i < eqFrequencies.length; i++) {
      sb.writeln('Filter ${i + 1}: PEQ Fc ${eqFrequencies[i].toInt()} Hz '
          'Gain ${preset.gains[i]} dB');
    }
    return sb.toString();
  }

  static String encodePreset(EqPreset p) => jsonEncode(p.toJson());
  static EqPreset decodePreset(String s) =>
      EqPreset.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
