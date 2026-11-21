import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../features/player/data/player_controller.dart';
import '../../features/player/presentation/widgets/engine_video_surface.dart';
import '../../shared/models/media_item.dart';

/// Draggable floating 16:9 Picture-in-Picture video window for mobile and desktop.
class FloatingMiniPlayerPill extends ConsumerStatefulWidget {
  const FloatingMiniPlayerPill({super.key});

  @override
  ConsumerState<FloatingMiniPlayerPill> createState() =>
      _FloatingMiniPlayerPillState();
}

class _FloatingMiniPlayerPillState
    extends ConsumerState<FloatingMiniPlayerPill> {
  Offset? _position;
  bool _showControls = true;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    _hideTimer?.cancel();
    if (_showControls) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isVisible = ref.watch(
      playerControllerProvider.select((s) => s.isMiniPlayerVisible),
    );
    final item = ref.watch(
      playerControllerProvider.select((s) => s.currentItem),
    );
    final isPlaying = ref.watch(
      playerControllerProvider.select((s) => s.isPlaying),
    );
    final isBuffering = ref.watch(
      playerControllerProvider.select((s) => s.isBuffering),
    );
    final controller = ref.read(playerControllerProvider.notifier);

    if (!isVisible || item == null) {
      return const SizedBox.shrink();
    }

    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final padding = mediaQuery.padding;
    final isMobile = screenSize.width < 768;
    final isLive = item.type == MediaType.live;

    final double pipWidth = isMobile
        ? (screenSize.width * 0.56).clamp(185.0, 240.0)
        : 320.0;
    final double pipHeight = pipWidth * 9 / 16;

    const double margin = 12.0;
    const double minX = margin;
    final double maxX = (screenSize.width - pipWidth - margin).clamp(minX, double.infinity);
    final double minY = padding.top + (isMobile ? 56.0 : 16.0);
    final double maxY = (screenSize.height -
            pipHeight -
            padding.bottom -
            (isMobile ? 74.0 : 20.0))
        .clamp(minY, double.infinity);

    // Default to bottom-right corner on first show
    final currentOffset = _position ?? Offset(maxX, maxY);
    final clampedX = currentOffset.dx.clamp(minX, maxX);
    final clampedY = currentOffset.dy.clamp(minY, maxY);

    return Positioned(
      left: clampedX,
      top: clampedY,
      width: pipWidth,
      height: pipHeight,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              (clampedX + details.delta.dx).clamp(minX, maxX),
              (clampedY + details.delta.dy).clamp(minY, maxY),
            );
          });
        },
        onTap: _toggleControls,
        onDoubleTap: controller.openFullscreen,
        child: Material(
          color: Colors.black,
          elevation: 14,
          shadowColor: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Pure 16:9 Live/VOD Video Surface
                const EngineVideoSurface(fit: BoxFit.cover),

                // Buffering spinner
                if (isBuffering)
                  const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),

                // Subtle LIVE badge in top-left
                if (isLive)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),

                // Minimal tap-to-toggle overlay controls
                IgnorePointer(
                  ignoring: !_showControls,
                  child: AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.42),
                      child: Stack(
                        children: [
                          // Top-right expand & close buttons
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _MiniOverlayIcon(
                                  icon: Icons.open_in_full_rounded,
                                  tooltip: 'Full screen',
                                  onTap: controller.openFullscreen,
                                ),
                                _MiniOverlayIcon(
                                  icon: Icons.close_rounded,
                                  tooltip: 'Close player',
                                  onTap: controller.closeMiniPlayer,
                                ),
                              ],
                            ),
                          ),

                          // Center Play / Pause button
                          Center(
                            child: InkWell(
                              onTap: controller.togglePlayPause,
                              borderRadius: BorderRadius.circular(24),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white54,
                                    width: 1.2,
                                  ),
                                ),
                                child: Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),

                          // Compact title at bottom
                          Positioned(
                            left: 8,
                            right: 8,
                            bottom: 5,
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(color: Colors.black, blurRadius: 4),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniOverlayIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MiniOverlayIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 15),
        ),
      ),
    );
  }
}
