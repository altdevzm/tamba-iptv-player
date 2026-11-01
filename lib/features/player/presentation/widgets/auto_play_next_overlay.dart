import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/media_item.dart';
import '../../data/player_controller.dart';

/// Overlay displayed when an episode is near completion with a countdown
/// to the next episode.
class AutoPlayNextOverlay extends ConsumerStatefulWidget {
  final MediaItem nextEpisode;

  const AutoPlayNextOverlay({super.key, required this.nextEpisode});

  @override
  ConsumerState<AutoPlayNextOverlay> createState() =>
      _AutoPlayNextOverlayState();
}

class _AutoPlayNextOverlayState extends ConsumerState<AutoPlayNextOverlay>
    with SingleTickerProviderStateMixin {
  static const _countdownSeconds = 10;
  int _remaining = _countdownSeconds;
  Timer? _timer;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _countdownSeconds),
    )..forward();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        _playNext();
      }
    });
  }

  void _playNext() {
    _timer?.cancel();
    final controller = ref.read(playerControllerProvider.notifier);
    controller.playItem(widget.nextEpisode, startFullscreen: true);
  }

  void _cancel() {
    _timer?.cancel();
    ref.read(playerControllerProvider.notifier).clearNextEpisode();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 24,
      bottom: 100,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A22).withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _animController,
                        builder: (_, __) => CircularProgressIndicator(
                          value: 1.0 - _animController.value,
                          strokeWidth: 3,
                          color: AppColors.primary,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                      Text(
                        '$_remaining',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Up Next',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _cancel,
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white54,
                    size: 18,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (widget.nextEpisode.posterUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  widget.nextEpisode.posterUrl!,
                  height: 90,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              widget.nextEpisode.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (widget.nextEpisode.subtitle != null)
              Text(
                widget.nextEpisode.subtitle!,
                style:
                    const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _playNext,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Play Now',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _cancel,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white54,
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
