import 'dart:async';
import 'package:flutter/material.dart';
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

class TvLiveTvPreviewPage extends ConsumerStatefulWidget {
  final ContentItemsTableData channel;

  const TvLiveTvPreviewPage({super.key, required this.channel});

  @override
  ConsumerState<TvLiveTvPreviewPage> createState() =>
      _TvLiveTvPreviewPageState();
}

class _TvLiveTvPreviewPageState extends ConsumerState<TvLiveTvPreviewPage> {
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

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D12),
      body: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left: TV Preview Player & Remote Action Controls
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Channel Title & Logo
                  Row(
                    children: [
                      if (_currentChannel.posterUrl != null &&
                          _currentChannel.posterUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: _currentChannel.posterUrl!,
                            width: 52,
                            height: 52,
                            fit: BoxFit.contain,
                            errorWidget: (_, __, ___) => _buildFallback(),
                          ),
                        )
                      else
                        _buildFallback(),
                      const SizedBox(width: 14),
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
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Row(
                              children: [
                                Icon(Icons.circle,
                                    size: 8, color: Colors.redAccent),
                                SizedBox(width: 5),
                                Text(
                                  'LIVE BROADCAST',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // TV 16:9 Video surface
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      clipBehavior: Clip.antiAlias,
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
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // D-pad Action Buttons
                  Row(
                    children: [
                      // Watch Full Screen (Autofocused for TV)
                      _TvButton(
                        autofocus: true,
                        icon: Icons.fullscreen_rounded,
                        label: 'Watch Fullscreen',
                        isPrimary: true,
                        onPressed: _watchFullScreen,
                      ),
                      const SizedBox(width: 12),
                      // Previous Channel
                      _TvButton(
                        icon: Icons.skip_previous_rounded,
                        label: 'Prev Channel',
                        onPressed: () => _changeChannelDelta(-1),
                      ),
                      const SizedBox(width: 12),
                      // Next Channel
                      _TvButton(
                        icon: Icons.skip_next_rounded,
                        label: 'Next Channel',
                        onPressed: () => _changeChannelDelta(1),
                      ),
                      const SizedBox(width: 12),
                      // Back
                      _TvButton(
                        icon: Icons.arrow_back_rounded,
                        label: 'Back',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 28),

            // Right: EPG Programme Guide
            Expanded(
              flex: 5,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF14141A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Electronic Programme Guide (EPG)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),

                    Expanded(
                      child: StreamBuilder<List<EpgProgramsTableData>>(
                        stream: scheduleStream,
                        builder: (context, snapshot) {
                          final programs = snapshot.data ?? [];
                          final now = DateTime.now().toUtc();

                          if (programs.isEmpty) {
                            return const Center(
                              child: Text(
                                'No EPG schedule available for this channel.',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 13),
                              ),
                            );
                          }

                          return ListView.separated(
                            itemCount: programs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, idx) {
                              final prog = programs[idx];
                              final isLive = prog.start.isBefore(now) &&
                                  prog.stop.isAfter(now);
                              final isUpcoming = prog.start.isAfter(now);

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isLive
                                      ? AppColors.primary
                                          .withValues(alpha: 0.15)
                                      : Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isLive
                                        ? AppColors.primary
                                        : Colors.white.withValues(alpha: 0.08),
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
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            margin: const EdgeInsets.only(
                                                right: 8),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'NOW',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
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
                                              fontSize: 14,
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
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (isUpcoming) ...[
                                          const SizedBox(width: 8),
                                          IconButton(
                                            tooltip: 'Set Reminder',
                                            padding: EdgeInsets.zero,
                                            constraints:
                                                const BoxConstraints(),
                                            icon: const Icon(
                                              Icons.alarm_add_rounded,
                                              color: AppColors.primary,
                                              size: 20,
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
                                      const SizedBox(height: 6),
                                      Text(
                                        prog.description!,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.65),
                                          fontSize: 12,
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
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: 52,
      height: 52,
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
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}

class _TvButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool autofocus;

  const _TvButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.autofocus = false,
  });

  @override
  State<_TvButton> createState() => _TvButtonState();
}

class _TvButtonState extends State<_TvButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isPrimary
        ? (_isFocused ? Colors.white : AppColors.primary)
        : (_isFocused ? Colors.white : Colors.white.withValues(alpha: 0.08));
    final fg = widget.isPrimary
        ? (_isFocused ? Colors.black : Colors.white)
        : (_isFocused ? Colors.black : Colors.white);

    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onFocusChange: (f) => setState(() => _isFocused = f),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onPressed(),
        ),
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.transparent,
              width: 2,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
