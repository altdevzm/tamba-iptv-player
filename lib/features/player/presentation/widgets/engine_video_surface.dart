import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../data/libvlc_bridge.dart';
import '../../data/player_controller.dart';
import '../../domain/playback_enums.dart';

/// Unified video rendering surface that switches cleanly between
/// `media_kit` (`libmpv`) and bundled native `LibVLC` on Android.
class EngineVideoSurface extends ConsumerWidget {
  final BoxFit fit;
  final double? aspectRatio;

  const EngineVideoSurface({
    super.key,
    this.fit = BoxFit.contain,
    this.aspectRatio,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(
      playerControllerProvider.select((s) => s.playbackEngine),
    );
    final controller = ref.read(playerControllerProvider.notifier);

    if (engine == PlaybackEngine.libVlc && LibVlcBridge.isSupported) {
      return const LibVlcVideoSurface();
    }

    return Video(
      controller: controller.videoController,
      fit: fit,
      aspectRatio: aspectRatio,
      controls: NoVideoControls,
    );
  }
}
