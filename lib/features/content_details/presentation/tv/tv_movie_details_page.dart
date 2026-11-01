import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/persistence/app_database.dart';
import '../../../../shared/services/tmdb_service.dart';
import '../controllers/movie_details_controller.dart';

class TvMovieDetailsPage extends ConsumerStatefulWidget {
  final ContentItemsTableData movie;

  const TvMovieDetailsPage({super.key, required this.movie});

  @override
  ConsumerState<TvMovieDetailsPage> createState() => _TvMovieDetailsPageState();
}

class _TvMovieDetailsPageState extends ConsumerState<TvMovieDetailsPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(movieDetailsProvider(widget.movie));
    final controller = ref.read(movieDetailsProvider(widget.movie).notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF09090C),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Cinematic Full-Screen Hero Backdrop ──
          if (state.displayBackdrop != null)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: state.displayBackdrop!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _buildBackdropFallback(state.displayPoster),
              ),
            )
          else
            _buildBackdropFallback(state.displayPoster),

          // ── Immersive TV Scrim Gradient (Left heavy for text readability) ──
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xFF09090C),
                    Color(0xEE09090C),
                    Color(0x9909090C),
                    Color(0x4409090C),
                  ],
                  stops: [0.0, 0.45, 0.75, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x6609090C),
                    Colors.transparent,
                    Color(0xFF09090C),
                  ],
                  stops: [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),

          // ── Scrollable TV Content ──
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button for D-pad navigation
                  _TvRemoteBackButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 20),

                  // Movie Title (Large, readable from 10 feet)
                  SizedBox(
                    width: 720,
                    child: Text(
                      state.displayTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                        height: 1.15,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Metadata Badges Row (Large for distance)
                  Wrap(
                    spacing: 14,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (state.displayYear != null)
                        Text(
                          '${state.displayYear}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (state.displayDuration != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            state.displayDuration!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (state.displayRating != null && state.displayRating! > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              state.displayRating!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      if (state.displayAgeRating != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white54, width: 1.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            state.displayAgeRating!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      if (state.displayGenres.isNotEmpty)
                        Text(
                          state.displayGenres.take(3).join(' • '),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Prominent D-Pad Action Controls ──
                  Row(
                    children: [
                      // Watch Now (Autofocused for immediate TV play)
                      _TvActionButton(
                        autofocus: true,
                        icon: Icons.play_arrow_rounded,
                        label: 'Watch Movie',
                        isPrimary: true,
                        onPressed: () => controller.playMovie(context),
                      ),
                      const SizedBox(width: 18),

                      // Watch Trailer
                      if (state.trailerUrl != null) ...[
                        _TvActionButton(
                          icon: Icons.smart_display_rounded,
                          label: 'Watch Trailer',
                          accentColor: Colors.amber,
                          onPressed: () => controller.watchTrailer(context),
                        ),
                        const SizedBox(width: 18),
                      ],

                      // Add to My List
                      _TvActionButton(
                        icon: state.isFavorite
                            ? Icons.bookmark_added_rounded
                            : Icons.bookmark_add_outlined,
                        label: state.isFavorite ? 'In My List' : 'Add to My List',
                        accentColor: state.isFavorite ? AppColors.primary : null,
                        onPressed: () => controller.toggleFavorite(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Synopsis (Readable size for 10-foot UI)
                  if (state.displayOverview != null && state.displayOverview!.isNotEmpty)
                    SizedBox(
                      width: 740,
                      child: Text(
                        state.displayOverview!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),

                  // Directors & Cast
                  if (state.displayDirectors.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Director: ${state.displayDirectors.join(", ")}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],

                  // ── Cast Row (D-Pad Navigable Avatars) ──
                  if (state.cast.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    const Text(
                      'Cast & Characters',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 130,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: state.cast.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 18),
                        itemBuilder: (context, idx) {
                          final actor = state.cast[idx];
                          return _TvCastCard(actor: actor);
                        },
                      ),
                    ),
                  ],

                  // ── Similar Movies (D-Pad Navigable) ──
                  if (state.recommendations.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    const Text(
                      'More Like This',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 190,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: state.recommendations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (context, idx) {
                          final rec = state.recommendations[idx];
                          return _TvRecommendationCard(rec: rec);
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackdropFallback(String? poster) {
    if (poster != null) {
      return CachedNetworkImage(imageUrl: poster, fit: BoxFit.cover);
    }
    return Container(color: const Color(0xFF0F0F14));
  }
}

class _TvRemoteBackButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _TvRemoteBackButton({required this.onPressed});

  @override
  State<_TvRemoteBackButton> createState() => _TvRemoteBackButtonState();
}

class _TvRemoteBackButtonState extends State<_TvRemoteBackButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onFocusChange: (f) => setState(() => _isFocused = f),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onPressed(),
        ),
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _isFocused ? Colors.white : Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.white24,
              width: _isFocused ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_back_rounded,
                color: _isFocused ? Colors.black : Colors.white,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Back',
                style: TextStyle(
                  color: _isFocused ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold,
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

class _TvActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool autofocus;
  final Color? accentColor;

  const _TvActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.autofocus = false,
    this.accentColor,
  });

  @override
  State<_TvActionButton> createState() => _TvActionButtonState();
}

class _TvActionButtonState extends State<_TvActionButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final activeBg = widget.isPrimary ? Colors.white : Colors.white.withValues(alpha: 0.15);
    final focusedBg = widget.isPrimary ? Colors.white : (widget.accentColor ?? AppColors.primary);

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
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.diagonal3Values(
            _isFocused ? 1.08 : 1.0,
            _isFocused ? 1.08 : 1.0,
            1.0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: _isFocused ? focusedBg : activeBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused ? Colors.white : Colors.white24,
              width: _isFocused ? 2.5 : 1,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: (widget.accentColor ?? AppColors.primary).withValues(alpha: 0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                color: _isFocused && widget.isPrimary
                    ? Colors.black
                    : (_isFocused ? Colors.white : (widget.isPrimary ? Colors.black : Colors.white)),
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                widget.label,
                style: TextStyle(
                  color: _isFocused && widget.isPrimary
                      ? Colors.black
                      : (_isFocused ? Colors.white : (widget.isPrimary ? Colors.black : Colors.white)),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvCastCard extends StatefulWidget {
  final TmdbCastItem actor;

  const _TvCastCard({required this.actor});

  @override
  State<_TvCastCard> createState() => _TvCastCardState();
}

class _TvCastCardState extends State<_TvCastCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final actor = widget.actor;

    return FocusableActionDetector(
      onFocusChange: (f) => setState(() => _isFocused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 88,
        transform: Matrix4.diagonal3Values(
          _isFocused ? 1.1 : 1.0,
          _isFocused ? 1.1 : 1.0,
          1.0,
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isFocused ? Colors.white : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white12,
                backgroundImage: actor.profileUrl != null
                    ? CachedNetworkImageProvider(actor.profileUrl!)
                    : null,
                child: actor.profileUrl == null
                    ? const Icon(Icons.person, color: Colors.white38, size: 28)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              actor.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isFocused ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: _isFocused ? FontWeight.bold : FontWeight.w600,
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
                  fontSize: 10,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TvRecommendationCard extends StatefulWidget {
  final TmdbRecommendation rec;

  const _TvRecommendationCard({required this.rec});

  @override
  State<_TvRecommendationCard> createState() => _TvRecommendationCardState();
}

class _TvRecommendationCardState extends State<_TvRecommendationCard> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final rec = widget.rec;

    return FocusableActionDetector(
      onFocusChange: (f) => setState(() => _isFocused = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.diagonal3Values(
          _isFocused ? 1.08 : 1.0,
          _isFocused ? 1.08 : 1.0,
          1.0,
        ),
        width: 115,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isFocused ? Colors.white : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.6),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: rec.posterUrl != null
                    ? CachedNetworkImage(
                        imageUrl: rec.posterUrl!,
                        width: 115,
                        height: 155,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 115,
                          height: 155,
                          color: Colors.white10,
                          child: const Icon(Icons.movie, color: Colors.white24),
                        ),
                      )
                    : Container(
                        width: 115,
                        height: 155,
                        color: Colors.white10,
                        child: const Icon(Icons.movie, color: Colors.white24),
                      ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              rec.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _isFocused ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: _isFocused ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
