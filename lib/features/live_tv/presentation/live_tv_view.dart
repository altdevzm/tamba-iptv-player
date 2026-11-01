import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/persistence/app_database.dart';
import '../../../core/persistence/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../epg/presentation/epg_timeline_widget.dart';
import '../../epg/presentation/reminders_dialog.dart';
import '../../content_details/domain/device_form_factor.dart';
import '../../content_details/presentation/adaptive_details_coordinator.dart';
import '../../../shared/models/media_item.dart';
import '../../player/data/player_controller.dart';
import '../../xtream/data/xtream_client.dart';
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

    // No playlist selected
    if (activePlaylistId == null) {
      return const _EmptyState(
        icon: Icons.live_tv_rounded,
        message: 'No playlist added yet.\nGo to Playlists to add one.',
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
          vertical: isMobile ? 12 : 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Header ----
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Live Television',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => RemindersDialog.show(context),
                  icon: const Icon(Icons.alarm_on_rounded, size: 16),
                  label: const Text('Reminders'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (!isMobile) ...[
              _SearchBar(
                controller: _searchController,
                onChanged: notifier.search,
              ),
              const SizedBox(height: 12),
            ],

            // ---- Sort & Quality Filters Row ----
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
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

            // ---- Category Chips ----
            // ---- Live TV category selector ----
            categoriesAsync.when(
              data: (categories) => _CategoryDropdown(
                categories: categories,
                selectedCategoryId: liveTvState.selectedCategoryId,
                unlockedCategoryIds: liveTvState.unlockedCategoryIds,
                onSelected: _handleCategorySelect,
              ),
              loading: () => const SizedBox(height: 36),
              error: (_, __) => const SizedBox(height: 36),
            ),
            const SizedBox(height: 16),

            // ---- Channel List ----
            Expanded(
              child: channelsAsync.when(
                data: (allChannels) {
                  final query = liveTvState.searchQuery.toLowerCase();
                  var filtered = allChannels.where((ch) {
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

                  return _ChannelList(channels: filtered, isTv: isTv);
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

class _CategoryDropdown extends StatelessWidget {
  final List<CategoriesTableData> categories;
  final int? selectedCategoryId;
  final Set<int> unlockedCategoryIds;
  final ValueChanged<CategoriesTableData?> onSelected;

  const _CategoryDropdown({
    required this.categories,
    required this.selectedCategoryId,
    required this.unlockedCategoryIds,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final selectedExists =
        categories.any((cat) => cat.id == selectedCategoryId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.category_outlined,
              color: AppColors.textSecondary, size: 18),
          const SizedBox(width: 10),
          const Text(
            'Category',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                isExpanded: true,
                value: selectedExists ? selectedCategoryId : null,
                dropdownColor: AppColors.surfaceElevated,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All channels'),
                  ),
                  ...categories.map((cat) {
                    final sensitive = cat.locked ||
                        cat.name.toLowerCase().contains('adult') ||
                        cat.name.toLowerCase().contains('xxx') ||
                        cat.name.toLowerCase().contains('18+');
                    final locked =
                        sensitive && !unlockedCategoryIds.contains(cat.id);
                    return DropdownMenuItem<int?>(
                      value: cat.id,
                      child: Row(
                        children: [
                          if (locked) ...[
                            const Icon(Icons.lock_outline,
                                color: Colors.amber, size: 15),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(cat.name,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                onChanged: (id) {
                  if (id == null) {
                    onSelected(null);
                  } else {
                    final category =
                        categories.firstWhere((cat) => cat.id == id);
                    onSelected(category);
                  }
                },
              ),
            ),
          ),
        ],
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
      itemCount: channels.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
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
    }
  }

  Future<void> _fetchEpg() async {
    final epgId = widget.channel.epgChannelId;
    if (epgId != null && epgId.isNotEmpty) {
      try {
        final programs =
            await widget.db.getCurrentAndNextPrograms(epgId, DateTime.now());
        if (programs.isNotEmpty && mounted) {
          setState(() => _nowPlayingTitle = programs.first.title);
          return;
        }
      } catch (_) {}
    }

    // Xtream short EPG fallback
    try {
      final playlist = await widget.db.getPlaylist(widget.channel.playlistId);
      if (playlist != null &&
          playlist.type == 'xtream' &&
          playlist.serverUrl != null &&
          playlist.username != null) {
        final storage = ref.read(secureStorageProvider);
        final pass =
            await storage.getPlaylistCredentials(widget.channel.playlistId);
        if (pass != null) {
          final creds = XtreamCredentials(
              serverUrl: playlist.serverUrl!,
              username: playlist.username!,
              password: pass);
          final client = XtreamClient(ref.read(apiClientProvider).dio);
          final shortEpg = await client
              .getShortEpg(creds, widget.channel.providerId, limit: 1);
          if (shortEpg.isNotEmpty && mounted) {
            final rawTitle = shortEpg.first['title']?.toString();
            if (rawTitle != null && rawTitle.isNotEmpty) {
              String title = rawTitle;
              try {
                if (!rawTitle.contains(' ') && rawTitle.length % 4 == 0) {
                  title = utf8.decode(base64.decode(rawTitle));
                }
              } catch (_) {}
              setState(() => _nowPlayingTitle = title);
            }
          }
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final ch = widget.channel;
    final isActive = _isHovered || _isFocused;

    return FocusableActionDetector(
      onFocusChange: (f) => setState(() => _isFocused = f),
      onShowHoverHighlight: (h) => setState(() => _isHovered = h),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => _openPreview(),
        ),
      },
      child: GestureDetector(
        onTap: _openPreview,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          transform: Matrix4.diagonal3Values(
            _isFocused ? 1.02 : 1.0,
            _isFocused ? 1.02 : 1.0,
            1.0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppColors.surfaceElevated : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isFocused
                  ? Colors.white
                  : (_isHovered
                      ? AppColors.primary.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.06)),
              width: _isFocused ? 2 : 1,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 16,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Channel Logo
              _ChannelLogo(logoUrl: ch.posterUrl),
              const SizedBox(width: 16),

              // Channel Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ch.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    if (_nowPlayingTitle != null)
                      Text(
                        '▶  $_nowPlayingTitle',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      const Text(
                        'Live Stream',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),

              // LIVE Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.5)),
                ),
                child: const Text(
                  'LIVE',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
              ),

              const SizedBox(width: 8),

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

              // Direct Play Button
              IconButton(
                icon: const Icon(Icons.play_circle_fill_rounded,
                    color: Colors.white70, size: 24),
                tooltip: 'Watch Now',
                onPressed: _playChannel,
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
                      color: isFav ? AppColors.primary : Colors.white60,
                      size: 20,
                    ),
                    tooltip: isFav
                        ? 'In My List (Click to remove)'
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

              const SizedBox(width: 4),
              Icon(
                Icons.play_circle_outline_rounded,
                color: isActive ? AppColors.primary : Colors.white54,
                size: 26,
              ),
            ],
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
