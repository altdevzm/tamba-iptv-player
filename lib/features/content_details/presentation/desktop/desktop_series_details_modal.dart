import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/persistence/app_database.dart';
import '../controllers/series_details_controller.dart';

class DesktopSeriesDetailsModal extends ConsumerWidget {
  final ContentItemsTableData series;

  const DesktopSeriesDetailsModal({super.key, required this.series});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(seriesDetailsProvider(series));
    final controller = ref.read(seriesDetailsProvider(series).notifier);

    final screenSize = MediaQuery.of(context).size;
    final modalWidth = (screenSize.width * 0.78).clamp(740.0, 1060.0);
    final modalMaxHeight = (screenSize.height * 0.90).clamp(520.0, 880.0);

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
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            width: modalWidth,
            constraints: BoxConstraints(maxHeight: modalMaxHeight),
            decoration: BoxDecoration(
              color: const Color(0xFF141416),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
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
                // ── Scrollable Body ──
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Large Cinematic Backdrop ──
                      Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 21 / 9,
                            child: state.displayBackdrop != null
                                ? CachedNetworkImage(
                                    imageUrl: state.displayBackdrop!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        _buildBackdropFallback(state.displayPoster),
                                  )
                                : _buildBackdropFallback(state.displayPoster),
                          ),

                          // Gradient Scrim
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Color(0x88141416),
                                    Color(0xFF141416),
                                  ],
                                  stops: [0.3, 0.75, 1.0],
                                ),
                              ),
                            ),
                          ),

                          // Title and Prominent Action Buttons over backdrop
                          Positioned(
                            left: 36,
                            right: 36,
                            bottom: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.displayTitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Action Buttons Row
                                Row(
                                  children: [
                                    // Watch First Episode / Watch Now
                                    ElevatedButton.icon(
                                      onPressed: () =>
                                          controller.playFirstAvailableEpisode(context),
                                      icon: const Icon(Icons.play_arrow_rounded,
                                          color: Colors.black, size: 26),
                                      label: const Text(
                                        'Watch Now',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 26, vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        elevation: 4,
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // Watch Trailer
                                    if (state.trailerUrl != null) ...[
                                      OutlinedButton.icon(
                                        onPressed: () => controller.watchTrailer(context),
                                        icon: const Icon(Icons.smart_display_rounded,
                                            color: Colors.amber, size: 20),
                                        label: const Text(
                                          'Watch Trailer',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.amber, width: 1.5),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                    ],

                                    // My List Button
                                    InkWell(
                                      onTap: () => controller.toggleFavorite(context),
                                      borderRadius: BorderRadius.circular(24),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: state.isFavorite
                                              ? AppColors.primary.withValues(alpha: 0.2)
                                              : Colors.white.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: state.isFavorite
                                                ? AppColors.primary
                                                : Colors.white.withValues(alpha: 0.2),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Icon(
                                          state.isFavorite
                                              ? Icons.bookmark_added_rounded
                                              : Icons.bookmark_add_outlined,
                                          color: state.isFavorite
                                              ? AppColors.primary
                                              : Colors.white,
                                          size: 20,
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

                      // ── Metadata, Synopsis & Creators ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(36, 12, 36, 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Column: Metadata & Synopsis
                            Expanded(
                              flex: 5,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Year, seasons, rating row
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      if (state.displayYear != null)
                                        Text(
                                          '${state.displayYear}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${state.seasonsCount} Season${state.seasonsCount > 1 ? "s" : ""}',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (state.displayRating != null && state.displayRating! > 0)
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.star_rounded,
                                                color: Colors.amber, size: 16),
                                            const SizedBox(width: 4),
                                            Text(
                                              state.displayRating!.toStringAsFixed(1),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      if (state.displayAgeRating != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: Colors.white38),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            state.displayAgeRating!,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      if (state.isLoadingTmdb || state.isLoadingEpisodes)
                                        const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Synopsis
                                  if (state.displayOverview != null &&
                                      state.displayOverview!.isNotEmpty)
                                    Text(
                                      state.displayOverview!,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 32),

                            // Right Column: Cast, Creators, Genres
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (state.cast.isNotEmpty) ...[
                                    RichText(
                                      text: TextSpan(
                                        children: [
                                          const TextSpan(
                                            text: 'Cast: ',
                                            style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: 13,
                                            ),
                                          ),
                                          TextSpan(
                                            text: state.cast.map((c) => c.name).take(5).join(', '),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],

                                  if (state.displayCreators.isNotEmpty) ...[
                                    RichText(
                                      text: TextSpan(
                                        children: [
                                          const TextSpan(
                                            text: 'Creators: ',
                                            style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: 13,
                                            ),
                                          ),
                                          TextSpan(
                                            text: state.displayCreators.join(', '),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],

                                  if (state.displayGenres.isNotEmpty) ...[
                                    RichText(
                                      text: TextSpan(
                                        children: [
                                          const TextSpan(
                                            text: 'Genres: ',
                                            style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: 13,
                                            ),
                                          ),
                                          TextSpan(
                                            text: state.displayGenres.join(', '),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 36),
                        child: Divider(color: Colors.white12),
                      ),

                      // ── Season & Episode Browsing ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(36, 16, 36, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Episodes',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (state.episodesBySeason.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: state.selectedSeason,
                                    dropdownColor: const Color(0xFF222228),
                                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                    items: state.episodesBySeason.keys.map((s) {
                                      return DropdownMenuItem<String>(
                                        value: s,
                                        child: Text('Season $s'),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) controller.selectSeason(val);
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Episodes List (Desktop Row Cards)
                      if (state.currentEpisodes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 36),
                          child: Column(
                            children: state.currentEpisodes.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final ep = entry.value;
                              final epTitle = ep['title']?.toString() ?? 'Episode ${idx + 1}';
                              final epNum = ep['episode_num']?.toString() ?? '${idx + 1}';
                              final epInfo = ep['info'] is Map ? ep['info'] as Map : null;
                              final rawImg = epInfo?['movie_image']?.toString() ??
                                  ep['movie_image']?.toString() ??
                                  epInfo?['cover']?.toString() ??
                                  ep['cover']?.toString() ??
                                  (epInfo?['still_path'] != null
                                      ? 'https://image.tmdb.org/t/p/w300${epInfo!['still_path']}'
                                      : null);
                              final epThumbnail =
                                  (rawImg != null && rawImg.startsWith('http')) ? rawImg : null;
                              final epDuration = epInfo?['duration']?.toString() ??
                                  (epInfo?['duration_secs'] != null
                                      ? '${((epInfo!['duration_secs'] as num) ~/ 60)} min'
                                      : null);
                              final epPlot = epInfo?['plot']?.toString() ??
                                  ep['plot']?.toString() ??
                                  epInfo?['description']?.toString();

                              return InkWell(
                                onTap: () => controller.playEpisode(context, ep, idx),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Large Widescreen Thumbnail with Play Overlay
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Stack(
                                          children: [
                                            Container(
                                              width: 140,
                                              height: 80,
                                              color: Colors.white12,
                                              child: epThumbnail != null
                                                  ? CachedNetworkImage(
                                                      imageUrl: epThumbnail,
                                                      fit: BoxFit.cover,
                                                      errorWidget: (_, __, ___) =>
                                                          _buildEpisodePlaceholder(epNum),
                                                    )
                                                  : _buildEpisodePlaceholder(epNum),
                                            ),
                                            Positioned.fill(
                                              child: Center(
                                                child: Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black.withValues(alpha: 0.55),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(Icons.play_arrow_rounded,
                                                      color: Colors.white, size: 22),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // Episode Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    '$epNum. $epTitle',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                                if (epDuration != null)
                                                  Text(
                                                    epDuration,
                                                    style: TextStyle(
                                                      color: Colors.white.withValues(alpha: 0.5),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            if (epPlot != null && epPlot.isNotEmpty) ...[
                                              const SizedBox(height: 6),
                                              Text(
                                                epPlot,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.7),
                                                  fontSize: 13,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
                          child: Center(
                            child: Text(
                              state.isLoadingEpisodes
                                  ? 'Loading episodes from provider...'
                                  : (state.fetchEpisodesError ??
                                      'No episodes found for this season.'),
                              style: TextStyle(
                                color: state.fetchEpisodesError != null
                                    ? Colors.redAccent
                                    : Colors.white38,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(height: 36),
                    ],
                  ),
                ),

                // ── Visible Floating Close Button in Top-Right ──
                Positioned(
                  top: 16,
                  right: 16,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF181818).withValues(alpha: 0.85),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
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

  Widget _buildBackdropFallback(String? poster) {
    if (poster != null) {
      return CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover);
    }
    return Container(color: const Color(0xFF1E1E24));
  }

  Widget _buildEpisodePlaceholder(String epNum) {
    return Center(
      child: Text(
        'EP $epNum',
        style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

