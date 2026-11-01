import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../shared/models/media_item.dart';
import '../../../core/theme/app_colors.dart';
import '../data/player_controller.dart';
import '../data/stream_recording_service.dart';
import '../data/external_player_service.dart';
import '../domain/playback_enums.dart';
import 'widgets/diagnostics_panel.dart';
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
  DateTime _lastInteraction = DateTime.now();
  bool _showDiagnostics = false;
  _VideoAspectPreset _aspectPreset = _VideoAspectPreset.original;
  double _videoScale = 1;

  void _onUserInteraction() {
    setState(() {
      _showControls = true;
      _lastInteraction = DateTime.now();
    });
    _scheduleAutoHide();
  }

  void _scheduleAutoHide() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted &&
          DateTime.now().difference(_lastInteraction).inSeconds >= 4) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _selectAspectRatio(_VideoAspectPreset preset) {
    setState(() => _aspectPreset = preset);
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
      case LogicalKeyboardKey.space:
        controller.togglePlayPause();
        _onUserInteraction();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        final target = playerState.position - const Duration(seconds: 10);
        controller.seek(target < Duration.zero ? Duration.zero : target);
        _onUserInteraction();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        final target = playerState.position + const Duration(seconds: 10);
        controller.seek(target);
        _onUserInteraction();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        controller.setVolume((playerState.volume + 10).clamp(0.0, 100.0));
        _onUserInteraction();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        controller.setVolume((playerState.volume - 10).clamp(0.0, 100.0));
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
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('No media loaded')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: MouseRegion(
          onHover: (_) => _onUserInteraction(),
          child: GestureDetector(
            onTap: () => _onUserInteraction(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // --- Video Surface ---
                Center(
                  child: ClipRect(
                    child: Transform.scale(
                      scale: _videoScale,
                      child: Video(
                        controller: controller.videoController,
                        fit: _aspectPreset.fit,
                        aspectRatio: _aspectPreset.aspectRatio,
                        controls: NoVideoControls,
                      ),
                    ),
                  ),
                ),

                // --- Buffering Indicator ---
                if (playerState.isBuffering && playerState.errorMessage == null)
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 14),
                        Text(
                          'Connecting & buffering stream...',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
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

                // --- Auto-Play Next Episode Overlay ---
                if (playerState.nextEpisodeItem != null &&
                    playerState.autoPlayEnabled &&
                    playerState.playbackState == PlaybackState.completed)
                  AutoPlayNextOverlay(
                      nextEpisode: playerState.nextEpisodeItem!),

                // --- Auto-Hiding Controls Overlay ---
                AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
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
                          // --- Top Header ---
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                  tooltip: 'Close player',
                                  onPressed: controller.closePlayer,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (item.subtitle != null)
                                        Text(
                                          item.subtitle!,
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.65),
                                            fontSize: 13,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                // Speed button
                                IconButton(
                                  icon: const Icon(
                                    Icons.speed_rounded,
                                    color: Colors.white,
                                  ),
                                  tooltip: 'Playback Speed',
                                  onPressed: () =>
                                      PlaybackSpeedSheet.show(context),
                                ),
                                IconButton(
                                  tooltip: 'Video size and aspect ratio',
                                  icon: const Icon(
                                    Icons.aspect_ratio_rounded,
                                    color: Colors.white,
                                  ),
                                  onPressed: _showVideoSizingSheet,
                                ),
                                // Diagnostics button
                                IconButton(
                                  icon: Icon(
                                    Icons.info_outline_rounded,
                                    color: _showDiagnostics
                                        ? AppColors.primary
                                        : Colors.white,
                                  ),
                                  tooltip: 'Playback Diagnostics',
                                  onPressed: () => setState(
                                    () => _showDiagnostics = !_showDiagnostics,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // --- Center Controls (Play/Pause + Live Zapping / Seek) ---
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (item.type == MediaType.live)
                                IconButton(
                                  iconSize: 38,
                                  icon: const Icon(Icons.skip_previous_rounded,
                                      color: Colors.white),
                                  tooltip: 'Previous Channel (PageUp)',
                                  onPressed: () =>
                                      controller.playPreviousChannel(),
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
                              const SizedBox(width: 20),
                              GestureDetector(
                                onTap: () => controller.togglePlayPause(),
                                child: Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white24,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    playerState.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              if (item.type == MediaType.live)
                                IconButton(
                                  iconSize: 38,
                                  icon: const Icon(Icons.skip_next_rounded,
                                      color: Colors.white),
                                  tooltip: 'Next Channel (PageDown)',
                                  onPressed: () => controller.playNextChannel(),
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
                          ),

                          // --- Bottom Controls ---
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Progress Slider or Live Badge
                                if (item.type == MediaType.live)
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent
                                                .withValues(alpha: 0.25),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                                color: Colors.redAccent,
                                                width: 1),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.circle,
                                                  color: Colors.redAccent,
                                                  size: 8),
                                              SizedBox(width: 6),
                                              Text(
                                                'LIVE',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 0.8,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: AppColors.primary,
                                      inactiveTrackColor: Colors.white24,
                                      thumbColor: Colors.white,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 6,
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
                                    Text(
                                      item.type == MediaType.live
                                          ? (playerState.position >
                                                  Duration.zero
                                              ? 'Live • ${_format(playerState.position)}'
                                              : 'Live Stream')
                                          : '${_format(playerState.position)} / ${_format(playerState.duration)}',
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.8),
                                        fontSize: 13,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    const Spacer(),
                                    Flexible(
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // DVR Live Stream Recording
                                            Consumer(
                                              builder: (context, ref, _) {
                                                final recState = ref.watch(
                                                    streamRecordingProvider);
                                                final streamUrl = playerState
                                                    .currentItem?.streamUrl;

                                                if (recState.isRecording) {
                                                  return InkWell(
                                                    onTap: () => ref
                                                        .read(
                                                            streamRecordingProvider
                                                                .notifier)
                                                        .stopRecording(),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 10,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.redAccent
                                                            .withValues(
                                                                alpha: 0.25),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                        border: Border.all(
                                                          color:
                                                              Colors.redAccent,
                                                        ),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          const Icon(
                                                            Icons.stop_rounded,
                                                            color: Colors
                                                                .redAccent,
                                                            size: 16,
                                                          ),
                                                          const SizedBox(
                                                              width: 4),
                                                          Text(
                                                            'REC ${recState.formattedDuration} (${recState.formattedSize})',
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  Colors.white,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                }

                                                if (streamUrl != null &&
                                                    streamUrl.isNotEmpty) {
                                                  return IconButton(
                                                    icon: const Icon(
                                                      Icons
                                                          .fiber_manual_record_rounded,
                                                      color: Colors.redAccent,
                                                    ),
                                                    tooltip:
                                                        'Record Stream (DVR)',
                                                    onPressed: () {
                                                      final title = playerState
                                                              .currentItem
                                                              ?.title ??
                                                          'Stream';
                                                      ref
                                                          .read(
                                                              streamRecordingProvider
                                                                  .notifier)
                                                          .startRecording(
                                                              streamUrl, title);
                                                      ScaffoldMessenger.of(
                                                              context)
                                                          .showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Started recording "$title" to Documents/Recordings',
                                                          ),
                                                          backgroundColor:
                                                              Colors.redAccent,
                                                        ),
                                                      );
                                                    },
                                                  );
                                                }
                                                return const SizedBox.shrink();
                                              },
                                            ),

                                            // External Player Launcher
                                            PopupMenuButton<String>(
                                              icon: const Icon(
                                                Icons.open_in_new_rounded,
                                                color: Colors.white70,
                                              ),
                                              tooltip:
                                                  'Open in External Player',
                                              color: const Color(0xFF1E1E24),
                                              onSelected: (val) async {
                                                final streamUrl = playerState
                                                    .currentItem?.streamUrl;
                                                if (streamUrl == null) return;
                                                if (val == 'vlc') {
                                                  final ok =
                                                      await ExternalPlayerService
                                                          .openInVlc(streamUrl);
                                                  if (!ok && context.mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Could not launch VLC. Is VLC installed?',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                } else if (val == 'mpv') {
                                                  final ok =
                                                      await ExternalPlayerService
                                                          .openInMpv(streamUrl);
                                                  if (!ok && context.mounted) {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Could not launch MPV standalone.',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                }
                                              },
                                              itemBuilder: (ctx) => [
                                                const PopupMenuItem(
                                                  value: 'vlc',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .play_circle_outline,
                                                        color: Colors.orange,
                                                        size: 18,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Open in VLC Player',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'mpv',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .movie_filter_outlined,
                                                        color:
                                                            Colors.purpleAccent,
                                                        size: 18,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Open in MPV Standalone',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.audiotrack_rounded,
                                                color: Colors.white,
                                              ),
                                              tooltip: 'Audio Track',
                                              onPressed: () =>
                                                  _showAudioTrackDialog(
                                                context,
                                                controller,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.subtitles_rounded,
                                                color: Colors.white,
                                              ),
                                              tooltip: 'Subtitles',
                                              onPressed: () =>
                                                  _showSubtitleTrackDialog(
                                                context,
                                                controller,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.replay_10_rounded,
                                                color: Colors.white,
                                              ),
                                              onPressed: () {
                                                final target = playerState
                                                        .position -
                                                    const Duration(seconds: 10);
                                                controller.seek(
                                                    target < Duration.zero
                                                        ? Duration.zero
                                                        : target);
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.forward_10_rounded,
                                                color: Colors.white,
                                              ),
                                              onPressed: () {
                                                final target = playerState
                                                        .position +
                                                    const Duration(seconds: 10);
                                                controller.seek(target);
                                              },
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                playerState.volume > 0
                                                    ? Icons.volume_up_rounded
                                                    : Icons.volume_off_rounded,
                                                color: Colors.white,
                                              ),
                                              onPressed: () {
                                                controller.setVolume(
                                                  playerState.volume > 0
                                                      ? 0.0
                                                      : 100.0,
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAudioTrackDialog(
    BuildContext context,
    PlayerController controller,
  ) {
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
