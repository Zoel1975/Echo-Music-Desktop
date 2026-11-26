import 'package:Echo/ytmusic/client.dart';

/// Port of Android's `InnerTube.addToPlaylist` / `removeFromPlaylist` /
/// `createPlaylist`. All calls need the signed-in context (Cookie +
/// SAPISIDHASH + visitorData + onBehalfOfUser), which [YTClient.sendRequest]
/// refreshes on every request.
mixin PlaylistEditMixin on YTClient {
  static String id(String playlistId) {
    final value = playlistId.trim();
    return value.startsWith('VL') ? value.substring(2) : value;
  }

  /// Exact `EditPlaylistBody` from Android's InnerTube.kt.
  static Map<String, dynamic> editBody(
    String playlistId,
    Map<String, dynamic> action,
    Map<String, dynamic> context,
  ) =>
      {
        'context': context,
        'playlistId': id(playlistId),
        'actions': [action],
      };

  Future<Map> _edit(String playlistId, Map<String, dynamic> action) =>
      sendRequest('browse/edit_playlist', editBody(playlistId, action, context));

  /// Add a video to an online YouTube Music playlist.
  Future<Map> addToPlaylist(String playlistId, String videoId) =>
      _edit(playlistId, {
        'action': 'ACTION_ADD_VIDEO',
        'addedVideoId': videoId,
      });

  /// Remove a video. `setVideoId` is the per-playlist entry id returned by
  /// `getPlaylistSongs` (Android stores it in `SetVideoIdEntity`).
  Future<Map> removeFromPlaylist(
    String playlistId,
    String videoId,
    String setVideoId,
  ) =>
      _edit(playlistId, {
        'action': 'ACTION_REMOVE_VIDEO',
        'setVideoId': setVideoId,
        'removedVideoId': videoId,
      });

  Future<Map> renamePlaylist(String playlistId, String name) =>
      _edit(playlistId, {
        'action': 'ACTION_SET_PLAYLIST_NAME',
        'playlistName': name,
      });

  Future<Map> createPlaylist(String title) =>
      sendRequest('playlist/create', {
        'context': context,
        'title': title,
      });
}
