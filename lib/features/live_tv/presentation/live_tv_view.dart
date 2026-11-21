import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:go_router/go_router.dart';

import '../../../core/persistence/app_database.dart';
import '../../../core/persistence/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../epg/presentation/epg_timeline_widget.dart';
import '../../epg/presentation/reminders_dialog.dart';
import '../../content_details/domain/device_form_factor.dart';
import '../../content_details/presentation/adaptive_details_coordinator.dart';
import '../../../shared/models/media_item.dart';
import '../../player/data/player_controller.dart';
import '../../parental_lock/presentation/pin_prompt_dialog.dart';

// ---------------------------------------------------------------------------
// Sort & Resolution Enums
// ---------------------------------------------------------------------------

enum LiveTvSortOption {
  nameAZ,
  nameZA,
  channelId,
  favoritesFirst,
}

extension LiveTvSortOptionLabel on LiveTvSortOption {
  String get label {
    switch (this) {
      case LiveTvSortOption.nameAZ:
        return 'Name A–Z';
      case LiveTvSortOption.nameZA:
        return 'Name Z–A';
      case LiveTvSortOption.channelId:
        return 'Channel No.';
      case LiveTvSortOption.favoritesFirst:
        return 'Favorites First';
    }
  }
}

enum LiveTvResolutionFilter {
  all,
  fourK,
  fhd,
  hd,
  sd,
}

extension LiveTvResolutionFilterLabel on LiveTvResolutionFilter {
  String get label {
    switch (this) {
      case LiveTvResolutionFilter.all:
        return 'All Qualities';
      case LiveTvResolutionFilter.fourK:
        return '4K / UHD';
      case LiveTvResolutionFilter.fhd:
        return 'Full HD (1080p)';
      case LiveTvResolutionFilter.hd:
        return 'HD (720p)';
      case LiveTvResolutionFilter.sd:
        return 'SD';
    }
  }
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class LiveTvState {
  final int? selectedCategoryId;
  final Set<int> unlockedCategoryIds;
  final String searchQuery;
  final LiveTvSortOption sortBy;
  final LiveTvResolutionFilter resolution;
  final bool favoritesOnly;
  final bool isLoading;

  const LiveTvState({
    this.selectedCategoryId,
    this.unlockedCategoryIds = const {},
    this.searchQuery = '',
    this.sortBy = LiveTvSortOption.nameAZ,
    this.resolution = LiveTvResolutionFilter.all,
    this.favoritesOnly = false,
    this.isLoading = false,
  });

  LiveTvState copyWith({
    int? selectedCategoryId,
    bool clearCategory = false,
    Set<int>? unlockedCategoryIds,
    String? searchQuery,
    LiveTvSortOption? sortBy,
    LiveTvResolutionFilter? resolution,
    bool? favoritesOnly,
    bool? isLoading,
  }) {
    return LiveTvState(
      selectedCategoryId: clearCategory
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      unlockedCategoryIds: unlockedCategoryIds ?? this.unlockedCategoryIds,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      resolution: resolution ?? this.resolution,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool get hasActiveFilters =>
      selectedCategoryId != null ||
      searchQuery.isNotEmpty ||
      resolution != LiveTvResolutionFilter.all ||
      favoritesOnly ||
      sortBy != LiveTvSortOption.nameAZ;
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class LiveTvNotifier extends StateNotifier<LiveTvState> {
  LiveTvNotifier() : super(const LiveTvState());

  void filterByCategory(int? categoryId) {
    if (categoryId == null) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategoryId: categoryId);
    }
  }

  void unlockCategory(int categoryId) {
    state = state.copyWith(
      unlockedCategoryIds: {...state.unlockedCategoryIds, categoryId},
    );
  }

  void search(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSortBy(LiveTvSortOption sort) {
    state = state.copyWith(sortBy: sort);
  }

  void setResolution(LiveTvResolutionFilter res) {
    state = state.copyWith(resolution: res);
  }

  void toggleFavoritesOnly() {
    state = state.copyWith(favoritesOnly: !state.favoritesOnly);
  }

  void resetFilters() {
    state = const LiveTvState();
  }
}

final liveTvNotifierProvider =
    StateNotifierProvider<LiveTvNotifier, LiveTvState>(
  (_) => LiveTvNotifier(),
);

// ---------------------------------------------------------------------------
// Data providers
// ---------------------------------------------------------------------------

/// Watches all live channels for the active playlist.
final _liveChannelsProvider =
    StreamProvider.autoDispose<List<ContentItemsTableData>>((ref) {
  final playlistId = ref.watch(activePlaylistIdProvider);
  if (playlistId == null) return Stream.value([]);
  final db = ref.watch(databaseProvider);
  return db.watchContentItems(playlistId, 'live');
});

/// Watches categories of type 'live' for the active playlist.
final _liveCategoriesProvider =
    StreamProvider.autoDispose<List<CategoriesTableData>>((ref) {
  final playlistId = ref.watch(activePlaylistIdProvider);
  if (playlistId == null) return Stream.value([]);
  final db = ref.watch(databaseProvider);
  return db.watchCategories(playlistId, 'live');
});

/// Watches favorite live channel provider IDs for the active playlist.
final _liveFavoriteIdsProvider =
    StreamProvider.autoDispose<Set<String>>((ref) {
  final playlistId = ref.watch(activePlaylistIdProvider);
  if (playlistId == null) return Stream.value({});
  final db = ref.watch(databaseProvider);
  return db
      .watchFavorites(playlistId, type: 'live')
      .map((rows) => rows.map((r) => r.providerId).toSet());
});

/// Watches recently watched content DB IDs for the active playlist.
final _recentLiveChannelIdsProvider =
    StreamProvider.autoDispose<List<int>>((ref) {
  final playlistId = ref.watch(activePlaylistIdProvider);
  if (playlistId == null) return Stream.value([]);
  final db = ref.watch(databaseProvider);
  return db
      .watchRecentlyViewed(playlistId)
      .map((rows) => rows.map((r) => r.contentId).toList());
});

// ---------------------------------------------------------------------------
// View
// ---------------------------------------------------------------------------

class LiveTvView extends ConsumerStatefulWidget {
  const LiveTvView({super.key});

  @override
  ConsumerState<LiveTvView> createState() => _LiveTvViewState();
}

class _LiveTvViewState extends ConsumerState<LiveTvView> {
  final _searchController = TextEditingController();
  bool _searchSyncScheduled = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _syncSearchController(String query) {
    if (_searchController.text == query || _searchSyncScheduled) return;
    _searchSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchSyncScheduled = false;
      if (!mounted || _searchController.text == query) return;
      _searchController.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
    });
  }

  Future<void> _handleCategorySelect(CategoriesTableData? cat) async {
    final notifier = ref.read(liveTvNotifierProvider.notifier);
    if (cat == null) {
      notifier.filterByCategory(null);
      return;
    }

    final isLocked = cat.locked ||
        cat.name.toLowerCase().contains('adult') ||
        cat.name.toLowerCase().contains('xxx') ||
        cat.name.toLowerCase().contains('18+');

    final currentState = ref.read(liveTvNotifierProvider);
    if (isLocked && !currentState.unlockedCategoryIds.contains(cat.id)) {
      final unlocked =
          await PinPromptDialog.prompt(context, title: 'Unlock ${cat.name}');
      if (unlocked == true && mounted) {
        notifier.unlockCategory(cat.id);
        notifier.filterByCategory(cat.id);
      }
      return;
    }

    notifier.filterByCategory(cat.id);
  }

  @override
  Widget build(BuildContext context) {
    final activePlaylistId = ref.watch(activePlaylistIdProvider);
    final liveTvState = ref.watch(liveTvNotifierProvider);
    final notifier = ref.read(liveTvNotifierProvider.notifier);
    final channelsAsync = ref.watch(_liveChannelsProvider);
    final categoriesAsync = ref.watch(_liveCategoriesProvider);
    final favoriteIds = ref.watch(_liveFavoriteIdsProvider).valueOrNull ?? {};
    final recentIds =
        ref.watch(_recentLiveChannelIdsProvider).valueOrNull ?? [];

    // No playlist selected
    if (activePlaylistId == null) {
      return const _EmptyState(
        icon: Icons.live_tv_rounded,
        message: 'No playlist added yet.\nGo to Settings to add one.',
      );
    }

    final isTv = DeviceFormFactor.isTv(context);
    final isMobile = MediaQuery.sizeOf(context).width < 768 && !isTv;
    _syncSearchController(liveTvState.searchQuery);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 28,
          vertical: isMobile ? 10 : 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Header ----
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Live TV',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: isMobile ? 22 : 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => context.go('/epg'),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.view_timeline_rounded,
                            size: 15, color: Colors.white),
                        SizedBox(width: 5),
                        Text(
                          'Guide',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => RemindersDialog.show(context),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.alarm_on_rounded,
                            size: 15, color: Colors.white),
                        SizedBox(width: 5),
                        Text(
                          'Reminders',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ---- Search Bar ----
            _SearchBar(
              controller: _searchController,
              onChanged: notifier.search,
            ),
            const SizedBox(height: 10),

            // ---- Favorites, Sort & Quality Filters Row ----
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Favorites Only Pill
                  InkWell(
                    onTap: notifier.toggleFavoritesOnly,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: liveTvState.favoritesOnly
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: liveTvState.favoritesOnly
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            liveTvState.favoritesOnly
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            size: 14,
                            color: liveTvState.favoritesOnly
                                ? AppColors.primary
                                : Colors.white60,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Favorites',
                            style: TextStyle(
                              color: liveTvState.favoritesOnly
                                  ? Colors.white
                                  : Colors.white70,
                              fontSize: 12,
                              fontWeight: liveTvState.favoritesOnly
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sort By Pill
                  PopupMenuButton<LiveTvSortOption>(
                    onSelected: notifier.setSortBy,
                    color: const Color(0xFF1E1E26),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (_) => LiveTvSortOption.values
                        .map((s) =>
                            PopupMenuItem(value: s, child: Text(s.label)))
                        .toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: liveTvState.sortBy != LiveTvSortOption.nameAZ
                            ? AppColors.primary.withValues(alpha: 0.18)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: liveTvState.sortBy != LiveTvSortOption.nameAZ
                              ? AppColors.primary.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sort_rounded,
                              size: 13,
                              color:
                                  liveTvState.sortBy != LiveTvSortOption.nameAZ
                                      ? AppColors.primary
                                      : Colors.white54),
                          const SizedBox(width: 5),
                          Text(
                            liveTvState.sortBy.label,
                            style: TextStyle(
                              color:
                                  liveTvState.sortBy != LiveTvSortOption.nameAZ
                                      ? AppColors.primary
                                      : Colors.white70,
                              fontSize: 12,
                              fontWeight:
                                  liveTvState.sortBy != LiveTvSortOption.nameAZ
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded,
                              size: 14,
                              color:
                                  liveTvState.sortBy != LiveTvSortOption.nameAZ
                                      ? AppColors.primary
                                      : Colors.white38),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Resolution Filter Pill
                  PopupMenuButton<LiveTvResolutionFilter>(
                    onSelected: notifier.setResolution,
                    color: const Color(0xFF1E1E26),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    itemBuilder: (_) => LiveTvResolutionFilter.values
                        .map((r) =>
                            PopupMenuItem(value: r, child: Text(r.label)))
                        .toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color:
                            liveTvState.resolution != LiveTvResolutionFilter.all
                                ? AppColors.primary.withValues(alpha: 0.18)
                                : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: liveTvState.resolution !=
                                  LiveTvResolutionFilter.all
                              ? AppColors.primary.withValues(alpha: 0.6)
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.high_quality_rounded,
                              size: 14,
                              color: liveTvState.resolution !=
                                      LiveTvResolutionFilter.all
                                  ? AppColors.primary
                                  : Colors.white54),
                          const SizedBox(width: 5),
                          Text(
                            liveTvState.resolution.label,
                            style: TextStyle(
                              color: liveTvState.resolution !=
                                      LiveTvResolutionFilter.all
                                  ? AppColors.primary
                                  : Colors.white70,
                              fontSize: 12,
                              fontWeight: liveTvState.resolution !=
                                      LiveTvResolutionFilter.all
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded,
                              size: 14,
                              color: liveTvState.resolution !=
                                      LiveTvResolutionFilter.all
                                  ? AppColors.primary
                                  : Colors.white38),
                        ],
                      ),
                    ),
                  ),

                  if (liveTvState.hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: notifier.resetFilters,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.clear_rounded,
                                color: Colors.redAccent, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Reset',
                              style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ---- Live TV category chips ----
            categoriesAsync.when(
              data: (categories) {
                if (categories.isEmpty) return const SizedBox.shrink();
                return SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final isSelected =
                            liveTvState.selectedCategoryId == null;
                        return ChoiceChip(
                          label: const Text('All Channels'),
                          selected: isSelected,
                          onSelected: (_) => _handleCategorySelect(null),
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : Colors.white.withValues(alpha: 0.12),
                            ),
                          ),
                        );
                      }
                      final cat = categories[index - 1];
                      final isSelected =
                          liveTvState.selectedCategoryId == cat.id;
                      final sensitive = cat.locked ||
                          cat.name.toLowerCase().contains('adult') ||
                          cat.name.toLowerCase().contains('xxx') ||
                          cat.name.toLowerCase().contains('18+');
                      final locked = sensitive &&
                          !liveTvState.unlockedCategoryIds.contains(cat.id);

                      return ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (locked) ...[
                              const Icon(Icons.lock_outline,
                                  size: 12, color: Colors.amber),
                              const SizedBox(width: 4),
                            ],
                            Text(cat.name),
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (_) => _handleCategorySelect(cat),
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => const SizedBox(height: 36),
              error: (_, __) => const SizedBox(height: 36),
            ),
            const SizedBox(height: 12),

            // ---- Channel List ----
            Expanded(
              child: channelsAsync.when(
                data: (allChannels) {
                  final recentChannels = recentIds.isEmpty ||
                          liveTvState.searchQuery.isNotEmpty
                      ? const <ContentItemsTableData>[]
                      : recentIds
                          .map((id) {
                            for (final c in allChannels) {
                              if (c.id == id) return c;
                            }
                            return null;
                          })
                          .whereType<ContentItemsTableData>()
                          .take(10)
                          .toList();

                  final query = liveTvState.searchQuery.toLowerCase();
                  var filtered = allChannels.where((ch) {
                    if (liveTvState.favoritesOnly &&
                        !favoriteIds.contains(ch.providerId)) {
                      return false;
                    }
                    final matchesCategory =
                        liveTvState.selectedCategoryId == null ||
                            ch.categoryId == liveTvState.selectedCategoryId;
                    final matchesSearch =
                        query.isEmpty || ch.title.toLowerCase().contains(query);

                    // Quality filter
                    bool matchesResolution = true;
                    final titleUpper = ch.title.toUpperCase();
                    switch (liveTvState.resolution) {
                      case LiveTvResolutionFilter.all:
                        matchesResolution = true;
                        break;
                      case LiveTvResolutionFilter.fourK:
                        matchesResolution = titleUpper.contains('4K') ||
                            titleUpper.contains('UHD');
                        break;
                      case LiveTvResolutionFilter.fhd:
                        matchesResolution = titleUpper.contains('FHD') ||
                            titleUpper.contains('1080');
                        break;
                      case LiveTvResolutionFilter.hd:
                        matchesResolution = titleUpper.contains('HD') ||
                            titleUpper.contains('720');
                        break;
                      case LiveTvResolutionFilter.sd:
                        matchesResolution = titleUpper.contains('SD') ||
                            (!titleUpper.contains('HD') &&
                                !titleUpper.contains('4K') &&
                                !titleUpper.contains('FHD'));
                        break;
                    }

                    return matchesCategory &&
                        matchesSearch &&
                        matchesResolution;
                  }).toList();

                  switch (liveTvState.sortBy) {
                    case LiveTvSortOption.nameAZ:
                      filtered.sort((a, b) => a.title.compareTo(b.title));
                      break;
                    case LiveTvSortOption.nameZA:
                      filtered.sort((a, b) => b.title.compareTo(a.title));
                      break;
                    case LiveTvSortOption.channelId:
                      filtered.sort((a, b) => a.id.compareTo(b.id));
                      break;
                    case LiveTvSortOption.favoritesFirst:
                      filtered.sort((a, b) {
                        final aFav = favoriteIds.contains(a.providerId) ? 0 : 1;
                        final bFav = favoriteIds.contains(b.providerId) ? 0 : 1;
                        if (aFav != bFav) return aFav.compareTo(bFav);
                        return a.title.compareTo(b.title);
                      });
                      break;
                  }

                  if (filtered.isEmpty) {
                    return _EmptyState(
                      icon: Icons.search_off_rounded,
                      message: allChannels.isEmpty
                          ? 'No channels found.\nSync your playlist to load channels.'
                          : 'No channels match your filters.',
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (recentChannels.isNotEmpty) ...[
                        const Text(
                          'Recently Watched',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 62,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: recentChannels.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final ch = recentChannels[index];
                              return InkWell(
                                onTap: () {
                                  if (ch.streamUrl != null &&
                                      ch.streamUrl!.isNotEmpty) {
                                    ref
                                        .read(playerControllerProvider.notifier)
                                        .playItem(
                                          MediaItem(
                                            id: ch.providerId,
                                            title: ch.title,
                                            type: MediaType.live,
                                            posterUrl: ch.posterUrl,
                                            streamUrl: ch.streamUrl,
                                            playlistId: ch.playlistId,
                                            providerId: ch.providerId,
                                            contentDbId: ch.id,
                                          ),
                                          startFullscreen: true,
                                        );
                                  }
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 150,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      _ChannelLogo(logoUrl: ch.posterUrl),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          ch.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Expanded(
                        child: _ChannelList(channels: filtered, isTv: isTv),
                      ),
                    ],
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(
                  child: Text('Error loading channels: $e',
                      style: const TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search channels…',
          hintStyle:
              const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.textSecondary, size: 20),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: AppColors.textSecondary, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surfaceElevated,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _ChannelList extends ConsumerWidget {
  final List<ContentItemsTableData> channels;
  final bool isTv;

  const _ChannelList({required this.channels, required this.isTv});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    if (isTv) {
      return GridView.builder(
        itemCount: channels.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisExtent: 94,
          crossAxisSpacing: 12,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (context, index) =>
            _ChannelCard(channel: channels[index], db: db),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: channels.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) =>
          _ChannelCard(channel: channels[index], db: db),
    );
  }
}

class _ChannelCard extends ConsumerStatefulWidget {
  final ContentItemsTableData channel;
  final AppDatabase db;

  const _ChannelCard({required this.channel, required this.db});

  @override
  ConsumerState<_ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends ConsumerState<_ChannelCard> {
  bool _isHovered = false;
  bool _isFocused = false;
  String? _nowPlayingTitle;

  @override
  void initState() {
    super.initState();
    _fetchEpg();
  }

  void _openPreview() {
    AdaptiveDetailsCoordinator.show(context, content: widget.channel);
  }

  void _playChannel() {
    final ch = widget.channel;
    final url = ch.streamUrl;
    if (url != null && url.isNotEmpty) {
      final item = MediaItem(
        id: ch.providerId,
        title: ch.title,
        type: MediaType.live,
        posterUrl: ch.posterUrl,
        streamUrl: url,
        playlistId: ch.playlistId,
        providerId: ch.providerId,
        contentDbId: ch.id,
      );
      ref
          .read(playerControllerProvider.notifier)
          .playItem(item, startFullscreen: true);
    } else {
      _openPreview();
    }
  }

  Future<void> _fetchEpg() async {
    final epgId = widget.channel.epgChannelId;
    if (epgId == null || epgId.isEmpty) return;
    try {
      final programs =
          await widget.db.getCurrentAndNextPrograms(epgId, DateTime.now());
      if (programs.isNotEmpty && mounted) {
        setState(() => _nowPlayingTitle = programs.first.title);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;
    final isActive = _isHovered || _isFocused;
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return FocusableActionDetector(
      onFocusChange: (f) => setState(() => _isFocused = f),
      onShowHoverHighlight: (h) => setState(() => _isHovered = h),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => _openPreview(),
        ),
      },
      child: Material(
        color: isActive ? AppColors.surfaceElevated : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isMobile ? _playChannel : _openPreview,
          onLongPress: _openPreview,
          splashColor: AppColors.primary.withValues(alpha: 0.16),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 10 : 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isFocused
                    ? Colors.white
                    : (_isHovered
                        ? AppColors.primary.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.06)),
                width: _isFocused ? 2 : 1,
              ),
            ),
            child: Row(
            children: [
              // Channel Logo
              _ChannelLogo(logoUrl: ch.posterUrl),
              SizedBox(width: isMobile ? 12 : 16),

              // Channel Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ch.title,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: isMobile ? 14 : 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _nowPlayingTitle ?? 'LIVE',
                            style: TextStyle(
                              color: _nowPlayingTitle != null
                                  ? AppColors.textSecondary
                                  : AppColors.primary,
                              fontSize: 11.5,
                              fontWeight: _nowPlayingTitle != null
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // EPG & Catchup Button
              if ((ch.epgChannelId != null && ch.epgChannelId!.isNotEmpty) ||
                  ch.tvArchive > 0)
                IconButton(
                  icon: Icon(
                    ch.tvArchive > 0
                        ? Icons.history_rounded
                        : Icons.schedule_rounded,
                    color: ch.tvArchive > 0 ? Colors.amber : Colors.white60,
                    size: 20,
                  ),
                  visualDensity: VisualDensity.compact,
                  tooltip: ch.tvArchive > 0
                      ? 'Programme Guide & Catchup'
                      : 'Programme Guide',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => EpgTimelineWidget(
                        epgChannelId: ch.epgChannelId ?? ch.providerId,
                        channelName: ch.title,
                        channel: ch,
                      ),
                    );
                  },
                ),

              // Favorite Button
              StreamBuilder<bool>(
                stream: widget.db
                    .watchIsFavorite(ch.playlistId, 'live', ch.providerId),
                builder: (context, snap) {
                  final isFav = snap.data ?? false;
                  return IconButton(
                    icon: Icon(
                      isFav
                          ? Icons.bookmark_added_rounded
                          : Icons.bookmark_add_outlined,
                      color: isFav ? AppColors.primary : Colors.white54,
                      size: 20,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: isFav
                        ? 'In My List (Tap to remove)'
                        : 'Add to My List',
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await widget.db.toggleFavorite(
                        FavoritesTableCompanion(
                          playlistId: drift.Value(ch.playlistId),
                          contentId: drift.Value(ch.id),
                          providerId: drift.Value(ch.providerId),
                          type: const drift.Value('live'),
                          title: drift.Value(ch.title),
                          posterUrl: drift.Value(ch.posterUrl),
                        ),
                      );
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(isFav
                                ? 'Removed "${ch.title}" from My List'
                                : 'Added "${ch.title}" to My List'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                  );
                },
              ),

              // Info / Preview Button
              IconButton(
                icon: Icon(
                  isMobile
                      ? Icons.info_outline_rounded
                      : Icons.play_circle_fill_rounded,
                  color: Colors.white70,
                  size: isMobile ? 20 : 26,
                ),
                visualDensity: VisualDensity.compact,
                tooltip: isMobile ? 'Channel Info & EPG' : 'Watch Now',
                onPressed: isMobile ? _openPreview : _playChannel,
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _ChannelLogo extends StatelessWidget {
  final String? logoUrl;

  const _ChannelLogo({this.logoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: logoUrl != null && logoUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: logoUrl!,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const _LogoFallback(),
                placeholder: (_, __) => const _LogoFallback(),
              )
            : const _LogoFallback(),
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.live_tv_rounded, color: AppColors.textMuted, size: 22),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 64),
          const SizedBox(height: 20),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
