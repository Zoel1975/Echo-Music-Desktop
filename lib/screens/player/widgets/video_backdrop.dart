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
        return IgnorePointer(
          child: Opacity(
            opacity: 0.32,
            child: FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: WinVideoPlayer(controller),
              ),
            ),
          ),
        );
      },
    );
  }
}
