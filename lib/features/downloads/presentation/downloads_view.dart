import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/media_item.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../player/data/player_controller.dart';
import '../data/download_service.dart';

class DownloadsView extends ConsumerWidget {
  const DownloadsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.watch(downloadNotifierProvider);
    final player = ref.read(playerControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'Downloads & Offline Storage',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Manage your downloaded movies and episodes for offline viewing',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 28),

            // Downloads List
            Expanded(
              child: downloads.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.download_done_rounded,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No Offline Downloads',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You can download movies and episodes from their details sheet to watch without an internet connection.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: downloads.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final task = downloads[index];
                        final isCompleted =
                            task.status == DownloadStatus.completed;
                        final mbDownloaded =
                            (task.bytesDownloaded / (1024 * 1024))
                                .toStringAsFixed(1);
                        final mbTotal =
                            (task.totalBytes / (1024 * 1024)).toStringAsFixed(1);

                        return GlassContainer(
                          padding: const EdgeInsets.all(16),
                          borderRadius: 14,
                          child: Row(
                            children: [
                              // Poster or Icon
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: task.posterUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: task.posterUrl!,
                                        width: 48,
                                        height: 68,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            _buildIcon(),
                                      )
                                    : _buildIcon(),
                              ),
                              const SizedBox(width: 16),

                              // Info & Progress
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            task.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        _buildStatusBadge(task.status),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    if (task.status ==
                                        DownloadStatus.downloading) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: LinearProgressIndicator(
                                          value: task.progress,
                                          backgroundColor: Colors.white
                                              .withValues(alpha: 0.1),
                                          valueColor:
                                              const AlwaysStoppedAnimation<Color>(
                                                  AppColors.primary),
                                          minHeight: 4,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '$mbDownloaded MB of $mbTotal MB (${(task.progress * 100).toStringAsFixed(0)}%)',
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.5),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ] else if (isCompleted) ...[
                                      Text(
                                        'Ready for offline playback • $mbTotal MB',
                                        style: TextStyle(
                                          color: Colors.green
                                              .withValues(alpha: 0.8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Actions
                              if (isCompleted)
                                ElevatedButton.icon(
                                  onPressed: () {
                                    final item = MediaItem(
                                      id: task.id,
                                      title: task.title,
                                      type: MediaType.movie,
                                      posterUrl: task.posterUrl,
                                      streamUrl: task.filePath,
                                    );
                                    player.playItem(item,
                                        startFullscreen: true);
                                  },
                                  icon: const Icon(Icons.play_arrow_rounded,
                                      size: 18),
                                  label: const Text('Play'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),

                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded,
                                    color: Colors.white54, size: 20),
                                onPressed: () {
                                  ref
                                      .read(downloadNotifierProvider.notifier)
                                      .deleteDownload(task.id);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 48,
      height: 68,
      color: Colors.white12,
      child: const Icon(Icons.movie_rounded, color: Colors.white38),
    );
  }

  Widget _buildStatusBadge(DownloadStatus status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case DownloadStatus.downloading:
        bg = Colors.blue.withValues(alpha: 0.2);
        fg = Colors.lightBlueAccent;
        label = 'DOWNLOADING';
        break;
      case DownloadStatus.completed:
        bg = Colors.green.withValues(alpha: 0.2);
        fg = Colors.greenAccent;
        label = 'COMPLETED';
        break;
      case DownloadStatus.paused:
        bg = Colors.orange.withValues(alpha: 0.2);
        fg = Colors.orangeAccent;
        label = 'PAUSED';
        break;
      case DownloadStatus.failed:
        bg = Colors.red.withValues(alpha: 0.2);
        fg = Colors.redAccent;
        label = 'FAILED';
        break;
      case DownloadStatus.pending:
        bg = Colors.grey.withValues(alpha: 0.2);
        fg = Colors.white70;
        label = 'PENDING';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

