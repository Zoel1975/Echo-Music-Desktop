part of 'appearance_cubit.dart';

@immutable
sealed class AppearanceState {
  const AppearanceState();
}

class AppearanceLoaded extends AppearanceState {
  final ThemeMode themeMode;
  final Color? accentColor;
  final bool amoledBlack;
  final bool dynamicColors;
  final String miniPlayerStyle;
  final String playerBackgroundStyle;
  final String lyricsTextPosition;
  final double lyricsTextSize;
  final bool lyricsAutoScroll;
  final bool hidePlayerThumbnail;
  final int defaultTab;
  final bool showLikedPlaylist;
  final bool showDownloadedPlaylist;
  final bool showTopPlaylist;
  final bool showBottomPlaylist;
  final bool showCachedPlaylist;

  const AppearanceLoaded({
    required this.themeMode,
    required this.accentColor,
    required this.amoledBlack,
    required this.dynamicColors,
    this.miniPlayerStyle = 'Glass',
    this.playerBackgroundStyle = 'Gradient',
    this.lyricsTextPosition = 'Center',
    this.lyricsTextSize = 18,
    this.lyricsAutoScroll = true,
    this.hidePlayerThumbnail = false,
    this.defaultTab = 0,
    this.showLikedPlaylist = true,
    this.showDownloadedPlaylist = true,
    this.showTopPlaylist = true,
    this.showBottomPlaylist = false,
    this.showCachedPlaylist = false,
  });
}
