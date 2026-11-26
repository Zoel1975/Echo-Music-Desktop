import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:Echo/services/settings_manager.dart';

part 'appearance_state.dart';

class AppearanceCubit extends Cubit<AppearanceState> {
  final SettingsManager _settings = GetIt.I<SettingsManager>();

  late final VoidCallback _listener;

  AppearanceCubit()
      : super(
          AppearanceLoaded(
            themeMode: GetIt.I<SettingsManager>().themeMode,
            accentColor: GetIt.I<SettingsManager>().accentColor,
            amoledBlack: GetIt.I<SettingsManager>().amoledBlack,
            dynamicColors: GetIt.I<SettingsManager>().dynamicColors,
            miniPlayerStyle: GetIt.I<SettingsManager>().miniPlayerStyle,
            playerBackgroundStyle:
                GetIt.I<SettingsManager>().playerBackgroundStyle,
            lyricsTextPosition: GetIt.I<SettingsManager>().lyricsTextPosition,
            lyricsTextSize: GetIt.I<SettingsManager>().lyricsTextSize,
            lyricsAutoScroll: GetIt.I<SettingsManager>().lyricsAutoScroll,
            hidePlayerThumbnail: GetIt.I<SettingsManager>().hidePlayerThumbnail,
            defaultTab: GetIt.I<SettingsManager>().defaultTab,
            showLikedPlaylist: GetIt.I<SettingsManager>().showLikedPlaylist,
            showDownloadedPlaylist:
                GetIt.I<SettingsManager>().showDownloadedPlaylist,
            showTopPlaylist: GetIt.I<SettingsManager>().showTopPlaylist,
            showBottomPlaylist: GetIt.I<SettingsManager>().showBottomPlaylist,
            showCachedPlaylist: GetIt.I<SettingsManager>().showCachedPlaylist,
          ),
        ) {
    _listener = () {
      if (!isClosed) {
        _emitState();
      }
    };

    _settings.addListener(_listener);
  }

  void _emitState() {
    if (isClosed) return;

    emit(
      AppearanceLoaded(
        themeMode: _settings.themeMode,
        accentColor: _settings.accentColor,
        amoledBlack: _settings.amoledBlack,
        dynamicColors: _settings.dynamicColors,
        miniPlayerStyle: _settings.miniPlayerStyle,
        playerBackgroundStyle: _settings.playerBackgroundStyle,
        lyricsTextPosition: _settings.lyricsTextPosition,
        lyricsTextSize: _settings.lyricsTextSize,
        lyricsAutoScroll: _settings.lyricsAutoScroll,
        hidePlayerThumbnail: _settings.hidePlayerThumbnail,
        defaultTab: _settings.defaultTab,
        showLikedPlaylist: _settings.showLikedPlaylist,
        showDownloadedPlaylist: _settings.showDownloadedPlaylist,
        showTopPlaylist: _settings.showTopPlaylist,
        showBottomPlaylist: _settings.showBottomPlaylist,
        showCachedPlaylist: _settings.showCachedPlaylist,
      ),
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _settings.setThemeMode(mode);
    // listener will emit
  }

  void setAmoledBlack(bool value) {
    _settings.amoledBlack = value;
  }

  void setDynamicColors(bool value) {
    _settings.dynamicColors = value;
  }

  void setMiniPlayerStyle(String v) => _settings.miniPlayerStyle = v;
  void setPlayerBackgroundStyle(String v) => _settings.playerBackgroundStyle = v;
  void setLyricsTextPosition(String v) => _settings.lyricsTextPosition = v;
  void setLyricsTextSize(double v) => _settings.lyricsTextSize = v;
  void setLyricsAutoScroll(bool v) => _settings.lyricsAutoScroll = v;
  void setHidePlayerThumbnail(bool v) => _settings.hidePlayerThumbnail = v;
  void setDefaultTab(int v) => _settings.defaultTab = v;
  void setShowLikedPlaylist(bool v) => _settings.showLikedPlaylist = v;
  void setShowDownloadedPlaylist(bool v) => _settings.showDownloadedPlaylist = v;
  void setShowTopPlaylist(bool v) => _settings.showTopPlaylist = v;
  void setShowBottomPlaylist(bool v) => _settings.showBottomPlaylist = v;
  void setShowCachedPlaylist(bool v) => _settings.showCachedPlaylist = v;

  @override
  Future<void> close() {
    _settings.removeListener(_listener);
    return super.close();
  }
}
