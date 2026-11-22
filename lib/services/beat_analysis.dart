import 'dart:math' as math;

/// Beat-grid analysis ported from Echo Android's `BeatAnalyzer` (classical DSP:
/// STFT -> spectral flux -> autocorrelation tempo -> comb-filter phase).
/// Kept pure so it can be unit-tested with synthetic PCM.
class BeatAnalysisResult {
  const BeatAnalysisResult({
    required this.bpm,
    required this.firstBeatOffsetMs,
    required this.confidence,
    this.mixInMs,
    this.mixOutMs,
    this.keyPitchClass,
    this.keyIsMinor,
  });

  final double bpm;
  final double firstBeatOffsetMs;
  final double confidence;

  /// Energy-based mix points (Android BeatAnalyzer HEAD/TAIL energy scan).
  final int? mixInMs;
  final int? mixOutMs;

  /// 0=C, 1=C#, ..., 9=A, 11=B (null when chroma is too weak).
  final int? keyPitchClass;
  final bool? keyIsMinor;

  double get beatPeriodMs => 60000.0 / bpm;

  String? get keyLabel {
    if (keyPitchClass == null) return null;
    const names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    return '${names[keyPitchClass!.clamp(0, 11)]}${keyIsMinor == true ? 'm' : ''}';
  }

  Map<String, dynamic> toJson() => {
        'bpm': bpm,
        'firstBeatOffsetMs': firstBeatOffsetMs,
        'confidence': confidence,
        'mixInMs': mixInMs,
        'mixOutMs': mixOutMs,
        'keyPitchClass': keyPitchClass,
        'keyIsMinor': keyIsMinor,
      };

  factory BeatAnalysisResult.fromJson(Map<String, dynamic> json) =>
      BeatAnalysisResult(
        bpm: (json['bpm'] as num?)?.toDouble() ?? 120,
        firstBeatOffsetMs:
            (json['firstBeatOffsetMs'] as num?)?.toDouble() ?? 0,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        mixInMs: (json['mixInMs'] as num?)?.toInt(),
        mixOutMs: (json['mixOutMs'] as num?)?.toInt(),
        keyPitchClass: (json['keyPitchClass'] as num?)?.toInt(),
        keyIsMinor: json['keyIsMinor'] as bool?,
      );
}

/// In-place iterative radix-2 FFT (real input in [re], imaginary in [im]).
void fft(List<double> re, List<double> im) {
  final n = re.length;
  if (n < 2 || (n & (n - 1)) != 0) {
    throw ArgumentError('FFT size must be a power of two');
  }
  for (var i = 1, j = 0; i < n; i++) {
    var bit = n >> 1;
    while (j & bit != 0) {
      j ^= bit;
      bit >>= 1;
    }
    j ^= bit;
    if (i < j) {
      final tr = re[i];
      re[i] = re[j];
      re[j] = tr;
      final ti = im[i];
      im[i] = im[j];
      im[j] = ti;
    }
  }
  for (var len = 2; len <= n; len <<= 1) {
    final angle = -2 * math.pi / len;
    final wLenRe = math.cos(angle);
    final wLenIm = math.sin(angle);
    for (var i = 0; i < n; i += len) {
      var wRe = 1.0;
      var wIm = 0.0;
      for (var k = 0; k < len ~/ 2; k++) {
        final uRe = re[i + k];
        final uIm = im[i + k];
        final vRe = re[i + k + len ~/ 2] * wRe -
            im[i + k + len ~/ 2] * wIm;
        final vIm = re[i + k + len ~/ 2] * wIm +
            im[i + k + len ~/ 2] * wRe;
        re[i + k] = uRe + vRe;
        im[i + k] = uIm + vIm;
        re[i + k + len ~/ 2] = uRe - vRe;
        im[i + k + len ~/ 2] = uIm - vIm;
        final nextRe = wRe * wLenRe - wIm * wLenIm;
        wIm = wRe * wLenIm + wIm * wLenRe;
        wRe = nextRe;
      }
    }
  }
}

/// Positive spectral flux onset envelope (one value per [hop] samples).
List<double> spectralFlux(
  List<double> mono, {
  int fftSize = 1024,
  int hop = 512,
}) {
  if (mono.length < fftSize * 4) return const <double>[];
  final window = List<double>.generate(
    fftSize,
    (i) => 0.5 - 0.5 * math.cos(2 * math.pi * i / (fftSize - 1)),
  );
  final flux = <double>[];
  final previous = List<double>.filled(fftSize ~/ 2, 0.0);
  for (var start = 0; start + fftSize <= mono.length; start += hop) {
    final re = List<double>.filled(fftSize, 0.0);
    final im = List<double>.filled(fftSize, 0.0);
    for (var i = 0; i < fftSize; i++) {
      re[i] = mono[start + i] * window[i];
    }
    fft(re, im);
    var sum = 0.0;
    for (var i = 0; i < fftSize ~/ 2; i++) {
      final magnitude = math.sqrt(re[i] * re[i] + im[i] * im[i]);
      final diff = magnitude - previous[i];
      if (diff > 0) sum += diff;
      previous[i] = magnitude;
    }
    flux.add(sum / (fftSize ~/ 2));
  }
  return flux;
}

({double bpm, double confidence}) estimateTempo(
  List<double> flux,
  double frameRate, {
  double minBpm = 60,
  double maxBpm = 180,
}) {
  if (flux.length < 32) return (bpm: 120, confidence: 0);
  final mean = flux.reduce((a, b) => a + b) / flux.length;
  final centered = flux.map((v) => v - mean).toList();
  var bestBpm = 120.0;
  var bestScore = double.negativeInfinity;
  for (var bpm = minBpm; bpm <= maxBpm; bpm += 0.5) {
    final lag = (frameRate * 60.0 / bpm).round();
    if (lag < 2 || lag >= centered.length ~/ 2) continue;
    var dot = 0.0;
    var norm = 0.0;
    for (var i = 0; i + lag < centered.length; i++) {
      dot += centered[i] * centered[i + lag];
      norm += centered[i] * centered[i];
    }
    final score = norm > 0 ? dot / norm : 0.0;
    if (score > bestScore) {
      bestScore = score;
      bestBpm = bpm;
    }
  }
  // Fold into the canonical 70-140 range like Android does.
  while (bestBpm < 70) bestBpm *= 2;
  while (bestBpm > 140) bestBpm /= 2;
  return (bpm: bestBpm, confidence: bestScore.clamp(0.0, 1.0));
}

/// Comb-filter phase: where in the beat period the onsets line up.
double estimateBeatPhase(List<double> flux, double frameRate, double bpm) {
  if (flux.isEmpty) return 0;
  final period = (frameRate * 60.0 / bpm).round().clamp(2, flux.length ~/ 2);
  var bestPhase = 0;
  var bestSum = double.negativeInfinity;
  for (var phase = 0; phase < period; phase++) {
    var sum = 0.0;
    for (var i = phase; i < flux.length; i += period) {
      sum += flux[i];
    }
    if (sum > bestSum) {
      bestSum = sum;
      bestPhase = phase;
    }
  }
  return bestPhase / frameRate * 1000.0;
}

/// First block whose RMS energy rises above 35% of the loudest block: the
/// start of the real song, after the intro (Android HEAD_WINDOW energy scan).
int? energyMixIn(
  List<double> mono,
  int sampleRate, {
  int blockMs = 500,
  int maxSkipMs = 20000,
}) {
  final block = sampleRate * blockMs ~/ 1000;
  if (block <= 0 || mono.length < block * 3) return null;
  final energies = <double>[];
  for (var start = 0; start + block <= mono.length; start += block) {
    var sum = 0.0;
    for (var i = start; i < start + block; i++) {
      sum += mono[i] * mono[i];
    }
    energies.add(math.sqrt(sum / block));
  }
  final peak = energies.reduce(math.max);
  if (peak <= 0) return null;
  final threshold = peak * 0.35;
  for (var i = 0; i < energies.length; i++) {
    if (energies[i] >= threshold) {
      return math.min(i * blockMs, maxSkipMs);
    }
  }
  return null;
}

/// Last energetic block of the tail window, converted to an absolute position
/// in the track (Android TAIL_WINDOW energy scan).
int? energyMixOut(
  List<double> tail,
  int sampleRate,
  int durationMs, {
  int blockMs = 500,
  int maxCutMs = 45000,
}) {
  final block = sampleRate * blockMs ~/ 1000;
  if (block <= 0 || tail.length < block * 2 || durationMs <= 0) return null;
  final energies = <double>[];
  for (var start = 0; start + block <= tail.length; start += block) {
    var sum = 0.0;
    for (var i = start; i < start + block; i++) {
      sum += tail[i] * tail[i];
    }
    energies.add(math.sqrt(sum / block));
  }
  final peak = energies.reduce(math.max);
  if (peak <= 0) return null;
  final threshold = peak * 0.35;
  var last = -1;
  for (var i = 0; i < energies.length; i++) {
    if (energies[i] >= threshold) last = i;
  }
  if (last < 0) return null;
  final windowMs = (tail.length / sampleRate * 1000).round();
  final absolute = durationMs - windowMs + last * blockMs + blockMs ~/ 2;
  if (absolute < durationMs - maxCutMs) return null;
  return absolute.clamp(0, durationMs).round();
}

/// Krumhansl-Schmuckler chroma correlation: 0=C ... 11=B.
({int pitchClass, bool minor})? estimateKey(
  List<double> mono,
  int sampleRate, {
  int fftSize = 4096,
}) {
  if (mono.length < fftSize * 4) return null;
  final chroma = List<double>.filled(12, 0.0);
  for (var start = 0; start + fftSize <= mono.length; start += fftSize ~/ 2) {
    final re = List<double>.filled(fftSize, 0.0);
    final im = List<double>.filled(fftSize, 0.0);
    for (var i = 0; i < fftSize; i++) {
      re[i] = mono[start + i];
    }
    fft(re, im);
    for (var i = 1; i < fftSize ~/ 2; i++) {
      final freq = i * sampleRate / fftSize;
      if (freq < 80 || freq > 2000) continue;
      final magnitude = math.sqrt(re[i] * re[i] + im[i] * im[i]);
      final midi = 69 + 12 * math.log(freq / 440) / math.ln2;
      final pc = midi.round() % 12;
      chroma[pc] += magnitude * magnitude;
    }
  }
  final total = chroma.reduce((a, b) => a + b);
  if (total <= 0) return null;
  const major = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88];
  const minor = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17];
  double correlation(List<double> a, List<double> b) {
    final am = a.reduce((x, y) => x + y) / a.length;
    final bm = b.reduce((x, y) => x + y) / b.length;
    var num = 0.0;
    var da = 0.0;
    var db = 0.0;
    for (var i = 0; i < a.length; i++) {
      final x = a[i] - am;
      final y = b[i] - bm;
      num += x * y;
      da += x * x;
      db += y * y;
    }
    return da > 0 && db > 0 ? num / math.sqrt(da * db) : 0;
  }

  var bestTonic = 0;
  var bestMinor = false;
  var bestScore = double.negativeInfinity;
  for (var tonic = 0; tonic < 12; tonic++) {
    for (final isMinor in [false, true]) {
      final profile = isMinor ? minor : major;
      final rotated = List<double>.generate(
        12,
        (pc) => profile[(pc - tonic + 12) % 12],
      );
      final score = correlation(chroma, rotated);
      if (score > bestScore) {
        bestScore = score;
        bestTonic = tonic;
        bestMinor = isMinor;
      }
    }
  }
  return (pitchClass: bestTonic, minor: bestMinor);
}

/// 16 beats of the outgoing track, clamped to a sane overlap length.
int djBlendDurationMs(
  BeatAnalysisResult beat, {
  int beats = 16,
  int minMs = 4000,
  int maxMs = 15000,
}) =>
    (beat.beatPeriodMs * beats).round().clamp(minMs, maxMs);

BeatAnalysisResult? analyzePcm(
  List<double> mono,
  int sampleRate, {
  List<double>? tailMono,
  int? durationMs,
}) {
  final flux = spectralFlux(mono);
  if (flux.length < 32) return null;
  final frameRate = sampleRate / 512.0;
  final tempo = estimateTempo(flux, frameRate);
  if (tempo.confidence <= 0) return null;
  final phase = estimateBeatPhase(flux, frameRate, tempo.bpm);
  final mixOut = tailMono == null || durationMs == null
      ? null
      : energyMixOut(tailMono, sampleRate, durationMs);
  final key = estimateKey(mono, sampleRate);
  return BeatAnalysisResult(
    bpm: tempo.bpm,
    firstBeatOffsetMs: phase,
    confidence: tempo.confidence,
    mixInMs: energyMixIn(mono, sampleRate),
    mixOutMs: mixOut,
    keyPitchClass: key?.pitchClass,
    keyIsMinor: key?.minor,
  );
}

/// Aligns the end of the crossfade with a beat near the outgoing mix-out point
/// (or the track end). Returns the remaining-time threshold (ms) to trigger.
int automixTriggerMs(
  int durationMs,
  int crossfadeMs,
  BeatAnalysisResult beat, {
  int? mixOutMs,
}) {
  if (durationMs <= crossfadeMs) return crossfadeMs;
  final period = beat.beatPeriodMs;
  if (period <= 0) return crossfadeMs;
  final targetEnd = (mixOutMs ?? durationMs).clamp(crossfadeMs, durationMs);
  final beatsBefore = ((targetEnd - beat.firstBeatOffsetMs) / period).floor();
  var alignedEnd = beat.firstBeatOffsetMs + beatsBefore * period;
  if (alignedEnd > durationMs) alignedEnd -= period;
  final start = alignedEnd - crossfadeMs;
  return (durationMs - start).round().clamp(crossfadeMs, durationMs);
}

/// Offset into the incoming track so that one of its beats lands exactly at
/// the end of the crossfade. This is the phase-matching part of Automix.
int beatAlignedStartMs(
  BeatAnalysisResult incoming,
  int crossfadeMs, {
  int maxSkipMs = 30000,
}) {
  final period = incoming.beatPeriodMs;
  if (period <= 0) return 0;
  final mixIn = incoming.mixInMs ?? 0;
  var start = incoming.firstBeatOffsetMs - crossfadeMs;
  if (start < mixIn) {
    final beats = ((mixIn - start) / period).ceil();
    start += beats * period;
  }
  if (start > maxSkipMs) return mixIn;
  return math.max(0, start).round();
}
