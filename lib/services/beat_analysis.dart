import 'dart:math' as math;

/// Beat-grid analysis ported from Echo Android's `BeatAnalyzer` (classical DSP:
/// STFT -> spectral flux -> autocorrelation tempo -> comb-filter phase).
/// Kept pure so it can be unit-tested with synthetic PCM.
class BeatAnalysisResult {
  const BeatAnalysisResult({
    required this.bpm,
    required this.firstBeatOffsetMs,
    required this.confidence,
  });

  final double bpm;
  final double firstBeatOffsetMs;
  final double confidence;

  double get beatPeriodMs => 60000.0 / bpm;

  Map<String, dynamic> toJson() => {
        'bpm': bpm,
        'firstBeatOffsetMs': firstBeatOffsetMs,
        'confidence': confidence,
      };

  factory BeatAnalysisResult.fromJson(Map<String, dynamic> json) =>
      BeatAnalysisResult(
        bpm: (json['bpm'] as num?)?.toDouble() ?? 120,
        firstBeatOffsetMs:
            (json['firstBeatOffsetMs'] as num?)?.toDouble() ?? 0,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
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

BeatAnalysisResult? analyzePcm(List<double> mono, int sampleRate) {
  final flux = spectralFlux(mono);
  if (flux.length < 32) return null;
  final frameRate = sampleRate / 512.0;
  final tempo = estimateTempo(flux, frameRate);
  if (tempo.confidence <= 0) return null;
  final phase = estimateBeatPhase(flux, frameRate, tempo.bpm);
  return BeatAnalysisResult(
    bpm: tempo.bpm,
    firstBeatOffsetMs: phase,
    confidence: tempo.confidence,
  );
}

/// Aligns the end of the crossfade with a beat close to the track end.
/// Returns the remaining-time threshold (ms) at which the fade should start.
int automixTriggerMs(
  int durationMs,
  int crossfadeMs,
  BeatAnalysisResult beat,
) {
  if (durationMs <= crossfadeMs) return crossfadeMs;
  final period = beat.beatPeriodMs;
  if (period <= 0) return crossfadeMs;
  final rawEnd = durationMs - crossfadeMs / 2;
  final beatsBefore = ((rawEnd - beat.firstBeatOffsetMs) / period).floor();
  var targetEnd = beat.firstBeatOffsetMs + beatsBefore * period;
  if (targetEnd > durationMs) targetEnd -= period;
  final start = targetEnd - crossfadeMs;
  return (durationMs - start).round().clamp(crossfadeMs, durationMs);
}
