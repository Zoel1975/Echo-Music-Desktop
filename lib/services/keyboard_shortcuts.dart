import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';

import 'media_player.dart';
import 'stem_mixer_service.dart';
import 'stem_separation_queue.dart';

/// Global keyboard shortcuts for playback and the stem mixer.
///
/// Space: play/pause (controls the stems while they are active)
/// ← / →: previous/next track, S: toggle stems, 1-4: toggle a stem
/// D / B / I / V: tap toggles Drums / Bass / Other / Vocals, hold mutes that
/// stem only while the key is down and restores its previous state on release.
final Map<LogicalKeyboardKey, int> stemHoldKeys = {
  LogicalKeyboardKey.keyD: 0,
  LogicalKeyboardKey.keyB: 1,
  LogicalKeyboardKey.keyI: 2,
  LogicalKeyboardKey.keyV: 3,
};

final List<bool> _stemHeld = List<bool>.filled(4, false);
final List<Timer?> _stemHoldTimers = List<Timer?>.filled(4, null);
final List<bool?> _stemSavedEnabled = List<bool?>.filled(4, null);

bool get _anyStemHeld => _stemHeld.any((held) => held);

/// Player calls are fire-and-forget from the UI; contain failures so a key
/// press can never produce an uncaught async exception.
void _safe(Future<void> Function() action) {
  unawaited(action().catchError((Object e, StackTrace st) {
    debugPrint('shortcut failed: $e');
  }));
}

KeyEventResult handleGlobalKey(FocusNode node, KeyEvent event) {
  // Never swallow keys typed into search boxes or settings fields. A held
  // stem key still receives its release so it can restore the mix.
  final focusWidget = FocusManager.instance.primaryFocus?.context?.widget;
  if (focusWidget is EditableText && !_anyStemHeld) {
    return KeyEventResult.ignored;
  }
  if (event is KeyRepeatEvent) return KeyEventResult.handled;

  if (!GetIt.I.isRegistered<MediaPlayer>()) return KeyEventResult.ignored;
  final player = GetIt.I<MediaPlayer>();
  final key = event.logicalKey;

  if (key == LogicalKeyboardKey.space) {
    if (GetIt.I.isRegistered<StemMixerService>() &&
        GetIt.I<StemMixerService>().state.stemsLoaded) {
      final mixer = GetIt.I<StemMixerService>();
      unawaited(mixer.setPlaying(!mixer.isPlaying));
    } else {
      final p = player.player;
      _safe(() => p.playing ? p.pause() : p.play());
    }
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.arrowRight) {
    _safe(() => player.player.seekToNext());
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.arrowLeft) {
    _safe(() => player.player.seekToPrevious());
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.keyS) {
    unawaited(_toggleStems());
    return KeyEventResult.handled;
  }
  const digits = [
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
  ];
  final digitIndex = digits.indexOf(key);
  if (digitIndex >= 0) {
    unawaited(_toggleStem(digitIndex));
    return KeyEventResult.handled;
  }
  final stemIndex = stemHoldKeys[key];
  if (stemIndex != null) {
    _handleStemKey(event, stemIndex);
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

Future<void> _ensureStems() async {
  if (!GetIt.I.isRegistered<StemMixerService>() ||
      !GetIt.I.isRegistered<MediaPlayer>()) {
    return;
  }
  final mixer = GetIt.I<StemMixerService>();
  if (mixer.state.stemsLoaded) return;
  final id = GetIt.I<MediaPlayer>().currentSongNotifier.value?.id;
  if (id == null || id.isEmpty) return;
  final paths = StemSeparationQueue.instance.stemPaths(id);
  if (paths.every((p) => File(p).existsSync())) {
    await mixer.setStemFiles(id, paths);
  }
}

Future<void> _toggleStems() async {
  if (!GetIt.I.isRegistered<StemMixerService>()) return;
  final mixer = GetIt.I<StemMixerService>();
  if (mixer.state.stemsLoaded) {
    await mixer.disableStems();
  } else {
    await _ensureStems();
  }
}

Future<void> _toggleStem(int index) async {
  if (!GetIt.I.isRegistered<StemMixerService>()) return;
  final mixer = GetIt.I<StemMixerService>();
  await _ensureStems();
  if (!mixer.state.stemsLoaded) return;
  mixer.setStemEnabled(index, !mixer.state.enabled[index]);
}

void _handleStemKey(KeyEvent event, int index) {
  if (!GetIt.I.isRegistered<StemMixerService>()) return;
  final mixer = GetIt.I<StemMixerService>();
  if (event is KeyDownEvent) {
    if (_stemHeld[index]) return; // key repeat guard
    _stemHeld[index] = true;
    _stemSavedEnabled[index] = null;
    _stemHoldTimers[index]?.cancel();
    _stemHoldTimers[index] = Timer(const Duration(milliseconds: 250), () async {
      if (!_stemHeld[index]) return;
      await _ensureStems();
      if (!_stemHeld[index] || !mixer.state.stemsLoaded) return;
      _stemSavedEnabled[index] = mixer.state.enabled[index];
      mixer.setStemEnabled(index, false);
    });
    return;
  }
  if (event is KeyUpEvent && _stemHeld[index]) {
    _stemHeld[index] = false;
    _stemHoldTimers[index]?.cancel();
    _stemHoldTimers[index] = null;
    final saved = _stemSavedEnabled[index];
    if (saved != null) {
      // Restore only this stem so multiple held keys compose correctly.
      mixer.setStemEnabled(index, saved);
      _stemSavedEnabled[index] = null;
    } else {
      unawaited(_toggleStem(index));
    }
  }
}
