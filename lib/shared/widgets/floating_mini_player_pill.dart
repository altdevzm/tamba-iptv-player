import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../shared/models/media_item.dart';
import '../../core/theme/app_colors.dart';
import '../../features/player/data/player_controller.dart';

class FloatingMiniPlayerPill extends ConsumerWidget {
  const FloatingMiniPlayerPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);

    if (!playerState.isMiniPlayerVisible || playerState.currentItem == null) {
      return const SizedBox.shrink();
    }

    final item = playerState.currentItem!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isLive = item.type == MediaType.live;
    final previewWidth = isMobile ? 112.0 : 188.0;
    final dockHeight = isMobile ? 92.0 : 132.0;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: isMobile ? 74 : 24,
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 860),
          width: double.infinity,
          height: dockHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppColors.primaryGlow.withValues(alpha: 0.15),
                blurRadius: 25,
                spreadRadius: -2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.playerPillBackground,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.playerPillBorder,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // The active video surface makes this a true mini-player,
                    // rather than a poster-led audio control strip.
                    GestureDetector(
                      onTap: controller.openFullscreen,
                      child: SizedBox(
                        width: previewWidth,
                        height: double.infinity,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ColoredBox(
                                color: const Color(0xFF08080A),
                                child: Video(
                                  controller: controller.videoController,
                                  controls: NoVideoControls,
                                ),
                              ),
                              Positioned(
                                left: 6,
                                bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.72),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    isLive ? 'LIVE' : 'NOW PLAYING',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(width: isMobile ? 9 : 14),

                    Expanded(
                      child: GestureDetector(
                        onTap: controller.openFullscreen,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: isMobile ? 12 : 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.subtitle ??
                                  (isLive ? 'Live channel' : 'Video'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: isMobile ? 10 : 11,
                              ),
                            ),
                            if (!isLive && playerState.duration > Duration.zero)
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 2,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 5,
                                      ),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                        overlayRadius: 10,
                                      ),
                                    ),
                                    child: Slider(
                                      min: 0,
                                      max: playerState.duration.inMilliseconds
                                          .toDouble(),
                                      value: playerState.position.inMilliseconds
                                          .clamp(
                                            0,
                                            playerState.duration.inMilliseconds,
                                          )
                                          .toDouble(),
                                      onChanged: (value) => controller.seek(
                                        Duration(milliseconds: value.round()),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),
                    if (!isMobile)
                      IconButton(
                        tooltip:
                            isLive ? 'Previous channel' : 'Back 10 seconds',
                        icon: Icon(
                          isLive
                              ? Icons.skip_previous_rounded
                              : Icons.replay_10_rounded,
                        ),
                        color: Colors.white70,
                        onPressed: isLive
                            ? controller.playPreviousChannel
                            : () => controller.seek(
                                  playerState.position -
                                      const Duration(seconds: 10),
                                ),
                      ),
                    IconButton.filled(
                      tooltip: playerState.isPlaying ? 'Pause' : 'Play',
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        fixedSize: Size.square(isMobile ? 38 : 42),
                      ),
                      onPressed: controller.togglePlayPause,
                      icon: Icon(
                        playerState.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 23,
                      ),
                    ),
                    if (!isMobile)
                      IconButton(
                        tooltip: isLive ? 'Next channel' : 'Forward 10 seconds',
                        icon: Icon(
                          isLive
                              ? Icons.skip_next_rounded
                              : Icons.forward_10_rounded,
                        ),
                        color: Colors.white70,
                        onPressed: isLive
                            ? controller.playNextChannel
                            : () => controller.seek(
                                  playerState.position +
                                      const Duration(seconds: 10),
                                ),
                      ),
                    IconButton(
                      tooltip: 'Full screen',
                      icon: const Icon(Icons.fullscreen_rounded),
                      color: Colors.white70,
                      onPressed: controller.openFullscreen,
                    ),
                    IconButton(
                      tooltip: 'Close player',
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.white54,
                      onPressed: controller.closeMiniPlayer,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
