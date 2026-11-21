import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/media_item.dart';
import '../../../../shared/services/tmdb_service.dart';

class FlixorHeroSpotlight extends ConsumerStatefulWidget {
  final MediaItem item;
  final VoidCallback onPlay;
  final VoidCallback? onToggleMyList;
  final bool isFavorite;
  final void Function(String trailerUrl, String trailerTitle)? onPlayTrailer;
  final VoidCallback? onMoreInfo;

  const FlixorHeroSpotlight({
    super.key,
    required this.item,
    required this.onPlay,
    this.onToggleMyList,
    this.isFavorite = false,
    this.onPlayTrailer,
    this.onMoreInfo,
  });

  @override
  ConsumerState<FlixorHeroSpotlight> createState() =>
      _FlixorHeroSpotlightState();
}

class _FlixorHeroSpotlightState extends ConsumerState<FlixorHeroSpotlight> {
  TmdbMetadata? _tmdb;

  @override
  void initState() {
    super.initState();
    _fetchEnrichment(widget.item);
  }

  @override
  void didUpdateWidget(covariant FlixorHeroSpotlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.title != widget.item.title) {
      _fetchEnrichment(widget.item);
    }
  }

  Future<void> _fetchEnrichment(MediaItem item) async {
    if (mounted) {
      setState(() => _tmdb = null);
    }

    final tmdbService = ref.read(tmdbServiceProvider);
    final cleanTitle = _cleanTitle(item.title);
    final year = item.releaseYear ?? _extractYear(item.title);

    try {
      TmdbMetadata? data;
      if (item.type == MediaType.series) {
        data = await tmdbService.searchSeries(cleanTitle);
      } else if (item.type == MediaType.movie) {
        data = await tmdbService.searchMovie(cleanTitle, year: year);
      }

      if (mounted && data != null) {
        setState(() => _tmdb = data);
      }
    } catch (_) {}
  }

  String _cleanTitle(String raw) {
    var title = raw.trim().replaceFirst(
          RegExp(r'^(?:watch\s+)?[a-z]{2,4}\s*[-:]\s*', caseSensitive: false),
          '',
        );
    title = title.replaceAll(RegExp(r'\[[^\]]*\]'), ' ');
    title = title.replaceAll(
      RegExp(r'\((HQ|LQ|4K|1080p|720p)\)', caseSensitive: false),
      '',
    );
    title = title.replaceFirst(
      RegExp(r'\s*(?:-|:)\s*S\d{1,2}\s*E\d{1,3}\b.*$', caseSensitive: false),
      '',
    );
    title = title.replaceAll(RegExp(r'\(\d{4}\)'), '');
    return title.trim().isNotEmpty ? title.trim() : raw;
  }

  int? _extractYear(String raw) {
    final match = RegExp(r'\((\d{4})\)').firstMatch(raw);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isMobile = size.width < 768;
    final isCompactMobile = size.width < 380;
    final item = widget.item;

    final displayTitle = _cleanTitle(item.title);
    final backdropUrl = _tmdb?.backdropUrl ??
        (item.backdropUrl != null && item.backdropUrl!.isNotEmpty
            ? item.backdropUrl
            : (item.posterUrl != null && item.posterUrl!.isNotEmpty
                ? item.posterUrl
                : null));

    final overview = _tmdb?.overview?.trim() ?? '';
    final year =
        _tmdb?.releaseYear ?? item.releaseYear ?? _extractYear(item.title);
    final rating = _tmdb?.rating ?? item.rating;
    final ageRating = _tmdb?.ageRating;
    final genres =
        _tmdb?.genres.take(2).toList() ?? item.genres.take(2).toList();
    final videos = _tmdb?.videos ?? [];

    final categoryLabel = switch (item.type) {
      MediaType.series || MediaType.episode => 'SERIES',
      MediaType.live => 'LIVE TV',
      MediaType.movie => 'MOVIE',
    };

    final double heroHeight;
    if (isMobile) {
      final proportional = size.height * 0.54;
      heroHeight = proportional.clamp(340.0, 470.0);
    } else {
      heroHeight = videos.isNotEmpty ? 540.0 : 480.0;
    }

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full-bleed artwork
          if (backdropUrl != null && backdropUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: backdropUrl,
              httpHeaders: const {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              },
              fit: BoxFit.cover,
              alignment: const Alignment(0, -0.25),
              errorWidget: (_, __, ___) => _buildFallbackBackdrop(),
            )
          else
            _buildFallbackBackdrop(),

          // 2. Cinematic bottom & top scrims
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.background.withValues(alpha: 0.45),
                  Colors.transparent,
                  AppColors.background.withValues(alpha: 0.72),
                  AppColors.background,
                ],
                stops: const [0.0, 0.35, 0.78, 1.0],
              ),
            ),
          ),

          if (!isMobile)
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.background.withValues(alpha: 0.88),
                    AppColors.background.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.42, 0.75],
                ),
              ),
            ),

          // 3. Content overlay
          Positioned(
            left: isMobile ? 16 : 32,
            right: isMobile ? 16 : 32,
            bottom: isMobile ? 16 : 24,
            child: Column(
              crossAxisAlignment: isMobile
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Category pill
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        categoryLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    if (year != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '$year',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (rating != null && rating > 0) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.accentAmber,
                        size: 14,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (ageRating != null && ageRating.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          ageRating,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                // Title
                Text(
                  displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: isMobile ? TextAlign.center : TextAlign.left,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isCompactMobile ? 22 : (isMobile ? 26 : 36),
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                    letterSpacing: -0.4,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.85),
                        blurRadius: 16,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),

                if (genres.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    genres.join('  •  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                if (overview.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isMobile ? 420 : 580,
                    ),
                    child: Text(
                      overview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: isMobile ? TextAlign.center : TextAlign.left,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 14),

                // Action buttons
                if (isMobile)
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: widget.onPlay,
                            icon: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.black,
                              size: 24,
                            ),
                            label: const Text(
                              'Play',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: widget.onToggleMyList,
                            icon: Icon(
                              widget.isFavorite
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            label: Text(
                              widget.isFavorite ? 'In My List' : 'My List',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.14),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.onMoreInfo != null) ...[
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: IconButton(
                            tooltip: 'More Info',
                            onPressed: widget.onMoreInfo,
                            style: IconButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                            ),
                            icon: const Icon(
                              Icons.info_outline_rounded,
                              color: Colors.white,
                              size: 21,
                            ),
                          ),
                        ),
                      ],
                    ],
                  )
                else
                  Row(
                    children: [
                      SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: widget.onPlay,
                          icon: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 24,
                          ),
                          label: const Text(
                            'Play',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (widget.onMoreInfo != null) ...[
                        SizedBox(
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: widget.onMoreInfo,
                            icon: const Icon(
                              Icons.info_outline_rounded,
                              color: Colors.white,
                              size: 19,
                            ),
                            label: const Text(
                              'More Info',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.14),
                              side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      SizedBox(
                        width: 44,
                        height: 44,
                        child: IconButton(
                          tooltip: widget.isFavorite
                              ? 'Remove from My List'
                              : 'Add to My List',
                          onPressed: widget.onToggleMyList,
                          style: IconButton.styleFrom(
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: widget.isFavorite
                                    ? AppColors.primary
                                    : Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                          ),
                          icon: Icon(
                            widget.isFavorite
                                ? Icons.bookmark_added_rounded
                                : Icons.add_rounded,
                            color: widget.isFavorite
                                ? AppColors.primary
                                : Colors.white,
                            size: 21,
                          ),
                        ),
                      ),
                    ],
                  ),

                // Trailers row on wider screens
                if (!isMobile && videos.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'TRAILERS & VIDEOS',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 68,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: videos.length.clamp(0, 6),
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, idx) =>
                          _buildDynamicTrailerCard(videos[idx]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicTrailerCard(TmdbVideoItem video) {
    return InkWell(
      onTap: () {
        if (widget.onPlayTrailer != null) {
          widget.onPlayTrailer!(video.youtubeUrl, video.name);
        } else {
          widget.onPlay();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: video.thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  Container(color: AppColors.surfaceElevated),
              errorWidget: (_, __, ___) =>
                  Container(color: AppColors.surfaceElevated),
            ),
            Container(color: Colors.black.withValues(alpha: 0.35)),
            const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            Positioned(
              left: 5,
              right: 5,
              bottom: 4,
              child: Text(
                video.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackBackdrop() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF231015), Color(0xFF140B0F), AppColors.background],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.movie_creation_rounded,
          color: Colors.white24,
          size: 64,
        ),
      ),
    );
  }
}
