import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/persistence/app_database.dart';
import '../../../core/persistence/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/models/media_item.dart';
import '../../content_details/presentation/adaptive_details_coordinator.dart';
import '../../home/presentation/home_view.dart';
import '../../player/data/player_controller.dart';

final favoritesStreamProvider =
    StreamProvider.autoDispose<List<FavoritesTableData>>((ref) {
  final db = ref.watch(databaseProvider);
  final activePlaylistId = ref.watch(activePlaylistIdProvider);

  if (activePlaylistId == null) {
    return (db.select(db.favoritesTable)).watch();
  }

  return db.watchFavorites(activePlaylistId);
});

enum _MyListFilter { all, movie, series, live }

class FavoritesView extends ConsumerStatefulWidget {
  const FavoritesView({super.key});

  @override
  ConsumerState<FavoritesView> createState() => _FavoritesViewState();
}

class _FavoritesViewState extends ConsumerState<FavoritesView> {
  _MyListFilter _filter = _MyListFilter.all;

  @override
  Widget build(BuildContext context) {
    final favoritesAsync = ref.watch(favoritesStreamProvider);
    final continueItems =
        ref.watch(continueWatchingMediaProvider).valueOrNull ?? [];
    final db = ref.watch(databaseProvider);
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 16 : 28,
              isMobile ? 12 : 24,
              isMobile ? 16 : 28,
              12,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'My List',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 22 : 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                      _QuickHubButton(
                        icon: Icons.download_done_rounded,
                        label: 'Downloads',
                        onTap: () => context.go('/downloads'),
                      ),
                      const SizedBox(width: 8),
                      _QuickHubButton(
                        icon: Icons.playlist_play_rounded,
                        label: 'Playlists',
                        onTap: () => context.go('/playlists'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Continue Watching strip inside My List hub
                  if (continueItems.isNotEmpty) ...[
                    const Text(
                      'Continue Watching',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 138,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: continueItems.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final item = continueItems[index];
                          final progress = item.durationSeconds > 0
                              ? (item.positionSeconds / item.durationSeconds)
                                  .clamp(0.0, 1.0)
                              : 0.0;
                          return InkWell(
                            onTap: () {
                              if (item.type == MediaType.series &&
                                  (item.streamUrl == null ||
                                      item.streamUrl!.isEmpty)) {
                                AdaptiveDetailsCoordinator.showMediaItem(
                                    context, item);
                              } else {
                                ref
                                    .read(playerControllerProvider.notifier)
                                    .playItem(item, startFullscreen: true);
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 180,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if ((item.backdropUrl ?? item.posterUrl) !=
                                      null)
                                    CachedNetworkImage(
                                      imageUrl:
                                          item.backdropUrl ?? item.posterUrl!,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => Container(
                                        color: AppColors.surfaceElevated,
                                      ),
                                    )
                                  else
                                    Container(color: AppColors.surfaceElevated),
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Colors.transparent,
                                          Colors.black.withValues(alpha: 0.88),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Center(
                                    child: Icon(
                                      Icons.play_circle_fill_rounded,
                                      color: Colors.white,
                                      size: 34,
                                    ),
                                  ),
                                  Positioned(
                                    left: 8,
                                    right: 8,
                                    bottom: 8,
                                    child: Text(
                                      item.subtitle != null
                                          ? '${item.title} • ${item.subtitle}'
                                          : item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: Colors.white24,
                                      color: AppColors.primary,
                                      minHeight: 3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterChip('All', _MyListFilter.all),
                        const SizedBox(width: 8),
                        _filterChip('Movies', _MyListFilter.movie),
                        const SizedBox(width: 8),
                        _filterChip('Series', _MyListFilter.series),
                        const SizedBox(width: 8),
                        _filterChip('Live TV', _MyListFilter.live),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Watchlist Grid
          favoritesAsync.when(
            data: (allFavorites) {
              final favorites = switch (_filter) {
                _MyListFilter.all => allFavorites,
                _MyListFilter.movie =>
                  allFavorites.where((f) => f.type == 'movie').toList(),
                _MyListFilter.series =>
                  allFavorites.where((f) => f.type == 'series').toList(),
                _MyListFilter.live =>
                  allFavorites.where((f) => f.type == 'live').toList(),
              };

              if (favorites.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bookmark_border_rounded,
                            size: 56,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _filter == _MyListFilter.all
                                ? 'Your List is Empty'
                                : 'No Saved ${_filter.name[0].toUpperCase()}${_filter.name.substring(1)} Items',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap + My List on any movie, series, or live channel to save it here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  isMobile ? 16 : 28,
                  6,
                  isMobile ? 16 : 28,
                  96,
                ),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.crossAxisExtent;
                    final gridDelegate = w < 600
                        ? SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: w < 340 ? 2 : 3,
                            childAspectRatio: 0.65,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 12,
                          )
                        : const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 190,
                            childAspectRatio: 0.66,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          );
                    return SliverGrid(
                      gridDelegate: gridDelegate,
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _FocusableFavoriteCard(
                          item: favorites[index],
                          db: db,
                        ),
                        childCount: favorites.length,
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Text(
                  'Error: $e',
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _MyListFilter value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.white70,
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected
              ? AppColors.primary
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}

class _QuickHubButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickHubButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusableFavoriteCard extends ConsumerStatefulWidget {
  final FavoritesTableData item;
  final AppDatabase db;

  const _FocusableFavoriteCard({
    required this.item,
    required this.db,
  });

  @override
  ConsumerState<_FocusableFavoriteCard> createState() =>
      _FocusableFavoriteCardState();
}

class _FocusableFavoriteCardState
    extends ConsumerState<_FocusableFavoriteCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  Future<void> _play() async {
    final item = widget.item;
    final db = widget.db;
    final player = ref.read(playerControllerProvider.notifier);

    if (item.type == 'movie' || item.type == 'series') {
      ContentItemsTableData? content;
      if (item.contentId != null) {
        content = await (db.select(db.contentItemsTable)
              ..where((t) => t.id.equals(item.contentId!)))
            .getSingleOrNull();
      }
      content ??= ContentItemsTableData(
        id: item.contentId ?? 0,
        playlistId: item.playlistId,
        providerId: item.providerId,
        title: item.title,
        type: item.type,
        posterUrl: item.posterUrl,
        backdropUrl: item.backdropUrl,
        tvArchive: 0,
        tvArchiveDuration: 0,
      );
      if (mounted) {
        AdaptiveDetailsCoordinator.show(context, content: content);
      }
      return;
    }

    String? streamUrl;
    if (item.contentId != null) {
      final content = await (db.select(db.contentItemsTable)
            ..where((t) => t.id.equals(item.contentId!)))
          .getSingleOrNull();
      streamUrl = content?.streamUrl;
    }

    final media = MediaItem(
      id: item.providerId,
      title: item.title,
      type: MediaType.live,
      posterUrl: item.posterUrl,
      backdropUrl: item.backdropUrl,
      streamUrl: streamUrl,
      playlistId: item.playlistId,
      providerId: item.providerId,
      contentDbId: item.contentId,
    );
    player.playItem(media, startFullscreen: true);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return FocusableActionDetector(
      onFocusChange: (f) => setState(() => _isFocused = f),
      onShowHoverHighlight: (h) => setState(() => _isHovered = h),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => _play(),
        ),
      },
      child: GestureDetector(
        onTap: _play,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _isFocused
                  ? Colors.white
                  : (_isHovered
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.08)),
              width: _isFocused ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (item.posterUrl != null && item.posterUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: item.posterUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _buildPlaceholder(item),
                )
              else
                _buildPlaceholder(item),

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 76,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.92),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 6,
                right: 6,
                child: InkWell(
                  onTap: () async {
                    await (widget.db.delete(widget.db.favoritesTable)
                          ..where((t) => t.id.equals(item.id)))
                        .go();
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),
                  ),
                ),
              ),

              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.type.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(FavoritesTableData item) {
    return Container(
      color: AppColors.surfaceElevated,
      child: Center(
        child: Icon(
          item.type == 'live'
              ? Icons.live_tv_rounded
              : (item.type == 'series'
                  ? Icons.tv_rounded
                  : Icons.movie_rounded),
          color: Colors.white.withValues(alpha: 0.2),
          size: 34,
        ),
      ),
    );
  }
}
