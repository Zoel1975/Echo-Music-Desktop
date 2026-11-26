/// Port of Android `musicflow/MusicFlowCoordinator.kt` over `MediaPlayer`
/// (Android: `PlayerConnectionMusicFlowPlayer`). Desktop has no
/// casting/Listen Together takeover signals yet, so `takeoverBlock()`
/// always returns null.
import 'package:get_it/get_it.dart';
import 'package:Echo/services/media_player.dart';

sealed class MusicFlowPlaybackStatus {
  const MusicFlowPlaybackStatus();

  static const idle = _Idle();
  static const switching = _Switching();
  static const synced = _Synced();

  static MusicFlowPlaybackStatus blocked(TakeoverBlock reason) =>
      _Blocked(reason);
}

class _Idle extends MusicFlowPlaybackStatus {
  const _Idle() : super();
}

class _Switching extends MusicFlowPlaybackStatus {
  const _Switching() : super();
}

class _Synced extends MusicFlowPlaybackStatus {
  const _Synced() : super();
}

class _Blocked extends MusicFlowPlaybackStatus {
  const _Blocked(this.reason);
  final TakeoverBlock reason;
}

enum TakeoverBlock { casting, listenTogetherGuest }

class DesktopMusicFlowPlayer {
  final MediaPlayer _player = GetIt.I<MediaPlayer>();
  bool _flowActive = false;

  String? currentMediaId() => _player.currentSongNotifier.value?.id;

  List<String> queueMediaIds() => List<String>.of(
        _player.songList.map((s) => s.tag?.id ?? ''),
      );

  bool ownsPlayback() => _flowActive;
  bool isAnyFlowQueueActive() => _flowActive;
  TakeoverBlock? takeoverBlock() => null;

  int indexOf(String songId) =>
      _player.songList.indexWhere((s) => s.tag?.id == songId);

  List<Map<String, dynamic>> get items => _player.songList
      .map((s) => Map<String, dynamic>.from(s.tag?.extras ?? const {})
        ..putIfAbsent('videoId', () => s.tag?.id ?? ''))
      .toList();

  Future<void> seekTo(int queueIndex, bool playWhenReady) async {
    final item = items[queueIndex];
    await _player.playSong(Map<String, dynamic>.from(item));
  }

  Future<void> startQueue(List<Map<String, dynamic>> items, int startIndex,
      bool playWhenReady, bool autoNext) async {
    _flowActive = true;
    await _player.playAll(items.sublist(startIndex));
  }

  Future<void> append(List<dynamic> items) async {
    for (final item in items) {
      await _player.playNext(Map<String, dynamic>.from(item));
    }
  }

  void setPauseAtEnd(bool pause) {}
  bool canRestorePreviousQueue() => false;
  Future<bool> restorePreviousQueue() async => false;
  void invalidateIfSuperseded() => _flowActive = false;
}

/// Port of Android `MusicFlowCoordinator`: settle-page selections turn into
/// player commands; stale requests are dropped (`Switching`).
class MusicFlowCoordinator {
  MusicFlowCoordinator({required this.session, required this.player});

  final dynamic session;
  final DesktopMusicFlowPlayer player;

  int _latestRequestId = 0;

  int nextRequestId() => ++_latestRequestId;

  bool ownsPlayback() => player.ownsPlayback();

  Future<MusicFlowPlaybackStatus> select({
    required int requestId,
    required String songId,
    required bool playWhenReady,
    required bool autoNext,
  }) async {
    if (requestId < _latestRequestId) {
      return MusicFlowPlaybackStatus.switching;
    }
    if (player.currentMediaId() == songId) {
      return MusicFlowPlaybackStatus.synced;
    }
    if (player.isAnyFlowQueueActive()) {
      final queueIndex = player.queueMediaIds().indexOf(songId);
      if (queueIndex >= 0) {
        await player.seekTo(queueIndex, playWhenReady);
        return MusicFlowPlaybackStatus.switching;
      }
    }
    final takeover = player.takeoverBlock();
    if (takeover != null) {
      return MusicFlowPlaybackStatus.blocked(takeover);
    }
    final index = player.indexOf(songId);
    if (index < 0) return MusicFlowPlaybackStatus.idle;
    final items = player.items;
    await player.startQueue(items, index, playWhenReady, autoNext);
    return MusicFlowPlaybackStatus.switching;
  }

  void applyAutoNext(bool autoNext) => player.setPauseAtEnd(!autoNext);
  void appendIfOwned(List<dynamic> items) => player.append(items);
  bool canRestorePreviousQueue() => player.canRestorePreviousQueue();
  Future<bool> restorePreviousQueue() => player.restorePreviousQueue();
  void invalidateIfSuperseded() => player.invalidateIfSuperseded();
}
