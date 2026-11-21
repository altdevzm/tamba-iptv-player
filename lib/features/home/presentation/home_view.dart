import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/persistence/app_database.dart';
import '../../../core/persistence/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/media_item.dart';
import '../../content_details/presentation/adaptive_details_coordinator.dart';
import '../../player/data/player_controller.dart';
import 'widgets/flixor_hero_spotlight.dart';

// ---------------------------------------------------------------------------
// Dynamic Database Content Providers (100% Real Playlist Data)
// ---------------------------------------------------------------------------

MediaItem _toMediaItem(ContentItemsTableData c) {
  return MediaItem(
    id: c.providerId,
    title: c.title,
    type: c.type == 'series'
        ? MediaType.series
        : (c.type == 'live' ? MediaType.live : MediaType.movie),
    posterUrl: c.posterUrl,
    backdropUrl: c.backdropUrl,
    rating: c.rating,
    releaseYear: c.releaseYear,
    streamUrl: c.streamUrl,
    playlistId: c.playlistId,
    providerId: c.providerId,
    contentDbId: c.id,
  );
}

final homeMoviesProvider = StreamProvider.autoDispose<List<MediaItem>>((ref) {
  final playlistId = ref.watch(activePlaylistIdProvider);
  if (playlistId == null) return Stream.value([]);
  final db = ref.watch(databaseProvider);

  return db
      .watchTopContentItems(playlistId, 'movie', limit: 30)
      .map((rows) => rows.map(_toMediaItem).toList());
});

final homePopularMoviesProvider =
    StreamProvider.autoDispose<List<MediaItem>>((ref) {
  final playlistId = ref.watch(activePlaylistIdProvider);
  if (playlistId == null) return Stream.value([]);
  final db = ref.watch(databaseProvider);

  return (db.select(db.contentItemsTable)
        ..where((t) => t.playlistId.equals(playlistId))
        ..where((t) => t.type.equals('movie'))
        ..where((t) => t.posterUrl.isNotNull() & t.posterUrl.isNotValue(''))
        ..orderBy([
          (t) => drift.OrderingTerm(
              expression: t.rating, mode: drift.OrderingMode.desc),
          (t) => drift.OrderingTerm(
              expression: t.releaseYear, mode: drift.OrderingMode.desc),
        ])
        ..limit(24))
      .watch()
      .map((rows) => rows.map(_toMediaItem).toList());
});

final homeSeriesProvider = StreamProvider.autoDispose<List<MediaItem>>((ref) {
  final playlistId = ref.watch(activePlaylistIdProvider);
  if (playlistId == null) return Stream.value([]);
  final db = ref.watch(databaseProvider);

  return db
      .watchTopContentItems(playlistId, 'series', limit: 30)
      .map((rows) => rows.map(_toMediaItem).toList());
});

final homeLiveTvProvider = StreamProvider.autoDispose<List<MediaItem>>((ref) {
  final playlistId = ref.watch(activePlaylistIdProvider);
  if (playlistId == null) return Stream.value([]);
  final db = ref.watch(databaseProvider);

  return (db.select(db.contentItemsTable)
        ..where((t) => t.playlistId.equals(playlistId))
        ..where((t) => t.type.equals('live'))
        ..limit(24))
      .watch()
      .map((rows) {
    final sorted = List.of(rows)
      ..sort((a, b) {
        final aHasLogo = (a.posterUrl?.isNotEmpty ?? false) ? 1 : 0;
        final bHasLogo = (b.posterUrl?.isNotEmpty ?? false) ? 1 : 0;
        return bHasLogo.compareTo(aHasLogo);
      });
    return sorted.map(_toMediaItem).toList();
  });
});

final homeLatest2026Provider =
    StreamProvider.autoDispose<List<MediaItem>>((ref) {
  final playlistId = ref.watch(activePlaylistIdProvider);
  if (playlistId == null) return Stream.value([]);
  final db = ref.watch(databaseProvider);

  return db.watchLatestReleases(playlistId, limit: 30).map((rows) {
    final sorted = List.of(rows)
      ..sort((a, b) => (b.releaseYear ?? 0).compareTo(a.releaseYear ?? 0));
    return sorted.map(_toMediaItem).toList();
  });
});

class HomeCategoryRail {
  final String title;
  final List<MediaItem> items;
  final String route;

  const HomeCategoryRail({
    required this.title,
    required this.items,
    required this.route,
  });
}

/// Discovers real genre carousels (Action, Comedy, Drama, Sci-Fi, etc.) from the active playlist.
final homeGenreRailsProvider =
    FutureProvider.autoDispose<List<HomeCategoryRail>>((ref) async {
  final playlistId = ref.watch(activePlaylistIdProvider);
  if (playlistId == null) return [];
  final db = ref.watch(databaseProvider);

  final categories = await db.getCategories(playlistId, 'movies');
  if (categories.isEmpty) return [];

  const genreMatchers = <String, List<String>>{
    'Action Movies': ['action'],
    'Comedy': ['comedy', 'comedies'],
    'Drama': ['drama'],
    'Thriller & Sci-Fi': ['thriller', 'sci-fi', 'scifi', 'science fiction'],
    'Animation & Family': ['animation', 'family', 'kids', 'cartoon'],
  };

  final rails = <HomeCategoryRail>[];
  final usedCategoryIds = <int>{};

  for (final entry in genreMatchers.entries) {
    if (rails.length >= 3) break;
    CategoriesTableData? match;
    for (final cat in categories) {
      if (cat.locked || usedCategoryIds.contains(cat.id)) continue;
      final lower = cat.name.toLowerCase();
      if (lower.contains('adult') ||
          lower.contains('xxx') ||
          lower.contains('18+')) {
        continue;
      }
      if (entry.value.any((kw) => lower.contains(kw))) {
        match = cat;
        break;
      }
    }
    if (match != null) {
      final matchedId = match.id;
      usedCategoryIds.add(matchedId);
      final rows = await (db.select(db.contentItemsTable)
            ..where((t) => t.playlistId.equals(playlistId))
            ..where((t) => t.type.equals('movie'))
            ..where((t) => t.categoryId.equals(matchedId))
            ..limit(18))
          .get();
      if (rows.length >= 3) {
        rails.add(
          HomeCategoryRail(
            title: entry.key,
            items: rows.map(_toMediaItem).toList(),
            route: '/movies',
          ),
        );
      }
    }
  }

  return rails;
});

final continueWatchingMediaProvider =
    StreamProvider.autoDispose<List<MediaItem>>((ref) {
  final db = ref.watch(databaseProvider);
  final playlistId = ref.watch(activePlaylistIdProvider);
  if (playlistId == null) return Stream.value([]);

  return db.watchContinueWatching(playlistId).asyncMap((positions) async {
    if (positions.isEmpty) return [];
    final providerIds =
        positions.map((p) => p.contentProviderId).toSet().toList();
    final contentRows = await (db.select(db.contentItemsTable)
          ..where((t) => t.playlistId.equals(playlistId))
          ..where((t) => t.providerId.isIn(providerIds)))
        .get();

    final byKey = <String, ContentItemsTableData>{
      for (final c in contentRows) '${c.type}:${c.providerId}': c,
    };

    final items = <MediaItem>[];
    for (final pos in positions) {
      final expectedType = pos.contentType == 'episode' ? 'series' : 'movie';
      final content = byKey['$expectedType:${pos.contentProviderId}'];
      if (content != null) {
        items.add(
          MediaItem(
            id: content.providerId,
            title: content.title,
            type:
                content.type == 'series' ? MediaType.series : MediaType.movie,
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
          ),
        );
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
    if (favs.isEmpty) return [];
    final contentIds =
        favs.map((f) => f.contentId).whereType<int>().toSet().toList();
    final contentMap = <int, ContentItemsTableData>{};
    if (contentIds.isNotEmpty) {
      final rows = await (db.select(db.contentItemsTable)
            ..where((t) => t.id.isIn(contentIds)))
          .get();
      for (final r in rows) {
        contentMap[r.id] = r;
      }
    }

    return favs.map((f) {
      final content = f.contentId != null ? contentMap[f.contentId!] : null;
      return MediaItem(
        id: f.providerId,
        title: f.title,
        type: f.type == 'live'
            ? MediaType.live
            : (f.type == 'series' ? MediaType.series : MediaType.movie),
        posterUrl: f.posterUrl,
        backdropUrl: f.backdropUrl,
        streamUrl: content?.streamUrl,
        playlistId: f.playlistId,
        providerId: f.providerId,
        contentDbId: f.contentId,
      );
    }).toList();
  });
});

// ---------------------------------------------------------------------------
// Home View - Mobile-First Cinematic Streaming Discovery
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
    ref.watch(effectivePlaylistIdProvider);

    final playerController = ref.read(playerControllerProvider.notifier);
    final db = ref.watch(databaseProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 768;

    final movies = ref.watch(homeMoviesProvider).valueOrNull ?? [];
    final popularMovies =
        ref.watch(homePopularMoviesProvider).valueOrNull ?? [];
    final series = ref.watch(homeSeriesProvider).valueOrNull ?? [];
    final liveChannels = ref.watch(homeLiveTvProvider).valueOrNull ?? [];
    final latestReleases = ref.watch(homeLatest2026Provider).valueOrNull ?? [];
    final continueItems =
        ref.watch(continueWatchingMediaProvider).valueOrNull ?? [];
    final favoriteItems =
        ref.watch(homeFavoritesMediaProvider).valueOrNull ?? [];
    final genreRails = ref.watch(homeGenreRailsProvider).valueOrNull ?? [];

    final spotlightCandidates = <MediaItem>[
      ...popularMovies,
      ...movies,
      ...latestReleases,
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
    // Prefer items that have artwork for the hero banner
    final withArtwork = uniqueSpotlights
        .where((i) =>
            (i.backdropUrl != null && i.backdropUrl!.isNotEmpty) ||
            (i.posterUrl != null && i.posterUrl!.isNotEmpty))
        .toList();
    final spotlightPool = withArtwork.isNotEmpty ? withArtwork : uniqueSpotlights;
    final activeSpotlight = spotlightPool.isEmpty
        ? null
        : spotlightPool[_spotlightIndex % spotlightPool.length];

    void playMedia(MediaItem item) {
      final isUnresolvedSeries = item.type == MediaType.series &&
          item.seasonNumber == null &&
          item.episodeNumber == null;
      final hasPlayableUrl =
          item.streamUrl != null && item.streamUrl!.trim().isNotEmpty;

      if (isUnresolvedSeries || !hasPlayableUrl) {
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

    if (activeSpotlight == null &&
        movies.isEmpty &&
        series.isEmpty &&
        liveChannels.isEmpty &&
        latestReleases.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.playlist_play_rounded,
                    color: AppColors.primary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'No Playlist Connected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your Xtream Codes, Stalker Portal, or M3U playlist in Settings to start streaming.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: () => context.go('/settings'),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('Add Playlist'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final horizontalPadding = isMobile ? 16.0 : 28.0;
    final double cardWidth = screenWidth < 380
        ? 106
        : (isMobile ? 118 : 148);
    final double cardHeight = cardWidth * 1.5;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // 1. Cinematic Hero Spotlight
          if (activeSpotlight != null)
            SliverToBoxAdapter(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 700),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: StreamBuilder<bool>(
                  key: ValueKey(
                    '${activeSpotlight.type.name}:${activeSpotlight.playlistId}:${activeSpotlight.providerId ?? activeSpotlight.id}',
                  ),
                  stream: (activeSpotlight.playlistId != null &&
                          activeSpotlight.providerId != null)
                      ? db.watchIsFavorite(
                          activeSpotlight.playlistId!,
                          activeSpotlight.type == MediaType.series
                              ? 'series'
                              : (activeSpotlight.type == MediaType.live
                                  ? 'live'
                                  : 'movie'),
                          activeSpotlight.providerId!,
                        )
                      : Stream.value(false),
                  builder: (context, snap) {
                    final isFav = snap.data ?? false;
                    return FlixorHeroSpotlight(
                      item: activeSpotlight,
                      onPlay: () => playMedia(activeSpotlight),
                      onMoreInfo: () => openContentDetail(activeSpotlight),
                      isFavorite: isFav,
                      onToggleMyList: () async {
                        if (activeSpotlight.playlistId != null &&
                            activeSpotlight.providerId != null) {
                          await db.toggleFavorite(
                            FavoritesTableCompanion(
                              playlistId:
                                  drift.Value(activeSpotlight.playlistId!),
                              contentId:
                                  drift.Value(activeSpotlight.contentDbId),
                              providerId:
                                  drift.Value(activeSpotlight.providerId!),
                              type: drift.Value(
                                activeSpotlight.type == MediaType.series
                                    ? 'series'
                                    : (activeSpotlight.type == MediaType.live
                                        ? 'live'
                                        : 'movie'),
                              ),
                              title: drift.Value(activeSpotlight.title),
                              posterUrl:
                                  drift.Value(activeSpotlight.posterUrl),
                              backdropUrl:
                                  drift.Value(activeSpotlight.backdropUrl),
                            ),
                          );
                        }
                      },
                      onPlayTrailer: playTrailer,
                    );
                  },
                ),
              ),
            ),

          SliverPadding(
            padding: const EdgeInsets.only(top: 12, bottom: 96),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 1. Continue Watching
                if (continueItems.isNotEmpty) ...[
                  _buildPosterRail(
                    title: 'Continue Watching',
                    items: continueItems,
                    horizontalPadding: horizontalPadding,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    showProgress: true,
                    onSelect: playMedia,
                  ),
                  const SizedBox(height: 22),
                ],

                // 2. Trending & Recently Added
                if (latestReleases.isNotEmpty) ...[
                  _buildPosterRail(
                    title: 'Trending & Recently Added',
                    items: latestReleases,
                    horizontalPadding: horizontalPadding,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    onHeaderTap: () => context.go('/movies'),
                    onSelect: openContentDetail,
                  ),
                  const SizedBox(height: 22),
                ],

                // 3. Popular Movies
                if (popularMovies.isNotEmpty) ...[
                  _buildPosterRail(
                    title: 'Popular Movies',
                    items: popularMovies,
                    horizontalPadding: horizontalPadding,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    onHeaderTap: () => context.go('/movies'),
                    onSelect: openContentDetail,
                  ),
                  const SizedBox(height: 22),
                ] else if (movies.isNotEmpty) ...[
                  _buildPosterRail(
                    title: 'Movies',
                    items: movies,
                    horizontalPadding: horizontalPadding,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    onHeaderTap: () => context.go('/movies'),
                    onSelect: openContentDetail,
                  ),
                  const SizedBox(height: 22),
                ],

                // 4. TV Series
                if (series.isNotEmpty) ...[
                  _buildPosterRail(
                    title: 'TV Series',
                    items: series,
                    horizontalPadding: horizontalPadding,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    onHeaderTap: () => context.go('/series'),
                    onSelect: openContentDetail,
                  ),
                  const SizedBox(height: 22),
                ],

                // 5. Live TV Channels
                if (liveChannels.isNotEmpty) ...[
                  _buildLiveTvRail(
                    title: 'Live TV',
                    channels: liveChannels,
                    horizontalPadding: horizontalPadding,
                    onHeaderTap: () => context.go('/live'),
                    onSelect: playMedia,
                  ),
                  const SizedBox(height: 22),
                ],

                // 6. Dynamic Genre Carousels from Playlist Categories
                for (final rail in genreRails) ...[
                  _buildPosterRail(
                    title: rail.title,
                    items: rail.items,
                    horizontalPadding: horizontalPadding,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    onHeaderTap: () => context.go(rail.route),
                    onSelect: openContentDetail,
                  ),
                  const SizedBox(height: 22),
                ],

                // 7. Your Watchlist / My List
                if (favoriteItems.isNotEmpty) ...[
                  _buildPosterRail(
                    title: 'Your Watchlist',
                    items: favoriteItems,
                    horizontalPadding: horizontalPadding,
                    cardWidth: cardWidth,
                    cardHeight: cardHeight,
                    onHeaderTap: () => context.go('/favorites'),
                    onSelect: openContentDetail,
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required double horizontalPadding,
    VoidCallback? onHeaderTap,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (onHeaderTap != null)
            InkWell(
              onTap: onHeaderTap,
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See All',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPosterRail({
    required String title,
    required List<MediaItem> items,
    required double horizontalPadding,
    required double cardWidth,
    required double cardHeight,
    required ValueChanged<MediaItem> onSelect,
    VoidCallback? onHeaderTap,
    bool showProgress = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: title,
          horizontalPadding: horizontalPadding,
          onHeaderTap: onHeaderTap,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return _FlixorPosterCard(
                item: item,
                width: cardWidth,
                height: cardHeight,
                showProgress: showProgress,
                onTap: () => onSelect(item),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLiveTvRail({
    required String title,
    required List<MediaItem> channels,
    required double horizontalPadding,
    required ValueChanged<MediaItem> onSelect,
    VoidCallback? onHeaderTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: title,
          horizontalPadding: horizontalPadding,
          onHeaderTap: onHeaderTap,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 104,
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: channels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final ch = channels[index];
              return _LiveChannelRailCard(
                item: ch,
                onTap: () => onSelect(ch),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LiveChannelRailCard extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onTap;

  const _LiveChannelRailCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primary.withValues(alpha: 0.16),
        child: Container(
          width: 156,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (item.posterUrl != null && item.posterUrl!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: item.posterUrl!,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => const Icon(
                            Icons.live_tv_rounded,
                            color: AppColors.textMuted,
                            size: 20,
                          ),
                        )
                      : const Icon(
                          Icons.live_tv_rounded,
                          color: AppColors.textMuted,
                          size: 20,
                        ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: AppColors.primary, size: 6),
                      SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Clean, Artwork-First Poster Card
// ---------------------------------------------------------------------------
class _FlixorPosterCard extends StatefulWidget {
  final MediaItem item;
  final VoidCallback onTap;
  final double width;
  final double height;
  final bool showProgress;

  const _FlixorPosterCard({
    required this.item,
    required this.onTap,
    required this.width,
    required this.height,
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
    final hasPoster = item.posterUrl != null && item.posterUrl!.isNotEmpty;

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
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isFocused
                  ? Colors.white
                  : (_isHovered
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.06)),
              width: _isFocused ? 2 : (_isHovered ? 1.4 : 0.8),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasPoster)
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

              // Continue Watching overlay (play icon + episode subtitle + progress bar)
              if (widget.showProgress) ...[
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 54,
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
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      item.subtitle ?? item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (item.durationSeconds > 0 && item.positionSeconds > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: (item.positionSeconds / item.durationSeconds)
                          .clamp(0.0, 1.0),
                      backgroundColor: Colors.white24,
                      color: AppColors.primary,
                      minHeight: 3.5,
                    ),
                  ),
              ],

              // Subtle play badge on hover/focus (desktop/TV)
              if (_isActive)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Center(
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _isFocused
                            ? AppColors.primary
                            : Colors.black.withValues(alpha: 0.72),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
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
      color: AppColors.surfaceElevated,
      padding: const EdgeInsets.all(10),
      child: Center(
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
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
                    size: 28,
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
