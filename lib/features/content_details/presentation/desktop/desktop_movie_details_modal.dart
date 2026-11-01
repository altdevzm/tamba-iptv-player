import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/persistence/app_database.dart';
import '../controllers/movie_details_controller.dart';

class DesktopMovieDetailsModal extends ConsumerWidget {
  final ContentItemsTableData movie;

  const DesktopMovieDetailsModal({super.key, required this.movie});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(movieDetailsProvider(movie));
    final controller = ref.read(movieDetailsProvider(movie).notifier);

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
                                    // Watch Now
                                    ElevatedButton.icon(
                                      onPressed: () => controller.playMovie(context),
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
                                    const SizedBox(width: 12),

                                    // Download Button
                                    if (movie.streamUrl != null && movie.streamUrl!.isNotEmpty)
                                      InkWell(
                                        onTap: () => controller.downloadMovie(context),
                                        borderRadius: BorderRadius.circular(24),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.2),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.download_rounded,
                                            color: Colors.white,
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

                      // ── Metadata, Synopsis & Cast ──
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
                                  // Year, duration, rating row
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
                                      if (state.displayDuration != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            state.displayDuration!,
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
                                      if (state.isLoadingTmdb || state.isLoadingVod)
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

                            // Right Column: Cast, Director, Genres
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (state.displayCastNames.isNotEmpty) ...[
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
                                            text: state.displayCastNames.take(5).join(', '),
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

                                  if (state.displayDirectors.isNotEmpty) ...[
                                    RichText(
                                      text: TextSpan(
                                        children: [
                                          const TextSpan(
                                            text: 'Director: ',
                                            style: TextStyle(
                                              color: Colors.white54,
                                              fontSize: 13,
                                            ),
                                          ),
                                          TextSpan(
                                            text: state.displayDirectors.join(', '),
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

                      // ── Cast Row (Avatars) ──
                      if (state.cast.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 36),
                          child: Text(
                            'Cast & Crew',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 110,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 36),
                            itemCount: state.cast.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 16),
                            itemBuilder: (context, idx) {
                              final actor = state.cast[idx];
                              return SizedBox(
                                width: 80,
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: Colors.white12,
                                      backgroundImage: actor.profileUrl != null
                                          ? CachedNetworkImageProvider(actor.profileUrl!)
                                          : null,
                                      child: actor.profileUrl == null
                                          ? const Icon(Icons.person, color: Colors.white38)
                                          : null,
                                    ),
                                    const SizedBox(height: 6),
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
                      ],

                      // ── More Like This (Recommendations) ──
                      if (state.recommendations.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 36),
                          child: Text(
                            'More Like This',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          height: 170,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 36),
                            itemCount: state.recommendations.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 14),
                            itemBuilder: (context, idx) {
                              final rec = state.recommendations[idx];
                              return SizedBox(
                                width: 105,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: rec.posterUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl: rec.posterUrl!,
                                              width: 105,
                                              height: 140,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) => Container(
                                                width: 105,
                                                height: 140,
                                                color: Colors.white10,
                                                child: const Icon(Icons.movie,
                                                    color: Colors.white24),
                                              ),
                                            )
                                          : Container(
                                              width: 105,
                                              height: 140,
                                              color: Colors.white10,
                                              child: const Icon(Icons.movie,
                                                  color: Colors.white24),
                                            ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      rec.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 11.5),
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
}

