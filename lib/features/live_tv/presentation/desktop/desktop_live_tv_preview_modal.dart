import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:drift/drift.dart' as drift;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/persistence/app_database.dart';
import '../../../../core/persistence/database_provider.dart';
import '../../../../shared/models/media_item.dart';
import '../../../player/data/player_controller.dart';
import '../../../epg/data/epg_repository_impl.dart';
import '../../../epg/presentation/reminders_dialog.dart';

class DesktopLiveTvPreviewModal extends ConsumerStatefulWidget {
  final ContentItemsTableData channel;

  const DesktopLiveTvPreviewModal({super.key, required this.channel});

  @override
  ConsumerState<DesktopLiveTvPreviewModal> createState() =>
      _DesktopLiveTvPreviewModalState();
}

class _DesktopLiveTvPreviewModalState
    extends ConsumerState<DesktopLiveTvPreviewModal> {
  late ContentItemsTableData _currentChannel;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _currentChannel = widget.channel;
    _startPlayback();
    _progressTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startPlayback() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final player = ref.read(playerControllerProvider.notifier);
      final media = _toMediaItem(_currentChannel);
      player.playItem(media, startFullscreen: false);
    });
  }

  MediaItem _toMediaItem(ContentItemsTableData ch) {
    return MediaItem(
      id: ch.providerId,
      title: ch.title,
      type: MediaType.live,
      posterUrl: ch.posterUrl,
      streamUrl: ch.streamUrl,
      playlistId: ch.playlistId,
      providerId: ch.providerId,
      contentDbId: ch.id,
    );
  }

  void _switchChannel(ContentItemsTableData nextCh) {
    setState(() {
      _currentChannel = nextCh;
    });
    final player = ref.read(playerControllerProvider.notifier);
    player.playItem(_toMediaItem(nextCh), startFullscreen: false);
  }

  Future<void> _changeChannelDelta(int delta) async {
    final db = ref.read(databaseProvider);
    final channels = await (db.select(db.contentItemsTable)
          ..where((t) => t.playlistId.equals(_currentChannel.playlistId))
          ..where((t) => t.type.equals('live'))
          ..orderBy([(t) => drift.OrderingTerm(expression: t.id)]))
        .get();

    if (channels.isEmpty) return;
    final currentIndex =
        channels.indexWhere((c) => c.providerId == _currentChannel.providerId);
    if (currentIndex == -1) return;

    final nextIndex = (currentIndex + delta + channels.length) % channels.length;
    _switchChannel(channels[nextIndex]);
  }

  void _watchFullScreen() {
    Navigator.of(context).pop();
    final player = ref.read(playerControllerProvider.notifier);
    player.openFullscreen();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final modalWidth = (screenSize.width * 0.82).clamp(840.0, 1160.0);
    final modalHeight = (screenSize.height * 0.84).clamp(540.0, 780.0);

    final playerState = ref.watch(playerControllerProvider);
    final playerController = ref.read(playerControllerProvider.notifier);
    final db = ref.watch(databaseProvider);
    final epgRepo = EpgRepositoryImpl(
      db: db,
      dio: ref.read(apiClientProvider).dio,
    );

    final epgId = _currentChannel.epgChannelId ?? _currentChannel.title;
    final scheduleStream = epgRepo.watchChannelSchedule(epgId);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.of(context).pop();
        },
      },
      child: Focus(
        autofocus: true,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Container(
            width: modalWidth,
            height: modalHeight,
            decoration: BoxDecoration(
              color: const Color(0xFF131317),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black87,
                  blurRadius: 40,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Left: Video Preview Player & Quick Actions ──
                    Expanded(
                      flex: 6,
                      child: Container(
                        color: Colors.black,
                        child: Column(
                          children: [
                            // 16:9 Video surface
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Video(
                                    controller: playerController.videoController,
                                    controls: NoVideoControls,
                                  ),
                                  if (playerState.isBuffering)
                                    const Center(
                                      child: CircularProgressIndicator(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  if (playerState.errorMessage != null)
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          playerState.errorMessage!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            // Mini Video Control Bar
                            Container(
                              color: const Color(0xFF181820),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(
                                children: [
                                  // Play / Pause
                                  IconButton(
                                    icon: Icon(
                                      playerState.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.white,
                                    ),
                                    onPressed: () =>
                                        playerController.togglePlayPause(),
                                  ),
                                  // Mute / Unmute
                                  IconButton(
                                    icon: Icon(
                                      playerState.isMuted
                                          ? Icons.volume_off_rounded
                                          : Icons.volume_up_rounded,
                                      color: Colors.white70,
                                    ),
                                    onPressed: () =>
                                        playerController.toggleMute(),
                                  ),

                                  const Spacer(),

                                  // Prev Channel
                                  IconButton(
                                    tooltip: 'Previous Channel',
                                    icon: const Icon(Icons.skip_previous_rounded,
                                        color: Colors.white70),
                                    onPressed: () => _changeChannelDelta(-1),
                                  ),

                                  // Next Channel
                                  IconButton(
                                    tooltip: 'Next Channel',
                                    icon: const Icon(Icons.skip_next_rounded,
                                        color: Colors.white70),
                                    onPressed: () => _changeChannelDelta(1),
                                  ),

                                  const SizedBox(width: 8),

                                  // Watch Full Screen Button
                                  ElevatedButton.icon(
                                    onPressed: _watchFullScreen,
                                    icon: const Icon(Icons.fullscreen_rounded,
                                        size: 20, color: Colors.white),
                                    label: const Text(
                                      'Watch Fullscreen',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Right: Channel Info, Current Programme & EPG Schedule ──
                    Expanded(
                      flex: 5,
                      child: Container(
                        color: const Color(0xFF16161D),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Channel Header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                              child: Row(
                                children: [
                                  // Channel logo
                                  if (_currentChannel.posterUrl != null &&
                                      _currentChannel.posterUrl!.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: CachedNetworkImage(
                                        imageUrl: _currentChannel.posterUrl!,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.contain,
                                        errorWidget: (_, __, ___) =>
                                            _buildChannelFallback(),
                                      ),
                                    )
                                  else
                                    _buildChannelFallback(),

                                  const SizedBox(width: 14),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _currentChannel.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.redAccent
                                                    .withValues(alpha: 0.2),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                border: Border.all(
                                                    color: Colors.redAccent,
                                                    width: 0.8),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.circle,
                                                      size: 7,
                                                      color: Colors.redAccent),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'LIVE',
                                                    style: TextStyle(
                                                      color: Colors.redAccent,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (_currentChannel.containerExtension !=
                                                null) ...[
                                              const SizedBox(width: 8),
                                              Text(
                                                _currentChannel
                                                    .containerExtension!
                                                    .toUpperCase(),
                                                style: const TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Divider(color: Colors.white12, height: 1),

                            // EPG Section Title
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Programme Guide (EPG)',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => RemindersDialog.show(context),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.alarm_rounded,
                                            color: AppColors.primary, size: 15),
                                        SizedBox(width: 4),
                                        Text(
                                          'My Reminders',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // EPG Programme Stream List
                            Expanded(
                              child: StreamBuilder<List<EpgProgramsTableData>>(
                                stream: scheduleStream,
                                builder: (context, snapshot) {
                                  final programs = snapshot.data ?? [];
                                  final now = DateTime.now().toUtc();

                                  if (snapshot.connectionState ==
                                          ConnectionState.waiting &&
                                      programs.isEmpty) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: AppColors.primary,
                                        strokeWidth: 2,
                                      ),
                                    );
                                  }

                                  if (programs.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.calendar_today_rounded,
                                            size: 40,
                                            color: Colors.white.withValues(
                                                alpha: 0.2),
                                          ),
                                          const SizedBox(height: 10),
                                          const Text(
                                            'No EPG schedule available',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Channel metadata will appear when synced.',
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.4),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  final timeFormat = DateFormat.jm();

                                  return ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    itemCount: programs.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, idx) {
                                      final prog = programs[idx];
                                      final isLive = prog.start.isBefore(now) &&
                                          prog.stop.isAfter(now);
                                      final isUpcoming = prog.start.isAfter(now);

                                      double progress = 0.0;
                                      if (isLive) {
                                        final total = prog.stop
                                            .difference(prog.start)
                                            .inSeconds;
                                        final elapsed =
                                            now.difference(prog.start).inSeconds;
                                        if (total > 0) {
                                          progress = (elapsed / total).clamp(0.0, 1.0);
                                        }
                                      }

                                      return Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isLive
                                              ? AppColors.primary
                                                  .withValues(alpha: 0.12)
                                              : Colors.white
                                                  .withValues(alpha: 0.04),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isLive
                                                ? AppColors.primary
                                                    .withValues(alpha: 0.5)
                                                : Colors.white
                                                    .withValues(alpha: 0.06),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                if (isLive) ...[
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 6,
                                                        vertical: 2),
                                                    margin: const EdgeInsets
                                                        .only(right: 8),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.primary,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4),
                                                    ),
                                                    child: const Text(
                                                      'NOW',
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 9.5,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                Expanded(
                                                  child: Text(
                                                    prog.title,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 13.5,
                                                      fontWeight: isLive
                                                          ? FontWeight.w800
                                                          : FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  '${timeFormat.format(prog.start.toLocal())} – ${timeFormat.format(prog.stop.toLocal())}',
                                                  style: TextStyle(
                                                    color: isLive
                                                        ? AppColors.primary
                                                        : Colors.white54,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                if (isUpcoming) ...[
                                                  const SizedBox(width: 6),
                                                  IconButton(
                                                    tooltip: 'Set Reminder',
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                    icon: const Icon(
                                                      Icons.alarm_add_rounded,
                                                      color: AppColors.primary,
                                                      size: 18,
                                                    ),
                                                    onPressed: () {
                                                      SetReminderHelper.prompt(
                                                        context,
                                                        ref: ref,
                                                        channelId:
                                                            _currentChannel.providerId,
                                                        channelName:
                                                            _currentChannel.title,
                                                        channelLogo:
                                                            _currentChannel.posterUrl,
                                                        streamUrl:
                                                            _currentChannel.streamUrl,
                                                        programTitle: prog.title,
                                                        programDescription:
                                                            prog.description,
                                                        start: prog.start,
                                                        stop: prog.stop,
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (prog.description != null &&
                                                prog.description!.isNotEmpty) ...[
                                              const SizedBox(height: 5),
                                              Text(
                                                prog.description!,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.65),
                                                  fontSize: 11.5,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                            if (isLive) ...[
                                              const SizedBox(height: 8),
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                                child: LinearProgressIndicator(
                                                  value: progress,
                                                  minHeight: 3,
                                                  backgroundColor:
                                                      Colors.white12,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Floating Close Button (Top-Right)
                Positioned(
                  top: 14,
                  right: 14,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 18),
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

  Widget _buildChannelFallback() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          _currentChannel.title.isNotEmpty
              ? _currentChannel.title[0].toUpperCase()
              : 'TV',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
