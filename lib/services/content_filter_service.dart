import 'package:hive_flutter/hive_flutter.dart';

/// Real port of Android `BlockedArtistsScreen.kt` + `DislikedSongsScreen.kt`:
/// stores hidden artists and disliked song ids, and exposes query helpers so
/// the library/search can filter them out.
class ContentFilterService {
  ContentFilterService()
      : _artists = Hive.box('BLOCKED_ARTISTS'),
        _songs = Hive.box('DISLIKED_SONGS');

  final Box _artists;
  final Box _songs;

  Box get artistsBox => _artists;
  Box get songsBox => _songs;

  List<String> get blockedArtists =>
      _artists.keys.map((e) => e.toString()).toList();
  List<String> get dislikedSongs =>
      _songs.keys.map((e) => e.toString()).toList();

  bool isArtistBlocked(String artist) =>
      _artists.containsKey(artist.toLowerCase());
  bool isSongDisliked(String videoId) => _songs.containsKey(videoId);

  Future<void> blockArtist(String artist) =>
      _artists.put(artist.toLowerCase(), artist);
  Future<void> unblockArtist(String artist) =>
      _artists.delete(artist.toLowerCase());
  Future<void> dislikeSong(String videoId, [String? title]) =>
      _songs.put(videoId, title ?? videoId);
  Future<void> likeSong(String videoId) => _songs.delete(videoId);

  Future<void> clearBlockedArtists() => _artists.clear();
  Future<void> clearDislikedSongs() => _songs.clear();
}
