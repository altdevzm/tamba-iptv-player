import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/theme/app_colors.dart';
import '../../../core/persistence/app_database.dart';
import '../../../core/persistence/database_provider.dart';
import '../../../shared/models/media_item.dart';
import '../../player/data/player_controller.dart';

final epgGridChannelsProvider = StreamProvider.autoDispose<List<ContentItemsTableData>>((ref) {
  final activePlaylistId = ref.watch(activePlaylistIdProvider);
  if (activePlaylistId == null) return Stream.value([]);
  final db = ref.watch(databaseProvider);
  return db.watchContentItems(activePlaylistId, 'live');
});

class EpgGridView extends ConsumerStatefulWidget {
  const EpgGridView({super.key});

  @override
  ConsumerState<EpgGridView> createState() => _EpgGridViewState();
}

class _EpgGridViewState extends ConsumerState<EpgGridView> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _channelListController = ScrollController();
  final ScrollController _programmesListController = ScrollController();
  bool _isSyncingScroll = false;

  static const double _pixelsPerMinute = 4.0;
  static const int _windowHours = 6;
  static const double _channelColWidth = 180.0;
  static const double _rowHeight = 52.0;

  late DateTime _gridStartTime;

  double get _totalTimelineWidth => _windowHours * 60 * _pixelsPerMinute;

  @override
  void initState() {
    super.initState();
    _gridStartTime = DateTime.now().toUtc();

    _channelListController.addListener(_onChannelListScrolled);
    _programmesListController.addListener(_onProgrammesListScrolled);

    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToNow());
  }

  void _onChannelListScrolled() {
    if (_isSyncingScroll) return;
    _isSyncingScroll = true;
    if (_programmesListController.hasClients &&
        _programmesListController.offset != _channelListController.offset) {
      _programmesListController.jumpTo(_channelListController.offset);
    }
    _isSyncingScroll = false;
  }

  void _onProgrammesListScrolled() {
    if (_isSyncingScroll) return;
    _isSyncingScroll = true;
    if (_channelListController.hasClients &&
        _channelListController.offset != _programmesListController.offset) {
      _channelListController.jumpTo(_programmesListController.offset);
    }
    _isSyncingScroll = false;
  }

  void _jumpToNow() {
    final now = DateTime.now().toUtc();
    final diffMinutes = now.difference(_gridStartTime).inMinutes;
    final targetOffset = (diffMinutes * _pixelsPerMinute) - 120;
    if (_horizontalController.hasClients) {
      _horizontalController.animateTo(
        targetOffset.clamp(0.0, _horizontalController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _channelListController.removeListener(_onChannelListScrolled);
    _programmesListController.removeListener(_onProgrammesListScrolled);
    _horizontalController.dispose();
    _channelListController.dispose();
    _programmesListController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(epgGridChannelsProvider);
    final db = ref.watch(databaseProvider);
    final timeFormat = DateFormat('HH:mm');
    final now = DateTime.now().toUtc();
    final nowOffset = now.difference(_gridStartTime).inMinutes * _pixelsPerMinute;

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 14 : 28,
          vertical: isMobile ? 12 : 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live TV Guide (EPG)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Currently airing and upcoming programmes',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: isMobile ? 11 : 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _jumpToNow,
                  icon: const Icon(Icons.my_location_rounded, size: 16),
                  label: Text(isMobile ? 'Now' : 'Jump to Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 10 : 16,
                      vertical: isMobile ? 8 : 12,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // 2D Matrix Grid Area
            Expanded(
              child: channelsAsync.when(
                data: (channels) {
                  if (channels.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tv_off_rounded, size: 64, color: Colors.white.withValues(alpha: 0.2)),
                          const SizedBox(height: 16),
                          const Text('No live channels available in this playlist', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Row(
                        children: [
                          // Left Column: Channels
                          SizedBox(
                            width: _channelColWidth,
                            child: Column(
                              children: [
                                // Corner Header
                                Container(
                                  height: 38,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  color: Colors.white.withValues(alpha: 0.04),
                                  alignment: Alignment.centerLeft,
                                  child: const Text(
                                    'Channel',
                                    style: TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const Divider(height: 1, color: Colors.white12),
                                // Channel Titles List
                                Expanded(
                                  child: ListView.separated(
                                    controller: _channelListController,
                                    itemCount: channels.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                                    itemBuilder: (context, index) {
                                      final ch = channels[index];
                                      return SizedBox(
                                        height: _rowHeight,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          color: Colors.white.withValues(alpha: 0.02),
                                          child: Row(
                                            children: [
                                              if (ch.posterUrl != null && ch.posterUrl!.isNotEmpty)
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(4),
                                                  child: Image.network(
                                                    ch.posterUrl!,
                                                    width: 26,
                                                    height: 26,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (_, __, ___) => const Icon(Icons.tv, size: 18, color: Colors.white38),
                                                  ),
                                                )
                                              else
                                                const Icon(Icons.tv, size: 18, color: Colors.white38),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  ch.title,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const VerticalDivider(width: 1, color: Colors.white12),

                          // Right Area: Schedule Grid with synchronized horizontal scroll
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _horizontalController,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: _totalTimelineWidth,
                                child: Column(
                                  children: [
                                    // Time slots header ruler
                                    SizedBox(
                                      height: 38,
                                      child: Stack(
                                        children: [
                                          Row(
                                            children: List.generate(_windowHours * 2, (idx) {
                                              final slotTime = _gridStartTime.add(Duration(minutes: idx * 30));
                                              return Container(
                                                width: 30 * _pixelsPerMinute,
                                                padding: const EdgeInsets.only(left: 8, top: 10),
                                                decoration: BoxDecoration(
                                                  border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                                                ),
                                                child: Text(
                                                  timeFormat.format(slotTime.toLocal()),
                                                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                              );
                                            }),
                                          ),
                                          // "Now" marker on header
                                          if (nowOffset >= 0 && nowOffset <= _totalTimelineWidth)
                                            Positioned(
                                              left: nowOffset - 1,
                                              top: 0,
                                              bottom: 0,
                                              child: Container(
                                                width: 2,
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const Divider(height: 1, color: Colors.white12),

                                    // Channels programme tracks
                                    Expanded(
                                      child: Stack(
                                        children: [
                                          ListView.separated(
                                            controller: _programmesListController,
                                            itemCount: channels.length,
                                            separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                                            itemBuilder: (context, index) {
                                              final ch = channels[index];
                                              return _EpgProgrammeTrackRow(
                                                channel: ch,
                                                db: db,
                                                gridStartTime: _gridStartTime,
                                                pixelsPerMinute: _pixelsPerMinute,
                                                windowHours: _windowHours,
                                                rowHeight: _rowHeight,
                                                totalWidth: _totalTimelineWidth,
                                              );
                                            },
                                          ),
                                          // "Now" red vertical indicator line spanning all channel rows
                                          if (nowOffset >= 0 && nowOffset <= _totalTimelineWidth)
                                            Positioned(
                                              left: nowOffset - 1,
                                              top: 0,
                                              bottom: 0,
                                              child: IgnorePointer(
                                                child: Container(
                                                  width: 2,
                                                  color: Colors.redAccent.withValues(alpha: 0.75),
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
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.redAccent))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EpgProgrammeTrackRow extends StatelessWidget {
  final ContentItemsTableData channel;
  final AppDatabase db;
  final DateTime gridStartTime;
  final double pixelsPerMinute;
  final int windowHours;
  final double rowHeight;
  final double totalWidth;

  const _EpgProgrammeTrackRow({
    required this.channel,
    required this.db,
    required this.gridStartTime,
    required this.pixelsPerMinute,
    required this.windowHours,
    required this.rowHeight,
    required this.totalWidth,
  });

  @override
  Widget build(BuildContext context) {
    final epgId = channel.epgChannelId;

    if (epgId == null || epgId.isEmpty) {
      return SizedBox(
        height: rowHeight,
        child: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 14),
          child: const Text('No EPG Guide Available', style: TextStyle(color: Colors.white24, fontSize: 11)),
        ),
      );
    }

    final gridEndTime = gridStartTime.add(Duration(hours: windowHours));

    return SizedBox(
      height: rowHeight,
      child: FutureBuilder<List<EpgProgramsTableData>>(
        future: (db.select(db.epgProgramsTable)
              ..where((t) => t.channelId.equals(epgId))
              ..where((t) => t.stop.isBiggerThanValue(gridStartTime))
              ..where((t) => t.start.isSmallerThanValue(gridEndTime))
              ..orderBy([(t) => drift.OrderingTerm(expression: t.start)]))
            .get(),
        builder: (context, snapshot) {
          final progs = snapshot.data ?? [];
          if (progs.isEmpty) {
            return Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 14),
              child: const Text('Regular Programming', style: TextStyle(color: Colors.white30, fontSize: 11)),
            );
          }

          final nowUtc = DateTime.now().toUtc();

          return Stack(
            children: progs.map((p) {
              final effStart = p.start.isBefore(gridStartTime) ? gridStartTime : p.start;
              final effStop = p.stop.isAfter(gridEndTime) ? gridEndTime : p.stop;
              final startDiff = effStart.difference(gridStartTime).inMinutes;
              final durDiff = effStop.difference(effStart).inMinutes;

              final left = (startDiff * pixelsPerMinute).clamp(0.0, totalWidth);
              final width = (durDiff * pixelsPerMinute).clamp(16.0, totalWidth);
              final isNow = nowUtc.isAfter(p.start) && nowUtc.isBefore(p.stop);

              return Positioned(
                left: left,
                width: width,
                top: 4,
                bottom: 4,
                child: Consumer(
                  builder: (ctx, ref, _) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        if (channel.streamUrl != null) {
                          final item = MediaItem(
                            id: channel.providerId,
                            title: channel.title,
                            type: MediaType.live,
                            posterUrl: channel.posterUrl,
                            streamUrl: channel.streamUrl,
                            playlistId: channel.playlistId,
                            providerId: channel.providerId,
                            contentDbId: channel.id,
                          );
                          ref.read(playerControllerProvider.notifier).playItem(item, startFullscreen: true);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isNow ? AppColors.primary.withValues(alpha: 0.28) : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isNow ? AppColors.primary.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              p.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isNow ? Colors.white : Colors.white70,
                                fontSize: 11.5,
                                fontWeight: isNow ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                            if (p.category != null && p.category!.isNotEmpty)
                              Text(
                                p.category!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 9.5),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
