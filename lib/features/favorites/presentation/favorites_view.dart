import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/persistence/app_database.dart';
import '../../../core/persistence/database_provider.dart';
import '../../../shared/models/media_item.dart';
import '../../player/data/player_controller.dart';
import '../../content_details/presentation/adaptive_details_coordinator.dart';

final favoritesStreamProvider =
    StreamProvider.autoDispose<List<FavoritesTableData>>((ref) {
  final db = ref.watch(databaseProvider);
  final activePlaylistId = ref.watch(activePlaylistIdProvider);

  if (activePlaylistId == null) {
    return (db.select(db.favoritesTable)).watch();
  }

  return db.watchFavorites(activePlaylistId);
});

class FavoritesView extends ConsumerWidget {
  const FavoritesView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesAsync = ref.watch(favoritesStreamProvider);
    final db = ref.watch(databaseProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 32,
          vertical: isMobile ? 16 : 28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'My List & Favorites',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your bookmarked live channels, movies, and series',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),

            const SizedBox(height: 20),

            // Content
            Expanded(
              child: favoritesAsync.when(
                data: (favorites) {
                  if (favorites.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bookmark_border_rounded,
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Your List is Empty',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Click the favorite button on any channel or movie to save it here for quick access.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate:
                        SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: isMobile ? 165 : 210,
                      childAspectRatio: 0.68,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: favorites.length,
                    itemBuilder: (context, index) {
                      final item = favorites[index];
                      return _FocusableFavoriteCard(
                        item: item,
                        db: db,
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: Colors.redAccent)),
                ),
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

  bool get _isActive => _isHovered || _isFocused;

  Future<void> _play() async {
    final item = widget.item;
    final db = widget.db;
    final player = ref.read(playerControllerProvider.notifier);

    if (item.type == 'movie') {
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
        type: 'movie',
        posterUrl: item.posterUrl,
        backdropUrl: item.backdropUrl,
        tvArchive: 0,
        tvArchiveDuration: 0,
      );
      if (mounted) {
        AdaptiveDetailsCoordinator.show(context, content: content);
      }
      return;
    } else if (item.type == 'series') {
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
        type: 'series',
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.diagonal3Values(
            _isFocused ? 1.06 : (_isHovered ? 1.03 : 1.0),
            _isFocused ? 1.06 : (_isHovered ? 1.03 : 1.0),
            1.0,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFocused
                  ? Colors.white
                  : (_isHovered
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.08)),
              width: _isFocused ? 2.5 : (_isHovered ? 2 : 1),
            ),
            boxShadow: [
              BoxShadow(
                color: _isFocused
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : (_isHovered
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.3)),
                blurRadius: _isFocused ? 18 : (_isHovered ? 14 : 8),
                offset: Offset(0, _isActive ? 6 : 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster
              if (item.posterUrl != null && item.posterUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: item.posterUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => _buildPlaceholder(item),
                )
              else
                _buildPlaceholder(item),

              // Gradient overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 100,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.95),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Play overlay on focus/hover
              if (_isActive)
                Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isFocused
                          ? AppColors.primary
                          : Colors.black.withValues(alpha: 0.6),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),

              // Delete / Unfavorite Button
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.bookmark_remove_rounded,
                      color: Colors.white70, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.6),
                  ),
                  tooltip: 'Remove from My List',
                  onPressed: () async {
                    await (widget.db.delete(widget.db.favoritesTable)
                          ..where((t) => t.id.equals(item.id)))
                        .go();
                  },
                ),
              ),

              // Title & Type & Play Button
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.type.toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.all(8),
                      ),
                      onPressed: _play,
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
          size: 40,
        ),
      ),
    );
  }
}
