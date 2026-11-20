import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

import '../../services/media_player.dart';
import '../../services/settings_manager.dart';
import '../../themes/dark.dart';
import '../../utils/song_thumbnail.dart';
import 'widgets/animated_gradient_bg.dart';
import 'widgets/lyrics_box.dart';

/// Real desktop port of Android `AmbientModeScreen` / `CanvasAlbum`: a
/// full-screen immersive player with an animated palette background, album art
/// and synced lyrics. Uses the same palette already extracted for the player.
class AmbientPage extends StatelessWidget {
  const AmbientPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: darkTheme(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFED5564),
          brightness: Brightness.dark,
        ),
      ),
      child: Consumer<MediaPlayer>(
        builder: (context, mp, _) {
          final song = mp.currentSongNotifier.value;
          final extras = song?.extras;
          final showArt = GetIt.I<SettingsManager>().extra<bool>('ambientArt', true);
          final showLyrics =
              GetIt.I<SettingsManager>().extra<bool>('ambientLyrics', true);
          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                const Positioned.fill(
                  child: AnimatedGradientBackground(
                    colors: [
                      Color(0xFF2A1B3D),
                      Color(0xFF1B2A3D),
                      Color(0xFF3D1B2A),
                    ],
                  ),
                ),
                if (song == null)
                  const Center(
                    child: Text('Nothing playing',
                        style: TextStyle(color: Colors.white70)),
                  )
                else
                  SafeArea(
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.topLeft,
                          child: IconButton(
                            icon:
                                const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const Spacer(),
                        if (showArt)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: SongThumbnail(
                              song: Map<String, dynamic>.from(extras ?? const {}),
                              width: 220,
                              height: 220,
                            ),
                          ),
                        const SizedBox(height: 20),
                        Text(
                          song.title ?? 'Unknown',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          song.artist ?? '',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 16),
                        ),
                        if (showLyrics)
                          Expanded(
                            child: LyricsBox(
                              currentSong: song,
                              size: MediaQuery.of(context).size,
                            ),
                          ),
                        const Spacer(),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
