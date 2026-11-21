import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../media_player.dart';
import '../yt_audio_stream.dart';
import 'cast_client.dart';
import 'cast_device.dart';
import 'cast_discovery.dart';

/// Desktop counterpart of Android's Cast flow: discovers receivers, connects,
/// and mirrors the current queue item to the selected device.
///
/// The Cast device fetches the audio from Echo's own local relay, so signed-in
/// YouTube Music cookies never leave the desktop - exactly like Android's
/// `CastConnectionHandler`, which hands the device a playable URL.
class CastService {
  CastService({CastDiscovery? discovery, CastClient? castClient})
      : _discovery = discovery ?? const CastDiscovery(),
        client = castClient ?? CastClient();

  final CastDiscovery _discovery;
  final CastClient client;

  final ValueNotifier<List<CastDevice>> devices =
      ValueNotifier<List<CastDevice>>(<CastDevice>[]);
  final ValueNotifier<CastDevice?> connected = ValueNotifier<CastDevice?>(null);
  final ValueNotifier<String> status = ValueNotifier<String>('');
  final ValueNotifier<bool> scanning = ValueNotifier<bool>(false);

  StreamSubscription<bool>? _playingSub;
  MediaItem? _lastSong;
  void Function()? _songListener;
  bool _suppressSync = false;

  bool get isCasting => connected.value != null && client.isConnected;

  Future<void> scan() async {
    if (scanning.value) return;
    scanning.value = true;
    status.value = 'Ricerca dispositivi sulla rete…';
    try {
      final found = await _discovery.discover();
      devices.value = found;
      status.value = found.isEmpty
          ? 'Nessun dispositivo Cast trovato. Controlla che sia sulla stessa Wi-Fi.'
          : '${found.length} dispositivi trovati.';
    } catch (e) {
      status.value = 'Ricerca non riuscita: $e';
    } finally {
      scanning.value = false;
    }
  }

  Future<void> connect(CastDevice device) async {
    status.value = 'Connessione a ${device.name}…';
    try {
      await client.connect(device);
      connected.value = device;
      status.value = 'Connesso a ${device.name}.';
      await _listenToPlayer();
      await castCurrentSong();
    } catch (e) {
      status.value = 'Connessione non riuscita: $e';
      connected.value = null;
    }
  }

  Future<void> disconnect() async {
    if (_songListener != null) {
      GetIt.I<MediaPlayer>().currentSongNotifier.removeListener(_songListener!);
      _songListener = null;
    }
    await _playingSub?.cancel();
    _playingSub = null;
    await client.disconnect();
    connected.value = null;
    status.value = 'Disconnesso.';
  }

  Future<void> _listenToPlayer() async {
    if (_songListener != null) {
      GetIt.I<MediaPlayer>().currentSongNotifier.removeListener(_songListener!);
    }
    await _playingSub?.cancel();
    if (!GetIt.I.isRegistered<MediaPlayer>()) return;
    final mp = GetIt.I<MediaPlayer>();
    _lastSong = mp.currentSongNotifier.value;
    _songListener = () {
      final song = mp.currentSongNotifier.value;
      if (song == _lastSong) return;
      _lastSong = song;
      if (!isCasting) return;
      unawaited(castCurrentSong());
    };
    mp.currentSongNotifier.addListener(_songListener!);
    _playingSub = mp.player.playingStream.listen((playing) {
      if (!isCasting || _suppressSync || playing == client.playing.value) return;
      unawaited(playing ? client.play() : client.pause());
    });
  }

  /// Load the current song on the receiver using the local LAN relay URL.
  Future<void> castCurrentSong() async {
    if (!isCasting || !GetIt.I.isRegistered<MediaPlayer>()) return;
    final song = GetIt.I<MediaPlayer>().currentSongNotifier.value;
    if (song == null || song.id.isEmpty || song.id.startsWith('local://')) {
      status.value = 'Connesso, ma nessun brano riproducibile in coda.';
      return;
    }
    try {
      final url = await lanAudioUrl(song.id, peerHost: connected.value?.host);
      final duration = song.extras?['duration'];
      _suppressSync = true;
      // Avoid hearing the same track twice: the TV/speaker is the output now.
      GetIt.I<MediaPlayer>().player.pause();
      await client.load(
        contentId: url,
        title: song.title,
        artist: song.artist,
        imageUrl: song.artUri?.toString(),
        durationMs: duration is num ? duration.toInt() : null,
      );
      status.value = 'In riproduzione su ${connected.value?.name}: ${song.title}';
    } catch (e) {
      status.value = 'Caricamento non riuscito: $e';
    } finally {
      _suppressSync = false;
    }
  }

  Future<void> togglePlayback() async {
    if (!isCasting) return;
    if (client.playing.value) {
      await client.pause();
    } else {
      await client.play();
    }
  }

  Future<void> stop() => client.stop();
  Future<void> seek(Duration position) => client.seek(position);
  Future<void> setVolume(double level) => client.setVolume(level);
}
