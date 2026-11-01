import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  bool _isWatched = false;
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
    setState(() {
      _tmdb = null;
    });

    final tmdbService = ref.read(tmdbServiceProvider);
    final cleanTitle = _cleanTitle(item.title);
    final year = item.releaseYear ?? _extractYear(item.title);

    try {
      TmdbMetadata? data;
      if (item.type == MediaType.series) {
        data = await tmdbService.searchSeries(cleanTitle);
      } else {
        data = await tmdbService.searchMovie(cleanTitle, year: year);
      }

      if (mounted) {
        setState(() {
          _tmdb = data;
        });
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
        RegExp(r'\((HQ|LQ|4K|1080p|720p)\)', caseSensitive: false), '');
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final item = widget.item;

    final displayTitle = _cleanTitle(item.title);
    // Resolve backdrop: TMDB backdrop -> Item Backdrop -> Item Poster -> Rich gradient fallback
    final backdropUrl = _tmdb?.backdropUrl ??
        (item.backdropUrl != null && item.backdropUrl!.isNotEmpty
            ? item.backdropUrl
            : (item.posterUrl != null && item.posterUrl!.isNotEmpty
                ? item.posterUrl
                : null));

    final overview = _tmdb?.overview?.trim() ?? '';
    final videos = _tmdb?.videos ?? [];

    final heroHeight = videos.isNotEmpty
        ? (isMobile ? 540.0 : 610.0)
        : (isMobile ? 440.0 : 510.0);

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Full-Bleed High-Res Backdrop Image ──
          if (backdropUrl != null && backdropUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: backdropUrl,
              httpHeaders: const {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              },
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorWidget: (_, __, ___) => _buildFallbackBackdrop(),
            )
          else
            _buildFallbackBackdrop(),

          // ── 2. Multi-Stop Dark Gradients ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF0E0708).withValues(alpha: 0.85),
                  const Color(0xFF0E0708).withValues(alpha: 0.25),
                  Colors.transparent,
                  const Color(0xFF0E0708).withValues(alpha: 0.95),
                  const Color(0xFF0E0708),
                ],
                stops: const [0.0, 0.16, 0.45, 0.88, 1.0],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFF0E0708).withValues(alpha: 0.95),
                  const Color(0xFF0E0708).withValues(alpha: 0.75),
                  const Color(0xFF0E0708).withValues(alpha: 0.25),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 0.65, 1.0],
              ),
            ),
          ),

          // ── 3. Content Overlays (100% Dynamic) ──
          Positioned(
            left: isMobile ? 18 : 36,
            right: isMobile ? 18 : 36,
            bottom: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Title Rendering (Main Title + Subtitle if colon exists) ──
                _buildDynamicTitle(displayTitle, isMobile),

                if (overview.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxWidth: isMobile ? double.infinity : 620),
                    child: Text(
                      overview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: isMobile ? 12 : 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // ── Action Buttons & Cast / Director on Right ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // [▶ Play] Button
                    ElevatedButton.icon(
                      onPressed: widget.onPlay,
                      icon: const Icon(Icons.play_arrow_rounded,
                          color: Colors.black, size: 22),
                      label: const Text(
                        'Play',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 16 : 24,
                          vertical: 11,
                        ),
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                    ),

                    SizedBox(width: isMobile ? 8 : 12),

                    // (+) Add to My List Button
                    InkWell(
                      onTap: widget.onToggleMyList,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1),
                        ),
                        child: Icon(
                          widget.isFavorite
                              ? Icons.bookmark_added_rounded
                              : Icons.add_rounded,
                          color: widget.isFavorite
                              ? const Color(0xFFE50914)
                              : Colors.white,
                          size: 20,
                        ),
                      ),
                    ),

                    SizedBox(width: isMobile ? 6 : 10),

                    // (✔) Watched Checkmark Button
                    InkWell(
                      onTap: () => setState(() => _isWatched = !_isWatched),
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isWatched
                                ? const Color(0xFF00E676)
                                : Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: _isWatched
                              ? const Color(0xFF00E676)
                              : Colors.white70,
                          size: 18,
                        ),
                      ),
                    ),

                    // (ℹ) Details Button
                    if (widget.onMoreInfo != null) ...[
                      SizedBox(width: isMobile ? 6 : 10),
                      InkWell(
                        onTap: widget.onMoreInfo,
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: isMobile ? 42 : null,
                          height: 42,
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 0 : 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: isMobile
                              ? const Icon(Icons.info_outline_rounded,
                                  color: Colors.white, size: 18)
                              : const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.info_outline_rounded,
                                        color: Colors.white, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      'Details',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ],
                ),

                // ── Real "TRAILERS & VIDEOS" Row if available for this title ──
                if (videos.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'TRAILERS & VIDEOS (${videos.length})',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 72,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: videos.length.clamp(0, 6),
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, idx) {
                        final video = videos[idx];
                        return _buildDynamicTrailerCard(video);
                      },
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

  Widget _buildDynamicTitle(String fullTitle, bool isMobile) {
    return Text(
      fullTitle.toUpperCase(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white,
        fontSize: isMobile ? 24 : 36,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.9),
            blurRadius: 14,
            offset: const Offset(0, 3),
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
        width: 124,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // YouTube thumbnail
            CachedNetworkImage(
              imageUrl: video.thumbnailUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: const Color(0xFF1C0E11)),
              errorWidget: (_, __, ___) =>
                  Container(color: const Color(0xFF1C0E11)),
            ),

            Container(color: Colors.black.withValues(alpha: 0.35)),

            // Center Play Icon
            Center(
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.2),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),

            // Red [TRAILER] badge
            Positioned(
              left: 4,
              bottom: 18,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  video.type.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            // Trailer Title
            Positioned(
              left: 4,
              right: 4,
              bottom: 3,
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
          colors: [Color(0xFF2C1015), Color(0xFF14080A), Color(0xFF0E0708)],
        ),
      ),
      child: const Center(
        child:
            Icon(Icons.movie_creation_rounded, color: Colors.white24, size: 70),
      ),
    );
  }
}
