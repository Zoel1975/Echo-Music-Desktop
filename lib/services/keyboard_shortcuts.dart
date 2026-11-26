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
/// Space: play/pause, arrows: previous/next, S: toggle stems, 1-4: toggle a
/// stem, V: tap toggles vocals, hold mutes vocals until the key is released.
Timer? _vHoldTimer;
bool _vHeld = false;
bool _vTemporaryMute = false;
List<bool>? _vSavedPattern;

KeyEventResult handleGlobalKey(FocusNode node, KeyEvent event) {
  // Never swallow keys typed into search boxes or settings fields.
  final focusWidget = FocusManager.instance.primaryFocus?.context?.widget;
  if (focusWidget is EditableText) return KeyEventResult.ignored;
  if (event is KeyRepeatEvent) return KeyEventResult.handled;

  if (!GetIt.I.isRegistered<MediaPlayer>()) return KeyEventResult.ignored;
  final player = GetIt.I<MediaPlayer>();
  final key = event.logicalKey;

  if (key == LogicalKeyboardKey.space) {
    final p = player.player;
    if (p.playing) {
      unawaited(p.pause());
    } else {
      unawaited(p.play());
    }
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.arrowRight) {
    unawaited(player.player.seekToNext());
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.arrowLeft) {
    unawaited(player.player.seekToPrevious());
    return KeyEventResult.handled;
  }
  if (key == LogicalKeyboardKey.keyS) {
    unawaited(_toggleStems());
    return KeyEventResult.handled;
  }
  final digits = [
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
  if (key == LogicalKeyboardKey.keyV) {
    _handleVocalKey(event);
    return KeyEventResult.handled;
  }
  return KeyEventResult.ignored;
}

Future<void> _ensureStems() async {
  if (!GetIt.I.isRegistered<StemMixerService>()) return;
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
  final mixer = GetIt.I<StemMixerService>();
  await _ensureStems();
  if (!mixer.state.stemsLoaded) return;
  mixer.setStemEnabled(index, !mixer.state.enabled[index]);
}

void _handleVocalKey(KeyEvent event) {
  if (!GetIt.I.isRegistered<StemMixerService>()) return;
  final mixer = GetIt.I<StemMixerService>();
  if (event is KeyDownEvent) {
    if (_vHeld) return; // key repeat guard
    _vHeld = true;
    _vTemporaryMute = false;
    _vSavedPattern = null;
    _vHoldTimer?.cancel();
    _vHoldTimer = Timer(const Duration(milliseconds: 250), () {
      if (!_vHeld) return;
      unawaited(_ensureStems());
      if (!mixer.state.stemsLoaded) return;
      _vSavedPattern = List<bool>.from(mixer.state.enabled);
      mixer.setStemEnabled(3, false);
      _vTemporaryMute = true;
    });
    return;
  }
  if (event is KeyUpEvent && _vHeld) {
    _vHeld = false;
    _vHoldTimer?.cancel();
    _vHoldTimer = null;
    if (_vTemporaryMute) {
      final saved = _vSavedPattern;
      if (saved != null) mixer.applyPattern(saved);
      _vTemporaryMute = false;
      _vSavedPattern = null;
    } else {
      unawaited(_toggleStem(3));
    }
  }
}
