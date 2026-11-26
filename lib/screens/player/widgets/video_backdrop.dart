import 'package:flutter/material.dart';
import 'package:video_player_win/video_player_win.dart';

import 'package:Echo/services/video_backdrop_service.dart';

/// Muted video layer behind the full-screen player canvas. It is completely
/// inert unless the beta setting is on and the video controller initialized.
class VideoBackdrop extends StatelessWidget {
  const VideoBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: VideoBackdropService.instance,
      builder: (context, _) {
        final controller = VideoBackdropService.instance.controller;
        if (controller == null || !controller.value.isInitialized) {
          return const SizedBox.shrink();
        }
        final size = controller.value.size;
        if (size.width <= 0 || size.height <= 0) {
          return const SizedBox.shrink();
        }
        // Full-window layer: it is placed behind every player widget, not
        // just behind the round artwork.
        return IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: WinVideoPlayer(controller),
                ),
              ),
              // Keep titles and controls readable over the video.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0x99000000),
                      Color(0x66000000),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
