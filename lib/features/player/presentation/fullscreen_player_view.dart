import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart' show SubtitleTrack;
import '../../../core/persistence/app_database.dart';
import '../../../core/persistence/database_provider.dart';
import '../../../shared/models/media_item.dart';
import '../../../core/theme/app_colors.dart';
import '../data/libvlc_bridge.dart';
import '../data/player_controller.dart';
import '../data/stream_recording_service.dart';
import '../data/external_player_service.dart';
import '../domain/playback_enums.dart';
import '../tiss/tiss_models.dart';
import 'widgets/diagnostics_panel.dart';
import 'widgets/engine_video_surface.dart';
import 'widgets/playback_speed_sheet.dart';
import 'widgets/auto_play_next_overlay.dart';

enum _VideoAspectPreset {
  original,
  widescreen,
  classic,
  cinema,
  fillScreen,
}

extension on _VideoAspectPreset {
  String get label => switch (this) {
        _VideoAspectPreset.original => 'Original',
        _VideoAspectPreset.widescreen => '16:9',
        _VideoAspectPreset.classic => '4:3',
        _VideoAspectPreset.cinema => '21:9',
        _VideoAspectPreset.fillScreen => 'Fill screen',
      };

  double? get aspectRatio => switch (this) {
        _VideoAspectPreset.original || _VideoAspectPreset.fillScreen => null,
        _VideoAspectPreset.widescreen => 16 / 9,
        _VideoAspectPreset.classic => 4 / 3,
        _VideoAspectPreset.cinema => 21 / 9,
      };

  BoxFit get fit =>
      this == _VideoAspectPreset.fillScreen ? BoxFit.cover : BoxFit.contain;
}

class FullscreenPlayerView extends ConsumerStatefulWidget {
  const FullscreenPlayerView({super.key});

  @override
  ConsumerState<FullscreenPlayerView> createState() =>
      _FullscreenPlayerViewState();
}

class _FullscreenPlayerViewState extends ConsumerState<FullscreenPlayerView> {
  bool _showControls = true;
  bool _showDiagnostics = false;
  bool _showChannelDrawer = false;
  _VideoAspectPreset _aspectPreset = _VideoAspectPreset.original;
  double _videoScale = 1;
  double _brightness = 1.0;
  bool _isLandscapeLocked = false;
  Timer? _autoHideTimer;
  Timer? _hudTimer;
  String? _gestureHudText;
  IconData? _gestureHudIcon;

  bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (_isMobilePlatform) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    _scheduleAutoHide();
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    _hudTimer?.cancel();
    if (_isMobilePlatform) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations(const []);
    }
    super.dispose();
  }

  void _onUserInteraction() {
    if (!_showControls) {
      setState(() => _showControls = true);
    }
    _scheduleAutoHide();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _scheduleAutoHide();
    } else {
      _autoHideTimer?.cancel();
    }
  }

  void _scheduleAutoHide() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _showControls) {
        setState(() => _showControls = false);
      }
    });
  }

  void _showGestureHud(IconData icon, String text) {
    _hudTimer?.cancel();
    setState(() {
      _gestureHudIcon = icon;
      _gestureHudText = text;
    });
    _hudTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() {
          _gestureHudIcon = null;
          _gestureHudText = null;
        });
      }
    });
  }

  Future<void> _toggleOrientation() async {
    if (!_isMobilePlatform) return;
    final nextLandscape = !_isLandscapeLocked;
    setState(() => _isLandscapeLocked = nextLandscape);
    if (nextLandscape) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
      // Release lock shortly after so auto-rotate still works
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && !_isLandscapeLocked) {
          SystemChrome.setPreferredOrientations(const []);
        }
      });
    }
    _onUserInteraction();
  }

  void _selectAspectRatio(_VideoAspectPreset preset) {
    setState(() => _aspectPreset = preset);
    ref.read(playerControllerProvider.notifier).setAspectRatio(
          preset == _VideoAspectPreset.original ||
                  preset == _VideoAspectPreset.fillScreen
              ? ''
              : preset.label,
        );
    _onUserInteraction();
  }

  Future<void> _showVideoSizingSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A22),
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Aspect ratio',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _VideoAspectPreset.values.map((preset) {
                  final selected = _aspectPreset == preset;
                  return ChoiceChip(
                    label: Text(preset.label),
                    selected: selected,
                    onSelected: (_) {
                      _selectAspectRatio(preset);
                      setSheetState(() {});
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Video size',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  Text(
                    '${(_videoScale * 100).round()}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
              Slider(
                min: 0.5,
                max: 1.0,
                divisions: 10,
                value: _videoScale,
                onChanged: (value) {
                  setState(() => _videoScale = value);
                  setSheetState(() {});
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final controller = ref.read(playerControllerProvider.notifier);
    final playerState = ref.read(playerControllerProvider);

    switch (event.logicalKey) {
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
      case LogicalKeyboardKey.gameButtonA:
        if (_showChannelDrawer) return KeyEventResult.ignored;
        if (!_showControls) {
          _onUserInteraction();
          return KeyEventResult.handled;
        }
        // When controls are visible, let the focused button/slider handle OK/ENTER
        // so TV remote users can activate Back, Quality, Channels, Audio, etc.
        final primary = FocusManager.instance.primaryFocus;
        if (primary != null && primary != node) {
          _onUserInteraction();
          return KeyEventResult.ignored;
        }
        controller.togglePlayPause();
        _onUserInteraction();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.space:
      case LogicalKeyboardKey.mediaPlayPause:
        controller.togglePlayPause();
        _onUserInteraction();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.mediaPlay:
        if (!playerState.isPlaying) controller.togglePlayPause();
        _onUserInteraction();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.mediaPause:
        if (playerState.isPlaying) controller.togglePlayPause();
        _onUserInteraction();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.mediaRewind:
        final target = playerState.position - const Duration(seconds: 30);
        controller.seek(target < Duration.zero ? Duration.zero : target);
        _showGestureHud(Icons.fast_rewind_rounded, '-30s');
        _onUserInteraction();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.mediaFastForward:
        final target = playerState.position + const Duration(seconds: 30);
        controller.seek(target);
        _showGestureHud(Icons.fast_forward_rounded, '+30s');
        _onUserInteraction();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyC:
      case LogicalKeyboardKey.contextMenu:
        if (playerState.currentItem?.type == MediaType.live) {
          setState(() => _showChannelDrawer = !_showChannelDrawer);
          _onUserInteraction();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      case LogicalKeyboardKey.keyL:
        if (playerState.currentItem?.type == MediaType.live) {
          controller.playPreviousWatchedChannel();
          _onUserInteraction();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.goBack:
        if (_showChannelDrawer) {
          setState(() => _showChannelDrawer = false);
          return KeyEventResult.handled;
        }
        if (_showDiagnostics) {
          setState(() => _showDiagnostics = false);
          return KeyEventResult.handled;
        }
        controller.closePlayer();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
      case LogicalKeyboardKey.arrowRight:
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.arrowDown:
        if (_showChannelDrawer) return KeyEventResult.ignored;
        // When controls overlay is visible, let D-pad traverse the player buttons!
        if (_showControls) {
          _onUserInteraction();
          return KeyEventResult.ignored;
        }
        // When controls are hidden: LEFT/RIGHT seek VOD, UP/DOWN reveal controls
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
            playerState.currentItem?.type != MediaType.live) {
          final target = playerState.position - const Duration(seconds: 10);
          controller.seek(target < Duration.zero ? Duration.zero : target);
          _showGestureHud(Icons.fast_rewind_rounded, '-10s');
          _onUserInteraction();
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
            playerState.currentItem?.type != MediaType.live) {
          final target = playerState.position + const Duration(seconds: 10);
          controller.seek(target);
          _showGestureHud(Icons.fast_forward_rounded, '+10s');
          _onUserInteraction();
          return KeyEventResult.handled;
        }
        _onUserInteraction();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyM:
        controller.setVolume(playerState.volume > 0 ? 0.0 : 100.0);
        _onUserInteraction();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyF:
        if (playerState.isFullscreen) {
          controller.closePlayer();
        } else {
          controller.openFullscreen();
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyI:
        setState(() => _showDiagnostics = !_showDiagnostics);
        _onUserInteraction();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.pageUp:
      case LogicalKeyboardKey.channelUp:
        if (playerState.currentItem?.type == MediaType.live) {
          controller.playPreviousChannel();
          _onUserInteraction();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      case LogicalKeyboardKey.pageDown:
      case LogicalKeyboardKey.channelDown:
        if (playerState.currentItem?.type == MediaType.live) {
          controller.playNextChannel();
          _onUserInteraction();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerControllerProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final item = playerState.currentItem;

    if (item == null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) controller.closePlayer();
        },
        child: const Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: Text('No media loaded')),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.closePlayer();
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: MouseRegion(
          onHover: (_) => _onUserInteraction(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleControls,
            onDoubleTapDown: (details) {
              if (item.type == MediaType.live) return;
              final width = MediaQuery.sizeOf(context).width;
              final isLeft = details.localPosition.dx < width / 2;
              final delta = isLeft
                  ? const Duration(seconds: -10)
                  : const Duration(seconds: 10);
              final target = playerState.position + delta;
              controller.seek(target < Duration.zero ? Duration.zero : target);
              _showGestureHud(
                isLeft ? Icons.replay_10_rounded : Icons.forward_10_rounded,
                isLeft ? '-10s' : '+10s',
              );
            },
            onVerticalDragUpdate: (details) {
              if (!_isMobilePlatform) return;
              final width = MediaQuery.sizeOf(context).width;
              final isLeft = details.localPosition.dx < width / 2;
              final delta = -details.delta.dy / 220.0;
              if (isLeft) {
                final next = (_brightness + delta).clamp(0.25, 1.0);
                setState(() => _brightness = next);
                _showGestureHud(
                  Icons.brightness_6_rounded,
                  '${(next * 100).round()}%',
                );
              } else {
                final next = (playerState.volume + delta * 100).clamp(0.0, 100.0);
                controller.setVolume(next);
                _showGestureHud(
                  next <= 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  '${next.round()}%',
                );
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                // --- Video Surface ---
                Center(
                  child: ClipRect(
                    child: Transform.scale(
                      scale: _videoScale,
                      child: EngineVideoSurface(
                        fit: _aspectPreset.fit,
                        aspectRatio: _aspectPreset.aspectRatio,
                      ),
                    ),
                  ),
                ),

                // --- Software Brightness Dimmer Overlay ---
                if (_brightness < 0.99)
                  IgnorePointer(
                    child: Container(
                      color: Colors.black.withValues(alpha: (1.0 - _brightness).clamp(0.0, 0.75)),
                    ),
                  ),

                // --- Gesture Feedback HUD ---
                if (_gestureHudText != null && _gestureHudIcon != null)
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_gestureHudIcon, color: Colors.white, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              _gestureHudText!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // --- Subtle TISS Quality / Failover Notification Pill ---
                if (playerState.tissNotification != null)
                  Positioned(
                    top: 68,
                    left: 24,
                    right: 24,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF14141C)
                                .withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.high_quality_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  playerState.tissNotification!,
                                  maxLines: 2,
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // --- Buffering Indicator ---
                if (playerState.isBuffering && playerState.errorMessage == null)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          playerState.playbackState.displayLabel,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                // --- Playback Error Display ---
                if (playerState.errorMessage != null)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E24).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.redAccent.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Colors.redAccent,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Playback Error',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            playerState.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () => controller.playItem(item,
                                    startFullscreen: true),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              OutlinedButton.icon(
                                onPressed: controller.closePlayer,
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white70,
                                ),
                                label: const Text(
                                  'Close player',
                                  style: TextStyle(color: Colors.white70),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                // --- Diagnostics Panel ---
                if (_showDiagnostics)
                  const Positioned(
                    top: 80,
                    right: 24,
                    child: PlaybackDiagnosticsPanel(),
                  ),

                // --- In-Player Live Channel Overlay Drawer (Switch channels without stopping playback) ---
                if (_showChannelDrawer && item.type == MediaType.live)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: (MediaQuery.sizeOf(context).width * 0.78)
                        .clamp(260.0, 340.0),
                    child: _LiveChannelOverlayDrawer(
                      currentChannel: item,
                      onClose: () => setState(() => _showChannelDrawer = false),
                      onSelectChannel: (ch) {
                        if (ch.streamUrl != null && ch.streamUrl!.isNotEmpty) {
                          controller.switchStream(
                            MediaItem(
                              id: ch.providerId,
                              title: ch.title,
                              type: MediaType.live,
                              posterUrl: ch.posterUrl,
                              streamUrl: ch.streamUrl,
                              playlistId: ch.playlistId,
                              providerId: ch.providerId,
                              contentDbId: ch.id,
                            ),
                          );
                        }
                        setState(() => _showChannelDrawer = false);
                      },
                    ),
                  ),

                // --- Auto-Play Next Episode Overlay ---
                if (playerState.nextEpisodeItem != null &&
                    playerState.autoPlayEnabled &&
                    playerState.playbackState == PlaybackState.completed)
                  AutoPlayNextOverlay(
                      nextEpisode: playerState.nextEpisodeItem!),

                // --- Auto-Hiding Controls Overlay ---
                ExcludeFocus(
                  excluding: !_showControls,
                  child: IgnorePointer(
                    ignoring: !_showControls,
                    child: AnimatedOpacity(
                    opacity: _showControls ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.75),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // --- Top Header (Clean 1-line title + Minimize + More) ---
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  tooltip: 'Close player',
                                  onPressed: controller.closePlayer,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      if (item.subtitle != null &&
                                          item.subtitle!.isNotEmpty)
                                        Text(
                                          item.subtitle!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.7),
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.picture_in_picture_alt_rounded,
                                    color: Colors.white,
                                    size: 21,
                                  ),
                                  tooltip: 'Minimize to floating video',
                                  onPressed: controller.minimizePlayer,
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                  tooltip: 'Player options',
                                  onPressed: () => _showPlayerOptionsSheet(
                                    context,
                                    playerState,
                                    controller,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // --- Center Controls (Hidden while buffering so spinner is clean) ---
                          if (!playerState.isBuffering ||
                              playerState.errorMessage != null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (item.type == MediaType.live)
                                  IconButton(
                                    iconSize: 34,
                                    icon: const Icon(
                                        Icons.skip_previous_rounded,
                                        color: Colors.white),
                                    tooltip: 'Previous Channel',
                                    onPressed: controller.playPreviousChannel,
                                  )
                                else
                                  IconButton(
                                    iconSize: 34,
                                    icon: const Icon(Icons.replay_10_rounded,
                                        color: Colors.white),
                                    tooltip: 'Rewind 10s',
                                    onPressed: () {
                                      final target = playerState.position -
                                          const Duration(seconds: 10);
                                      controller.seek(target < Duration.zero
                                          ? Duration.zero
                                          : target);
                                    },
                                  ),
                                const SizedBox(width: 28),
                                GestureDetector(
                                  onTap: controller.togglePlayPause,
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.52),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white30,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      playerState.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                      size: 38,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 28),
                                if (item.type == MediaType.live)
                                  IconButton(
                                    iconSize: 34,
                                    icon: const Icon(Icons.skip_next_rounded,
                                        color: Colors.white),
                                    tooltip: 'Next Channel',
                                    onPressed: controller.playNextChannel,
                                  )
                                else
                                  IconButton(
                                    iconSize: 34,
                                    icon: const Icon(Icons.forward_10_rounded,
                                        color: Colors.white),
                                    tooltip: 'Forward 10s',
                                    onPressed: () {
                                      final target = playerState.position +
                                          const Duration(seconds: 10);
                                      controller.seek(target);
                                    },
                                  ),
                              ],
                            )
                          else
                            const SizedBox.shrink(),

                          // --- Bottom Controls (Minimal, well-aligned) ---
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.type != MediaType.live)
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: AppColors.primary,
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: AppColors.primary,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 6,
                                      ),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                        overlayRadius: 14,
                                      ),
                                      trackHeight: 3,
                                    ),
                                    child: Slider(
                                      value: playerState.duration.inSeconds > 0
                                          ? (playerState.position.inSeconds /
                                                  playerState
                                                      .duration.inSeconds)
                                              .clamp(0.0, 1.0)
                                          : 0.0,
                                      onChanged: (val) {
                                        final target = Duration(
                                          seconds: (val *
                                                  playerState
                                                      .duration.inSeconds)
                                              .toInt(),
                                        );
                                        controller.seek(target);
                                      },
                                    ),
                                  ),
                                Row(
                                  children: [
                                    if (item.type == MediaType.live) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.25),
                                          borderRadius:
                                              BorderRadius.circular(5),
                                          border: Border.all(
                                            color: AppColors.primary,
                                            width: 1,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.circle,
                                                color: AppColors.primary,
                                                size: 7),
                                            SizedBox(width: 5),
                                            Text(
                                              'LIVE',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (playerState.position >
                                          Duration.zero) ...[
                                        const SizedBox(width: 10),
                                        Text(
                                          _format(playerState.position),
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.75),
                                            fontSize: 12.5,
                                            fontFamily: 'monospace',
                                          ),
                                        ),
                                      ],
                                    ] else
                                      Text(
                                        '${_format(playerState.position)} / ${_format(playerState.duration)}',
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.85),
                                          fontSize: 12.5,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    const Spacer(),
                                    if (playerState.nextEpisodeItem != null)
                                      TextButton.icon(
                                        onPressed: () => controller.playItem(
                                          playerState.nextEpisodeItem!,
                                          startFullscreen: true,
                                        ),
                                        icon: const Icon(
                                          Icons.skip_next_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Next',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    if (item.type == MediaType.live)
                                      IconButton(
                                        icon: Icon(
                                          Icons.list_rounded,
                                          color: _showChannelDrawer
                                              ? AppColors.primary
                                              : Colors.white,
                                          size: 22,
                                        ),
                                        tooltip: 'Channels',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () {
                                          setState(() => _showChannelDrawer =
                                              !_showChannelDrawer);
                                          _onUserInteraction();
                                        },
                                      ),
                                    if (item.type != MediaType.live)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.subtitles_outlined,
                                          color: Colors.white,
                                          size: 21,
                                        ),
                                        tooltip: 'Subtitles',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () =>
                                            _showSubtitleTrackDialog(
                                          context,
                                          controller,
                                        ),
                                      ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.audiotrack_rounded,
                                        color: Colors.white,
                                        size: 21,
                                      ),
                                      tooltip: 'Audio Track',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _showAudioTrackDialog(
                                        context,
                                        controller,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        playerState.volume > 0
                                            ? Icons.volume_up_rounded
                                            : Icons.volume_off_rounded,
                                        color: Colors.white,
                                        size: 21,
                                      ),
                                      tooltip: playerState.volume > 0
                                          ? 'Mute'
                                          : 'Unmute',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => controller.setVolume(
                                        playerState.volume > 0 ? 0.0 : 100.0,
                                      ),
                                    ),
                                    if (_isMobilePlatform)
                                      IconButton(
                                        icon: Icon(
                                          _isLandscapeLocked
                                              ? Icons
                                                  .screen_lock_landscape_rounded
                                              : Icons.screen_rotation_rounded,
                                          color: Colors.white,
                                          size: 21,
                                        ),
                                        tooltip: 'Rotate Screen',
                                        visualDensity: VisualDensity.compact,
                                        onPressed: _toggleOrientation,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  void _showSmartStreamQualitySheet(
    BuildContext context,
    PlayerController controller,
  ) {
    final tiss = controller.tissController;
    final logical = tiss.activeChannel;
    final abrRenditions = controller.availableRenditions;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF16161C),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Stream Quality',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Auto Quality Intelligence',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: SmartStreamMode.values.map((mode) {
                  final selected = controller.smartStreamMode == mode;
                  return ChoiceChip(
                    label: Text(mode.label),
                    selected: selected,
                    onSelected: (_) {
                      controller.setSmartStreamMode(mode);
                      Navigator.pop(sheetCtx);
                    },
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 12,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: selected
                            ? AppColors.primary
                            : Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 8),
              if (logical != null && logical.alternatives.length > 1) ...[
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.tune_rounded,
                    color: tiss.isAutoMode ? AppColors.primary : Colors.white60,
                    size: 20,
                  ),
                  title: const Text('Auto (SmartStream)',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    'Automatically switches quality if buffering occurs',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11.5),
                  ),
                  trailing: tiss.isAutoMode
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.primary)
                      : null,
                  onTap: () {
                    controller.selectTissQuality(null);
                    Navigator.pop(sheetCtx);
                  },
                ),
                ...logical.alternatives.map((alt) {
                  final isSelected = !tiss.isAutoMode &&
                      tiss.activeStream?.streamId == alt.streamId;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.hd_outlined,
                      color: isSelected ? AppColors.primary : Colors.white54,
                      size: 20,
                    ),
                    title: Text(
                      alt.qualityMenuLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      alt.qualitySource.label,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 11.5),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.primary)
                        : null,
                    onTap: () {
                      controller.selectTissQuality(alt);
                      Navigator.pop(sheetCtx);
                    },
                  );
                }),
              ] else if (abrRenditions.isNotEmpty) ...[
                ...abrRenditions.map((r) {
                  final isSelected = controller.selectedRendition.id == r.id;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(r.label,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14)),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: AppColors.primary)
                        : null,
                    onTap: () {
                      controller.selectQuality(r);
                      Navigator.pop(sheetCtx);
                    },
                  );
                }),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Only a single fixed-quality stream is available for this channel.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12.5,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlayerOptionsSheet(
    BuildContext context,
    PlayerState playerState,
    PlayerController controller,
  ) {
    final item = playerState.currentItem;
    if (item == null) return;
    final recState = ref.read(streamRecordingProvider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF16161C),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // SmartStream Quality & Mode Selector
              ListTile(
                leading: const Icon(Icons.high_quality_rounded,
                    color: AppColors.primary),
                title: const Text('Stream Quality',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                subtitle: Text(
                  'SmartStream: ${controller.smartStreamMode.label}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                ),
                trailing: Text(
                  controller.tissController.hasAlternatives
                      ? (controller.tissController.isAutoMode
                          ? 'Auto (${controller.tissController.activeStream?.displayQuality ?? "HD"})'
                          : (controller.tissController.activeStream
                                  ?.qualityMenuLabel ??
                              'Auto'))
                      : (controller.availableRenditions.isNotEmpty
                          ? controller.selectedRendition.label
                          : 'Auto'),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showSmartStreamQualitySheet(context, controller);
                },
              ),
              if (item.type != MediaType.live)
                ListTile(
                  leading: const Icon(Icons.speed_rounded, color: Colors.white),
                  title: const Text('Playback Speed',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  trailing: Text(
                    '${playerState.playbackRate}x',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    PlaybackSpeedSheet.show(context);
                  },
                ),
              ListTile(
                leading:
                    const Icon(Icons.aspect_ratio_rounded, color: Colors.white),
                title: const Text('Aspect Ratio & Zoom',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                trailing: Text(
                  _aspectPreset.label,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _showVideoSizingSheet();
                },
              ),
              if (LibVlcBridge.isSupported)
                ListTile(
                  leading: const Icon(Icons.settings_input_component_rounded,
                      color: Colors.white),
                  title: const Text('Playback Engine',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  trailing: Text(
                    playerState.playbackEngine.label,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    final next =
                        playerState.playbackEngine == PlaybackEngine.libVlc
                            ? PlaybackEngine.mediaKit
                            : PlaybackEngine.libVlc;
                    controller.setPlaybackEngine(next);
                    _showGestureHud(
                      Icons.settings_input_component_rounded,
                      'Engine: ${next.shortLabel}',
                    );
                  },
                ),
              if (item.streamUrl != null && item.streamUrl!.isNotEmpty)
                ListTile(
                  leading: Icon(
                    recState.isRecording
                        ? Icons.stop_circle_rounded
                        : Icons.fiber_manual_record_rounded,
                    color: Colors.redAccent,
                  ),
                  title: Text(
                    recState.isRecording
                        ? 'Stop Recording (${recState.formattedDuration})'
                        : 'Record Stream (DVR)',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    if (recState.isRecording) {
                      ref
                          .read(streamRecordingProvider.notifier)
                          .stopRecording();
                    } else {
                      ref
                          .read(streamRecordingProvider.notifier)
                          .startRecording(item.streamUrl!, item.title);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Started recording "${item.title}"'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                ),
              if (item.streamUrl != null && item.streamUrl!.isNotEmpty)
                ListTile(
                  leading:
                      const Icon(Icons.open_in_new_rounded, color: Colors.white),
                  title: const Text('Open in External Player (VLC)',
                      style: TextStyle(color: Colors.white, fontSize: 14)),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    final ok =
                        await ExternalPlayerService.openInVlc(item.streamUrl!);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Could not launch VLC. Is VLC installed?'),
                        ),
                      );
                    }
                  },
                ),
              ListTile(
                leading: Icon(
                  Icons.info_outline_rounded,
                  color: _showDiagnostics ? AppColors.primary : Colors.white,
                ),
                title: Text(
                  _showDiagnostics
                      ? 'Hide Stream Diagnostics'
                      : 'Show Stream Diagnostics',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  setState(() => _showDiagnostics = !_showDiagnostics);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAudioTrackDialog(
    BuildContext context,
    PlayerController controller,
  ) {
    final playerState = ref.read(playerControllerProvider);
    if (playerState.playbackEngine == PlaybackEngine.libVlc &&
        LibVlcBridge.isSupported) {
      final tracks = playerState.vlcAudioTracks;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          title: const Text(
            'Select Audio Track (LibVLC)',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: tracks.isEmpty
              ? const Text(
                  'No alternative audio tracks found.',
                  style: TextStyle(color: Colors.white70),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: tracks.map((track) {
                    final selected = track.id == playerState.activeVlcAudioTrack;
                    return ListTile(
                      title: Text(
                        track.name,
                        style: TextStyle(
                          color: selected ? AppColors.primary : Colors.white,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                      trailing: selected
                          ? const Icon(Icons.check_rounded,
                              color: AppColors.primary, size: 18)
                          : null,
                      onTap: () {
                        controller.setVlcAudioTrack(track.id);
                        Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
        ),
      );
      return;
    }

    final tracks = controller.player.state.tracks.audio;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text(
          'Select Audio Track',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: tracks.isEmpty
            ? const Text(
                'No alternative audio tracks found.',
                style: TextStyle(color: Colors.white70),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: tracks.map((track) {
                  final label = track.title ?? track.language ?? track.id;
                  return ListTile(
                    title: Text(
                      label,
                      style: const TextStyle(color: Colors.white),
                    ),
                    onTap: () {
                      controller.player.setAudioTrack(track);
                      Navigator.pop(ctx);
                    },
                  );
                }).toList(),
              ),
      ),
    );
  }

  void _showSubtitleTrackDialog(
    BuildContext context,
    PlayerController controller,
  ) {
    final playerState = ref.read(playerControllerProvider);
    if (playerState.playbackEngine == PlaybackEngine.libVlc &&
        LibVlcBridge.isSupported) {
      final tracks = playerState.vlcSubtitleTracks;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E24),
          title: const Text(
            'Select Subtitles (LibVLC)',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text(
                  'Off (Disable Subtitles)',
                  style: TextStyle(color: Colors.white70),
                ),
                onTap: () {
                  controller.setVlcSubtitleTrack(-1);
                  Navigator.pop(ctx);
                },
              ),
              ...tracks.map((track) {
                final selected =
                    track.id == playerState.activeVlcSubtitleTrack;
                return ListTile(
                  title: Text(
                    track.name,
                    style: TextStyle(
                      color: selected ? AppColors.primary : Colors.white,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.normal,
                    ),
                  ),
                  trailing: selected
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.primary, size: 18)
                      : null,
                  onTap: () {
                    controller.setVlcSubtitleTrack(track.id);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      );
      return;
    }

    final tracks = controller.player.state.tracks.subtitle;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        title: const Text(
          'Select Subtitles',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text(
                'Off (Disable Subtitles)',
                style: TextStyle(color: Colors.white70),
              ),
              onTap: () {
                controller.player.setSubtitleTrack(SubtitleTrack.no());
                Navigator.pop(ctx);
              },
            ),
            ...tracks.map((track) {
              final label = track.title ?? track.language ?? track.id;
              return ListTile(
                title: Text(
                  label,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () {
                  controller.player.setSubtitleTrack(track);
                  Navigator.pop(ctx);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  String _format(Duration d) {
    if (d <= Duration.zero) return '00:00';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

class _LiveChannelOverlayDrawer extends ConsumerWidget {
  final MediaItem currentChannel;
  final VoidCallback onClose;
  final ValueChanged<ContentItemsTableData> onSelectChannel;

  const _LiveChannelOverlayDrawer({
    required this.currentChannel,
    required this.onClose,
    required this.onSelectChannel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final playlistId =
        currentChannel.playlistId ?? ref.watch(activePlaylistIdProvider);

    return Material(
      color: const Color(0xF0101016),
      elevation: 16,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Live Channels',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            Expanded(
              child: playlistId == null
                  ? const Center(
                      child: Text(
                        'No active playlist',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : StreamBuilder<List<ContentItemsTableData>>(
                      stream: db.watchContentItems(playlistId, 'live'),
                      builder: (context, snapshot) {
                        final channels = snapshot.data ?? [];
                        if (channels.isEmpty) {
                          return const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary),
                          );
                        }
                        return ListView.builder(
                          itemCount: channels.length,
                          itemBuilder: (context, index) {
                            final ch = channels[index];
                            final isPlaying =
                                ch.providerId == currentChannel.providerId;
                            return ListTile(
                              autofocus: isPlaying,
                              selected: isPlaying,
                              selectedTileColor:
                                  AppColors.primary.withValues(alpha: 0.2),
                              leading: Icon(
                                isPlaying
                                    ? Icons.play_arrow_rounded
                                    : Icons.live_tv_rounded,
                                color: isPlaying
                                    ? AppColors.primary
                                    : Colors.white54,
                                size: 20,
                              ),
                              title: Text(
                                ch.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: isPlaying
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                              onTap: () => onSelectChannel(ch),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
