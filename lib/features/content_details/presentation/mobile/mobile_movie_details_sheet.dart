import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/persistence/app_database.dart';
import '../controllers/movie_details_controller.dart';

class MobileMovieDetailsSheet extends ConsumerWidget {
  final ContentItemsTableData movie;

  const MobileMovieDetailsSheet({super.key, required this.movie});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(movieDetailsProvider(movie));
    final controller = ref.read(movieDetailsProvider(movie).notifier);

    return DraggableScrollableSheet(
      initialChildSize: 0.68,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      snap: true,
      snapSizes: const [0.68, 0.94],
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

              // ── Cinematic Backdrop Header ──
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
                            if (state.displayDuration != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  state.displayDuration!,
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
                            if (state.isLoadingTmdb || state.isLoadingVod)
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

              // ── Touch-Friendly Action Buttons ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  children: [
                    // Play Movie Button
                    Expanded(
                      flex: 3,
                      child: ElevatedButton.icon(
                        onPressed: () => controller.playMovie(context),
                        icon: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 24),
                        label: const Text(
                          'Watch Movie',
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

                    // Trailer Button
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

                    // Bookmark / My List
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
                    const SizedBox(width: 10),

                    // Download Button
                    if (movie.streamUrl != null && movie.streamUrl!.isNotEmpty)
                      InkWell(
                        onTap: () => controller.downloadMovie(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: const Icon(Icons.download_rounded, color: Colors.white70, size: 22),
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

              // ── Synopsis (Expandable on Touch) ──
              if (state.displayOverview != null && state.displayOverview!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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

              // ── Directors ──
              if (state.displayDirectors.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  child: Text(
                    'Director: ${state.displayDirectors.join(", ")}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ),

              // ── Cast Section ──
              if (state.cast.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 10),
                  child: Text(
                    'Cast & Crew',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  height: 105,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    itemCount: state.cast.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, idx) {
                      final actor = state.cast[idx];
                      return SizedBox(
                        width: 72,
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.white12,
                              backgroundImage: actor.profileUrl != null
                                  ? CachedNetworkImageProvider(actor.profileUrl!)
                                  : null,
                              child: actor.profileUrl == null
                                  ? const Icon(Icons.person, color: Colors.white38, size: 22)
                                  : null,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              actor.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (actor.character != null)
                              Text(
                                actor.character!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 9.5,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ] else if (state.displayCastNames.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  child: Text(
                    'Cast: ${state.displayCastNames.take(8).join(", ")}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],

              // ── Similar Movies ──
              if (state.recommendations.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 10),
                  child: Text(
                    'More Like This',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(
                  height: 140,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    itemCount: state.recommendations.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (context, idx) {
                      final rec = state.recommendations[idx];
                      return SizedBox(
                        width: 90,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: rec.posterUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: rec.posterUrl!,
                                      width: 90,
                                      height: 115,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        width: 90,
                                        height: 115,
                                        color: Colors.white10,
                                        child: const Icon(Icons.movie, color: Colors.white24),
                                      ),
                                    )
                                  : Container(
                                      width: 90,
                                      height: 115,
                                      color: Colors.white10,
                                      child: const Icon(Icons.movie, color: Colors.white24),
                                    ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              rec.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],

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
}

