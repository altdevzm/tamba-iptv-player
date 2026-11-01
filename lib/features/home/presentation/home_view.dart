import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/drift.dart' as drift;
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/persistence/app_database.dart';
import '../../../core/persistence/database_provider.dart';
import '../../../shared/models/media_item.dart';
import '../../player/data/player_controller.dart';
import '../../content_details/presentation/adaptive_details_coordinator.dart';
import 'widgets/flixor_hero_spotlight.dart';

// ---------------------------------------------------------------------------
// Dynamic Database Content Providers (100% Real Playlist Data)
// ---------------------------------------------------------------------------

final homeMoviesProvider = StreamProvider.autoDispose<List<MediaItem>>((ref) {
  final playlistId = ref.watch(activePlaylistIdProvider);
  if (playlistId == null) return Stream.value([]);
  final db = ref.watch(databaseProvider);

  return db
      .watchTopContentItems(playlistId, 'movie', limit: 30)
      .map((rows) => rows
          .map((c) => MediaItem(
                id: c.providerId,
                title: c.title,
                type: MediaType.movie,
                posterUrl: c.posterUrl,
                backdropUrl: c.backdropUrl,
                rating: c.rating,
                releaseYear: c.releaseYear,
                streamUrl: c.streamUrl,
                playlistId: c.playlistId,
                providerId: c.providerId,
                contentDbId: c.id,
              ))
          .toList());
});

final homeSeriesProvider = StreamProvider.autoDispose<List<MediaItem>>((ref) {
  final playlistId = ref.watch(activePlaylistIdProvider);
  if (playlistId == null) return Stream.value([]);
  final db = ref.watch(databaseProvider);

  return db
      .watchTopContentItems(playlistId, 'series', limit: 30)
      .map((rows) => rows
          .map((c) => MediaItem(
                id: c.providerId,
                title: c.title,
                type: MediaType.series,
                posterUrl: c.posterUrl,
                backdropUrl: c.backdropUrl,
                rating: c.rating,
                releaseYear: c.releaseYear,
                streamUrl: c.streamUrl,
                playlistId: c.playlistId,
                providerId: c.providerId,
                contentDbId: c.id,
              ))
          .toList());
});

final homeLatest2026Provider =
    StreamProvider.autoDispose<List<MediaItem>>((ref) {
  final playlistId = ref.watch(activePlaylistIdProvider);
  if (playlistId == null) return Stream.value([]);
  final db = ref.watch(databaseProvider);

  return db.watchLatestReleases(playlistId, limit: 30).map((rows) {
    // Prioritize 2026 releases first, then newest release years descending
    final sorted = List.of(rows);
    sorted.sort((a, b) {
      final aIs2026 = (a.releaseYear == 2026) ? 1 : 0;
      final bIs2026 = (b.releaseYear == 2026) ? 1 : 0;
      if (aIs2026 != bIs2026) return bIs2026.compareTo(aIs2026);
      return (b.releaseYear ?? 0).compareTo(a.releaseYear ?? 0);
    });

    return sorted
        .map((c) => MediaItem(
              id: c.providerId,
              title: c.title,
              type: c.type == 'series' ? MediaType.series : MediaType.movie,
              posterUrl: c.posterUrl,
              backdropUrl: c.backdropUrl,
              rating: c.rating,
              releaseYear: c.releaseYear,
              streamUrl: c.streamUrl,
              playlistId: c.playlistId,
              providerId: c.providerId,
              contentDbId: c.id,
            ))
        .toList();
  });
});

final continueWatchingMediaProvider =
    StreamProvider.autoDispose<List<MediaItem>>((ref) {
  final db = ref.watch(databaseProvider);
  final playlistId = ref.watch(activePlaylistIdProvider);
  if (playlistId == null) return Stream.value([]);

  return db.watchContinueWatching(playlistId).asyncMap((positions) async {
    final List<MediaItem> items = [];
    for (final pos in positions) {
      final content = await (db.select(db.contentItemsTable)
            ..where((t) => t.playlistId.equals(pos.playlistId))
            ..where((t) => t.providerId.equals(pos.contentProviderId))
            ..where((t) => t.type
                .equals(pos.contentType == 'episode' ? 'series' : 'movie')))
          .getSingleOrNull();

      if (content != null) {
        items.add(MediaItem(
          id: content.providerId,
          title: content.title,
          type: content.type == 'series' ? MediaType.series : MediaType.movie,
          posterUrl: content.posterUrl,
          backdropUrl: content.backdropUrl,
          rating: content.rating,
          releaseYear: content.releaseYear,
          streamUrl: content.streamUrl,
          playlistId: content.playlistId,
          providerId: content.providerId,
          contentDbId: content.id,
          seriesProviderId: pos.seriesProviderId,
          seasonNumber: pos.seasonNumber,
          episodeNumber: pos.episodeNumber,
          subtitle: pos.seasonNumber != null && pos.episodeNumber != null
              ? 'S${pos.seasonNumber} E${pos.episodeNumber}'
              : null,
          positionSeconds: pos.positionSeconds,
          durationSeconds: pos.durationSeconds ?? 0,
        ));
      }
    }
    return items;
  });
});

final homeFavoritesMediaProvider =
    StreamProvider.autoDispose<List<MediaItem>>((ref) {
  final db = ref.watch(databaseProvider);
  final playlistId = ref.watch(activePlaylistIdProvider);
  if (playlistId == null) return Stream.value([]);

  return db.watchFavorites(playlistId).asyncMap((favs) async {
    final List<MediaItem> items = [];
    for (final f in favs) {
      String? streamUrl;
      if (f.contentId != null) {
        final content = await (db.select(db.contentItemsTable)
              ..where((t) => t.id.equals(f.contentId!)))
            .getSingleOrNull();
        streamUrl = content?.streamUrl;
      }
      items.add(MediaItem(
        id: f.providerId,
        title: f.title,
        type: f.type == 'live'
            ? MediaType.live
            : (f.type == 'series' ? MediaType.series : MediaType.movie),
        posterUrl: f.posterUrl,
        backdropUrl: f.backdropUrl,
        streamUrl: streamUrl,
        playlistId: f.playlistId,
        providerId: f.providerId,
        contentDbId: f.contentId,
      ));
    }
    return items;
  });
});

// ---------------------------------------------------------------------------
// Home View - 100% Dynamic IPTV Experience
// ---------------------------------------------------------------------------

class HomeView extends ConsumerStatefulWidget {
  const HomeView({super.key});

  @override
  ConsumerState<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends ConsumerState<HomeView> {
  final ScrollController _scrollController = ScrollController();
  Timer? _spotlightTimer;
  int _spotlightIndex = 0;

  @override
  void initState() {
    super.initState();
    _spotlightTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      if (mounted) setState(() => _spotlightIndex++);
    });
  }

  @override
  void dispose() {
    _spotlightTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Auto-resolve playlist if not already set
    ref.watch(effectivePlaylistIdProvider);

    final playerController = ref.read(playerControllerProvider.notifier);
    final db = ref.watch(databaseProvider);

    final moviesAsync = ref.watch(homeMoviesProvider);
    final seriesAsync = ref.watch(homeSeriesProvider);
    final latest2026Async = ref.watch(homeLatest2026Provider);
    final continueWatchingAsync = ref.watch(continueWatchingMediaProvider);
    final favoritesAsync = ref.watch(homeFavoritesMediaProvider);

    final movies = moviesAsync.valueOrNull ?? [];
    final series = seriesAsync.valueOrNull ?? [];
    final latest2026 = latest2026Async.valueOrNull ?? [];
    final continueItems = continueWatchingAsync.valueOrNull ?? [];
    final favoriteItems = favoritesAsync.valueOrNull ?? [];

    final spotlightCandidates = <MediaItem>[
      ...latest2026,
      ...movies,
      ...series,
      ...continueItems,
      ...favoriteItems,
    ];
    final seenSpotlightIds = <String>{};
    final uniqueSpotlights = spotlightCandidates.where((item) {
      final key =
          '${item.type.name}:${item.playlistId}:${item.providerId ?? item.id}';
      return seenSpotlightIds.add(key);
    }).toList();
    final activeSpotlight = uniqueSpotlights.isEmpty
        ? null
        : uniqueSpotlights[_spotlightIndex % uniqueSpotlights.length];

    void playMedia(MediaItem item) {
      if (item.type == MediaType.series &&
          (item.streamUrl == null || item.streamUrl!.isEmpty)) {
        AdaptiveDetailsCoordinator.showMediaItem(context, item);
      } else {
        playerController.playItem(item, startFullscreen: true);
      }
    }

    void openContentDetail(MediaItem item) {
      if (item.type == MediaType.movie || item.type == MediaType.series) {
        AdaptiveDetailsCoordinator.showMediaItem(context, item);
      } else {
        playMedia(item);
      }
    }

    void playTrailer(String url, String title) {
      if (activeSpotlight == null) return;
      final trailerMedia = MediaItem(
        id: 'trailer_${DateTime.now().millisecondsSinceEpoch}',
        title: '${activeSpotlight.title} - $title',
        type: MediaType.movie,
        streamUrl: url,
        posterUrl: activeSpotlight.posterUrl,
        backdropUrl: activeSpotlight.backdropUrl,
      );
      playerController.playItem(trailerMedia, startFullscreen: true);
    }

    // If completely empty (no playlist content yet)
    if (activeSpotlight == null &&
        movies.isEmpty &&
        series.isEmpty &&
        latest2026.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0E0708),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35)),
                ),
                child: const Icon(Icons.playlist_play_rounded,
                    color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 18),
              const Text(
                'No Playlist Connected',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Go to Settings > My Playlists & IPTV Providers to add your Xtream or M3U playlist.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55), fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.go('/settings'),
                icon: const Icon(Icons.settings_rounded, size: 16),
                label: const Text('Open Settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0E0708), // Dark wine-tinted charcoal
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. Dynamic Full-Bleed Edge-to-Edge Hero Spotlight ──
            if (activeSpotlight != null)
              Builder(
                builder: (context) {
                  final spotlight = activeSpotlight;
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 800),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.02, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: StreamBuilder<bool>(
                      key: ValueKey(
                        '${spotlight.type.name}:${spotlight.playlistId}:${spotlight.providerId ?? spotlight.id}',
                      ),
                      stream: (spotlight.playlistId != null &&
                              spotlight.providerId != null)
                          ? db.watchIsFavorite(
                              spotlight.playlistId!,
                              spotlight.type == MediaType.series
                                  ? 'series'
                                  : (spotlight.type == MediaType.live
                                      ? 'live'
                                      : 'movie'),
                              spotlight.providerId!,
                            )
                          : Stream.value(false),
                      builder: (context, snap) {
                        final isFav = snap.data ?? false;
                        return FlixorHeroSpotlight(
                          item: spotlight,
                          onPlay: () {
                            if (spotlight.type == MediaType.series &&
                                (spotlight.streamUrl == null ||
                                    spotlight.streamUrl!.isEmpty)) {
                              openContentDetail(spotlight);
                            } else {
                              playMedia(spotlight);
                            }
                          },
                          onMoreInfo: () => openContentDetail(spotlight),
                          isFavorite: isFav,
                          onToggleMyList: () async {
                            if (spotlight.playlistId != null &&
                                spotlight.providerId != null) {
                              await db.toggleFavorite(
                                FavoritesTableCompanion(
                                  playlistId:
                                      drift.Value(spotlight.playlistId!),
                                  contentId: drift.Value(spotlight.contentDbId),
                                  providerId:
                                      drift.Value(spotlight.providerId!),
                                  type: drift.Value(
                                      spotlight.type == MediaType.series
                                          ? 'series'
                                          : (spotlight.type == MediaType.live
                                              ? 'live'
                                              : 'movie')),
                                  title: drift.Value(spotlight.title),
                                  posterUrl: drift.Value(spotlight.posterUrl),
                                  backdropUrl:
                                      drift.Value(spotlight.backdropUrl),
                                ),
                              );
                            }
                          },
                          onPlayTrailer: playTrailer,
                        );
                      },
                    ),
                  );
                },
              ),

            const SizedBox(height: 20),

            // ── 1. "Continue Watching" Rail (Real In-Progress Positions) ──
            if (continueItems.isNotEmpty) ...[
              _buildRailSection(
                title: 'Continue Watching',
                items: continueItems,
                showProgress: true,
                onSelect: playMedia,
              ),
              const SizedBox(height: 26),
            ],

            // ── 2. "My List" Rail (Real Favorites Bookmarks) ──
            if (favoriteItems.isNotEmpty) ...[
              _buildRailSection(
                title: 'My List (${favoriteItems.length})',
                items: favoriteItems,
                onHeaderTap: () => context.go('/favorites'),
                onSelect: openContentDetail,
              ),
              const SizedBox(height: 26),
            ],

            // ── 3. Movies & Blockbusters ──
            if (movies.isNotEmpty) ...[
              _buildRailSection(
                title: 'Movies & Blockbusters (${movies.length})',
                items: movies,
                onHeaderTap: () => context.go('/movies'),
                onSelect: openContentDetail,
              ),
              const SizedBox(height: 26),
            ],

            // ── 4. TV Shows & Series ──
            if (series.isNotEmpty) ...[
              _buildRailSection(
                title: 'TV Shows & Series (${series.length})',
                items: series,
                onHeaderTap: () => context.go('/series'),
                onSelect: openContentDetail,
              ),
              const SizedBox(height: 26),
            ],

            // ── 5. Latest Releases ──
            if (latest2026.isNotEmpty) ...[
              _buildRailSection(
                title: 'Latest Releases (${latest2026.length})',
                items: latest2026,
                onSelect: openContentDetail,
              ),
              const SizedBox(height: 26),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildRailSection({
    required String title,
    required List<MediaItem> items,
    required ValueChanged<MediaItem> onSelect,
    VoidCallback? onHeaderTap,
    bool showProgress = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: InkWell(
            onTap: onHeaderTap,
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                if (onHeaderTap != null) ...[
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.white54,
                    size: 13,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Horizontal Poster Rail
        SizedBox(
          height: 215,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = items[index];
              return _FlixorPosterCard(
                item: item,
                showProgress: showProgress,
                onTap: () => onSelect(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Clean, Modern Poster Card Matching Design Reference
// ---------------------------------------------------------------------------
class _FlixorPosterCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final bool showProgress;

  const _FlixorPosterCard({
    required this.item,
    required this.onTap,
    this.showProgress = false,
  });

  @override
  State<_FlixorPosterCard> createState() => _FlixorPosterCardState();
}

class _FlixorPosterCardState extends State<_FlixorPosterCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  bool get _isActive => _isHovered || _isFocused;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return FocusableActionDetector(
      onFocusChange: (f) => setState(() => _isFocused = f),
      onShowHoverHighlight: (h) => setState(() => _isHovered = h),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onTap(),
        ),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 142,
          height: 212,
          transform: Matrix4.diagonal3Values(
            _isFocused ? 1.05 : (_isHovered ? 1.03 : 1.0),
            _isFocused ? 1.05 : (_isHovered ? 1.03 : 1.0),
            1.0,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isFocused
                  ? Colors.white
                  : (_isHovered
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.08)),
              width: _isFocused ? 2.2 : (_isHovered ? 1.5 : 0.8),
            ),
            boxShadow: [
              if (_isActive)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster Image with User-Agent headers
              if (item.posterUrl != null && item.posterUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: item.posterUrl!,
                  httpHeaders: const {
                    'User-Agent':
                        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                  },
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _buildFallback(item, isLoading: true),
                  errorWidget: (_, __, ___) => _buildFallback(item),
                )
              else
                _buildFallback(item),

              // Bottom Title Scrim
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 65,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  alignment: Alignment.bottomLeft,
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              // Play icon overlay on hover/focus
              if (_isActive)
                Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _isFocused
                            ? AppColors.primary
                            : Colors.black.withValues(alpha: 0.7),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),

              // Progress Bar if continue watching
              if (widget.showProgress &&
                  item.durationSeconds > 0 &&
                  item.positionSeconds > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    value: (item.positionSeconds / item.durationSeconds)
                        .clamp(0.0, 1.0),
                    backgroundColor: Colors.white12,
                    color: AppColors.primary,
                    minHeight: 3.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallback(MediaItem item, {bool isLoading = false}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF281318), Color(0xFF160A0D), Color(0xFF0F0608)],
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.type == MediaType.live
                        ? Icons.live_tv_rounded
                        : (item.type == MediaType.series
                            ? Icons.tv_rounded
                            : Icons.movie_rounded),
                    color: Colors.white24,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
