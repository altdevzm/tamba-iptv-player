import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/persistence/app_database.dart';
import '../controllers/series_details_controller.dart';

class MobileSeriesDetailsSheet extends ConsumerWidget {
  final ContentItemsTableData series;

  const MobileSeriesDetailsSheet({super.key, required this.series});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(seriesDetailsProvider(series));
    final controller = ref.read(seriesDetailsProvider(series).notifier);

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      snap: true,
      snapSizes: const [0.72, 0.94],
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF141416),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 24,
                offset: Offset(0, -6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              // ── Drag Handle ──
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),

              // ── Backdrop Header ──
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: state.displayBackdrop != null
                        ? CachedNetworkImage(
                            imageUrl: state.displayBackdrop!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _buildBackdropFallback(state.displayPoster),
                          )
                        : _buildBackdropFallback(state.displayPoster),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Color(0x99141416),
                            Color(0xFF141416),
                          ],
                          stops: [0.3, 0.75, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Close button
                  Positioned(
                    top: 12,
                    right: 14,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),

                  // Title & Meta inside Backdrop Bottom
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (state.displayYear != null)
                              Text(
                                '${state.displayYear}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.65),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${state.seasonsCount} Season${state.seasonsCount > 1 ? "s" : ""}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (state.displayRating != null && state.displayRating! > 0)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                                  const SizedBox(width: 3),
                                  Text(
                                    state.displayRating!.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            if (state.displayAgeRating != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.white38),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  state.displayAgeRating!,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            if (state.isLoadingTmdb || state.isLoadingEpisodes)
                              const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Action Buttons ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: () => controller.playFirstAvailableEpisode(context),
                        icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 24),
                        label: const Text(
                          'Watch Now',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    if (state.trailerUrl != null) ...[
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: () => controller.watchTrailer(context),
                          icon: const Icon(Icons.smart_display_rounded, color: Colors.amber, size: 18),
                          label: const Text(
                            'Trailer',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.amber),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],

                    InkWell(
                      onTap: () => controller.toggleFavorite(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: state.isFavorite
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: state.isFavorite
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Icon(
                          state.isFavorite
                              ? Icons.bookmark_added_rounded
                              : Icons.bookmark_add_outlined,
                          color: state.isFavorite ? AppColors.primary : Colors.white70,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Genres ──
              if (state.displayGenres.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: state.displayGenres.map((g) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          g,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11.5,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // ── Synopsis ──
              if (state.displayOverview != null && state.displayOverview!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.displayOverview!,
                        maxLines: state.isSynopsisExpanded ? null : 3,
                        overflow: state.isSynopsisExpanded ? null : TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: controller.toggleSynopsis,
                        child: Text(
                          state.isSynopsisExpanded ? 'Show less' : 'Read more',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Cast ──
              if (state.cast.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 12, 18, 8),
                  child: Text(
                    'Cast & Creators',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  height: 95,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    itemCount: state.cast.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, idx) {
                      final actor = state.cast[idx];
                      return SizedBox(
                        width: 70,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Colors.white12,
                              backgroundImage: actor.profileUrl != null
                                  ? CachedNetworkImageProvider(actor.profileUrl!)
                                  : null,
                              child: actor.profileUrl == null
                                  ? const Icon(Icons.person, color: Colors.white38, size: 20)
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              actor.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Divider(color: Colors.white12),
              ),

              // ── Season Selector ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Episodes',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (state.episodesBySeason.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
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
              const SizedBox(height: 8),

              // ── Episodes List ──
              if (state.currentEpisodes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
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
                          (epInfo?['still_path'] != null ? 'https://image.tmdb.org/t/p/w300${epInfo!['still_path']}' : null);
                      final epThumbnail = (rawImg != null && rawImg.startsWith('http')) ? rawImg : null;
                      final epDuration = epInfo?['duration']?.toString() ??
                          (epInfo?['duration_secs'] != null ? '${((epInfo!['duration_secs'] as num) ~/ 60)} min' : null);

                      return InkWell(
                        onTap: () => controller.playEpisode(context, ep, idx),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 58,
                                      color: Colors.white12,
                                      child: epThumbnail != null
                                          ? CachedNetworkImage(
                                              imageUrl: epThumbnail,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) => _buildEpisodePlaceholder(epNum),
                                            )
                                          : _buildEpisodePlaceholder(epNum),
                                    ),
                                    Positioned.fill(
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.5),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$epNum. $epTitle',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (epDuration != null) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        epDuration,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          fontSize: 11,
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
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
                  child: Center(
                    child: Text(
                      state.isLoadingEpisodes
                          ? 'Loading episodes from provider...'
                          : (state.fetchEpisodesError ?? 'No episodes available for this season.'),
                      style: TextStyle(
                        color: state.fetchEpisodesError != null ? Colors.redAccent : Colors.white38,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 36),
            ],
          ),
        );
      },
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
        style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

