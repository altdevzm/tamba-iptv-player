import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/persistence/app_database.dart';
import '../../../../core/persistence/database_provider.dart';
import '../../../../shared/models/media_item.dart';
import '../../../player/data/player_controller.dart';
import '../../../epg/data/epg_repository_impl.dart';
import '../../../epg/presentation/reminders_dialog.dart';

class MobileLiveTvPreviewSheet extends ConsumerStatefulWidget {
  final ContentItemsTableData channel;

  const MobileLiveTvPreviewSheet({super.key, required this.channel});

  @override
  ConsumerState<MobileLiveTvPreviewSheet> createState() =>
      _MobileLiveTvPreviewSheetState();
}

class _MobileLiveTvPreviewSheetState
    extends ConsumerState<MobileLiveTvPreviewSheet> {
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
      player.playItem(_toMediaItem(_currentChannel), startFullscreen: false);
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

  void _watchFullScreen() {
    Navigator.of(context).pop();
    final player = ref.read(playerControllerProvider.notifier);
    player.openFullscreen();
  }

  @override
  Widget build(BuildContext context) {
    final playerState = ref.watch(playerControllerProvider);
    final playerController = ref.read(playerControllerProvider.notifier);
    final db = ref.watch(databaseProvider);
    final epgRepo = EpgRepositoryImpl(
      db: db,
      dio: ref.read(apiClientProvider).dio,
    );

    final epgId = _currentChannel.epgChannelId ?? _currentChannel.title;
    final scheduleStream = epgRepo.watchChannelSchedule(epgId);
    final timeFormat = DateFormat.jm();

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF141419),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Compact Video Preview Player (16:9)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: Colors.black),
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
                    // Live badge overlay
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 6, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Watch Full Screen floating button
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: ElevatedButton.icon(
                        onPressed: _watchFullScreen,
                        icon: const Icon(Icons.fullscreen_rounded,
                            size: 18, color: Colors.white),
                        label: const Text(
                          'Full Screen',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.9),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Channel Information & EPG
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Channel Logo & Name
                    Row(
                      children: [
                        if (_currentChannel.posterUrl != null &&
                            _currentChannel.posterUrl!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: _currentChannel.posterUrl!,
                              width: 44,
                              height: 44,
                              fit: BoxFit.contain,
                              errorWidget: (_, __, ___) =>
                                  _buildChannelFallback(),
                            ),
                          )
                        else
                          _buildChannelFallback(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentChannel.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Channel Stream • ${_currentChannel.containerExtension ?? "MPEGTS"}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.alarm_rounded,
                              color: AppColors.primary),
                          onPressed: () => RemindersDialog.show(context),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12, height: 1),
                    const SizedBox(height: 14),

                    // EPG Title
                    const Text(
                      'Programme Schedule',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // EPG Programmes
                    StreamBuilder<List<EpgProgramsTableData>>(
                      stream: scheduleStream,
                      builder: (context, snapshot) {
                        final programs = snapshot.data ?? [];
                        final now = DateTime.now().toUtc();

                        if (programs.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'No schedule data available for this channel.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          );
                        }

                        return Column(
                          children: programs.map((prog) {
                            final isLive = prog.start.isBefore(now) &&
                                prog.stop.isAfter(now);
                            final isUpcoming = prog.start.isAfter(now);

                            double progress = 0.0;
                            if (isLive) {
                              final total =
                                  prog.stop.difference(prog.start).inSeconds;
                              final elapsed =
                                  now.difference(prog.start).inSeconds;
                              if (total > 0) {
                                progress = (elapsed / total).clamp(0.0, 1.0);
                              }
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isLive
                                    ? AppColors.primary.withValues(alpha: 0.12)
                                    : Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isLive
                                      ? AppColors.primary.withValues(alpha: 0.5)
                                      : Colors.white.withValues(alpha: 0.06),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (isLive) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 2),
                                          margin:
                                              const EdgeInsets.only(right: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            borderRadius:
                                                BorderRadius.circular(3),
                                          ),
                                          child: const Text(
                                            'NOW',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                      Expanded(
                                        child: Text(
                                          prog.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: isLive
                                                ? FontWeight.bold
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
                                        ),
                                      ),
                                      if (isUpcoming) ...[
                                        const SizedBox(width: 4),
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
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
                                              channelName: _currentChannel.title,
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
                                    const SizedBox(height: 4),
                                    Text(
                                      prog.description!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.6),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                  if (isLive) ...[
                                    const SizedBox(height: 6),
                                    LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 2.5,
                                      backgroundColor: Colors.white12,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChannelFallback() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          _currentChannel.title.isNotEmpty
              ? _currentChannel.title[0].toUpperCase()
              : 'TV',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

