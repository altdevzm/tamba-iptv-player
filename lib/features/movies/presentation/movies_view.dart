import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../content_details/presentation/adaptive_details_coordinator.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/persistence/app_database.dart';
import '../../../core/persistence/database_provider.dart';
import 'package:drift/drift.dart' as drift;
import '../../../shared/models/media_item.dart';
import '../../player/data/player_controller.dart';
import '../../player/data/external_player_service.dart';
import '../../downloads/data/download_service.dart';
import '../../../shared/services/tmdb_service.dart';
import '../../parental_lock/presentation/pin_prompt_dialog.dart';
import '../../xtream/data/xtream_client.dart';

// ---------------------------------------------------------------------------
// Sort & Filter Enums
// ---------------------------------------------------------------------------

enum MovieSortOption {
  titleAZ,
  titleZA,
  ratingHigh,
  ratingLow,
  yearNewest,
  yearOldest,
}

extension MovieSortOptionLabel on MovieSortOption {
  String get label {
    switch (this) {
      case MovieSortOption.titleAZ:
        return 'Title A–Z';
      case MovieSortOption.titleZA:
        return 'Title Z–A';
      case MovieSortOption.ratingHigh:
        return 'Top Rated';
      case MovieSortOption.ratingLow:
        return 'Lowest Rated';
      case MovieSortOption.yearNewest:
        return 'Newest';
      case MovieSortOption.yearOldest:
        return 'Oldest';
    }
  }
}

// ---------------------------------------------------------------------------
// State & Filter
// ---------------------------------------------------------------------------

class MoviesFilterState {
  final int? selectedCategoryId;
  final String searchQuery;
  final MovieSortOption sortBy;
  final int? filterYear;
  final double? minRating;

  const MoviesFilterState({
    this.selectedCategoryId,
    this.searchQuery = '',
    this.sortBy = MovieSortOption.titleAZ,
    this.filterYear,
    this.minRating,
  });

  MoviesFilterState copyWith({
    int? selectedCategoryId,
    bool clearCategory = false,
    String? searchQuery,
    MovieSortOption? sortBy,
    int? filterYear,
    bool clearYear = false,
    double? minRating,
    bool clearRating = false,
  }) {
    return MoviesFilterState(
      selectedCategoryId: clearCategory
          ? null
          : (selectedCategoryId ?? this.selectedCategoryId),
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      filterYear: clearYear ? null : (filterYear ?? this.filterYear),
      minRating: clearRating ? null : (minRating ?? this.minRating),
    );
  }

  bool get hasActiveFilters =>
      filterYear != null ||
      minRating != null ||
      sortBy != MovieSortOption.titleAZ;
}

class MoviesNotifier extends StateNotifier<MoviesFilterState> {
  MoviesNotifier() : super(const MoviesFilterState());

  void selectCategory(int? categoryId) {
    if (state.selectedCategoryId == categoryId) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategoryId: categoryId);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSortBy(MovieSortOption sort) {
    state = state.copyWith(sortBy: sort);
  }

  void setFilterYear(int? year) {
    if (year == null) {
      state = state.copyWith(clearYear: true);
    } else {
      state = state.copyWith(filterYear: year);
    }
  }

  void setMinRating(double? rating) {
    if (rating == null) {
      state = state.copyWith(clearRating: true);
    } else {
      state = state.copyWith(minRating: rating);
    }
  }

  void resetFilters() {
    state = const MoviesFilterState();
  }
}

final moviesFilterProvider =
    StateNotifierProvider<MoviesNotifier, MoviesFilterState>((ref) {
  return MoviesNotifier();
});

final moviesCategoriesProvider =
    StreamProvider.autoDispose<List<CategoriesTableData>>((ref) {
  final db = ref.watch(databaseProvider);
  final activePlaylistId = ref.watch(activePlaylistIdProvider);

  if (activePlaylistId == null) {
    return (db.select(db.categoriesTable)
          ..where((t) => t.type.equals('movies')))
        .watch();
  }

  return (db.select(db.categoriesTable)
        ..where((t) => t.playlistId.equals(activePlaylistId))
        ..where((t) => t.type.equals('movies')))
      .watch();
});

final filteredMoviesProvider =
    StreamProvider.autoDispose<List<ContentItemsTableData>>((ref) {
  final db = ref.watch(databaseProvider);
  final activePlaylistId = ref.watch(activePlaylistIdProvider);
  final filter = ref.watch(moviesFilterProvider);

  var query = db.select(db.contentItemsTable)
    ..where((t) => t.type.equals('movie'));

  if (activePlaylistId != null) {
    query = query..where((t) => t.playlistId.equals(activePlaylistId));
  }

  if (filter.selectedCategoryId != null) {
    query = query
      ..where((t) => t.categoryId.equals(filter.selectedCategoryId!));
  }

  return query.watch().map((items) {
    var result = items;

    // Search filter
    if (filter.searchQuery.isNotEmpty) {
      final term = filter.searchQuery.toLowerCase();
      result =
          result.where((i) => i.title.toLowerCase().contains(term)).toList();
    }

    // Year filter
    if (filter.filterYear != null) {
      result = result.where((i) => i.releaseYear == filter.filterYear).toList();
    }

    // Min rating filter
    if (filter.minRating != null) {
      result =
          result.where((i) => (i.rating ?? 0) >= filter.minRating!).toList();
    }

    // Sort
    result = List.from(result);
    switch (filter.sortBy) {
      case MovieSortOption.titleAZ:
        result.sort((a, b) => a.title.compareTo(b.title));
      case MovieSortOption.titleZA:
        result.sort((a, b) => b.title.compareTo(a.title));
      case MovieSortOption.ratingHigh:
        result.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      case MovieSortOption.ratingLow:
        result.sort((a, b) => (a.rating ?? 0).compareTo(b.rating ?? 0));
      case MovieSortOption.yearNewest:
        result
            .sort((a, b) => (b.releaseYear ?? 0).compareTo(a.releaseYear ?? 0));
      case MovieSortOption.yearOldest:
        result
            .sort((a, b) => (a.releaseYear ?? 0).compareTo(b.releaseYear ?? 0));
    }

    return result;
  });
});

// ---------------------------------------------------------------------------
// View
// ---------------------------------------------------------------------------

class MoviesView extends ConsumerStatefulWidget {
  const MoviesView({super.key});

  @override
  ConsumerState<MoviesView> createState() => _MoviesViewState();
}

class _MoviesViewState extends ConsumerState<MoviesView> {
  final _searchController = TextEditingController();
  final Set<int> _unlockedCategories = {};
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
    if (cat == null) {
      ref.read(moviesFilterProvider.notifier).selectCategory(null);
      return;
    }

    final isLocked = cat.locked ||
        cat.name.toLowerCase().contains('adult') ||
        cat.name.toLowerCase().contains('xxx') ||
        cat.name.toLowerCase().contains('18+');

    if (isLocked && !_unlockedCategories.contains(cat.id)) {
      final unlocked =
          await PinPromptDialog.prompt(context, title: 'Unlock ${cat.name}');
      if (unlocked == true && mounted) {
        setState(() => _unlockedCategories.add(cat.id));
        ref.read(moviesFilterProvider.notifier).selectCategory(cat.id);
      }
      return;
    }

    ref.read(moviesFilterProvider.notifier).selectCategory(cat.id);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(moviesCategoriesProvider);
    final moviesAsync = ref.watch(filteredMoviesProvider);
    final filter = ref.watch(moviesFilterProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;
    _syncSearchController(filter.searchQuery);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header + Search
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Movies Catalogue',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Browse and stream on-demand feature films',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                if (!isMobile)
                  SizedBox(
                    width: 260,
                    height: 42,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => ref
                          .read(moviesFilterProvider.notifier)
                          .setSearchQuery(val),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search movies...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: Colors.white54, size: 18),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: Colors.white54, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  ref
                                      .read(moviesFilterProvider.notifier)
                                      .setSearchQuery('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide:
                              const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 18),

            // ── Sort By & Filter By Bar ──
            _SortFilterBar(
              sortBy: filter.sortBy,
              filterYear: filter.filterYear,
              minRating: filter.minRating,
              onSortChanged: (s) =>
                  ref.read(moviesFilterProvider.notifier).setSortBy(s),
              onYearChanged: (y) =>
                  ref.read(moviesFilterProvider.notifier).setFilterYear(y),
              onRatingChanged: (r) =>
                  ref.read(moviesFilterProvider.notifier).setMinRating(r),
              onReset: () =>
                  ref.read(moviesFilterProvider.notifier).resetFilters(),
              hasActiveFilters: filter.hasActiveFilters,
            ),

            const SizedBox(height: 14),

            // Category Chips
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
                        final isSelected = filter.selectedCategoryId == null;
                        return ChoiceChip(
                          label: const Text('All Movies'),
                          selected: isSelected,
                          onSelected: (_) => _handleCategorySelect(null),
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.normal,
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
                      final isSelected = filter.selectedCategoryId == cat.id;
                      final isSensitive = cat.locked ||
                          cat.name.toLowerCase().contains('adult') ||
                          cat.name.toLowerCase().contains('xxx') ||
                          cat.name.toLowerCase().contains('18+');
                      final isLocked =
                          isSensitive && !_unlockedCategories.contains(cat.id);

                      return ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isLocked) ...[
                              const Icon(Icons.lock_rounded,
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
                              isSelected ? FontWeight.w700 : FontWeight.normal,
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
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: 20),

            // Movies Grid
            Expanded(
              child: moviesAsync.when(
                data: (moviesList) {
                  if (moviesList.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      childAspectRatio: 0.65,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: moviesList.length,
                    itemBuilder: (context, index) {
                      final item = moviesList[index];
                      return _buildMovieCard(context, item);
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Failed to load movies: $e',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovieCard(BuildContext context, ContentItemsTableData movie) {
    return _FocusableMovieCard(
      movie: movie,
      onTap: () => _showMovieDetail(context, movie),
      placeholderBuilder: _buildPosterPlaceholder,
    );
  }

  Widget _buildPosterPlaceholder(ContentItemsTableData movie) {
    return Container(
      color: AppColors.surfaceElevated,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_creation_rounded,
                color: Colors.white.withValues(alpha: 0.25), size: 36),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                movie.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.movie_filter_rounded,
              size: 54, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 14),
          const Text(
            'No Movies Found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add an Xtream Codes or M3U provider with movie content.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showMovieDetail(BuildContext context, ContentItemsTableData movie) {
    AdaptiveDetailsCoordinator.show(context, content: movie);
  }
}

// ---------------------------------------------------------------------------
// Sort & Filter Bar — shared pill-style control row
// ---------------------------------------------------------------------------

class _SortFilterBar extends StatelessWidget {
  final MovieSortOption sortBy;
  final int? filterYear;
  final double? minRating;
  final ValueChanged<MovieSortOption> onSortChanged;
  final ValueChanged<int?> onYearChanged;
  final ValueChanged<double?> onRatingChanged;
  final VoidCallback onReset;
  final bool hasActiveFilters;

  const _SortFilterBar({
    required this.sortBy,
    required this.filterYear,
    required this.minRating,
    required this.onSortChanged,
    required this.onYearChanged,
    required this.onRatingChanged,
    required this.onReset,
    required this.hasActiveFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Sort By dropdown pill
        _buildDropdownPill<MovieSortOption>(
          context: context,
          icon: Icons.sort_rounded,
          label: sortBy.label,
          isActive: sortBy != MovieSortOption.titleAZ,
          items: MovieSortOption.values
              .map((s) => PopupMenuItem(value: s, child: Text(s.label)))
              .toList(),
          onSelected: onSortChanged,
        ),

        const SizedBox(width: 8),

        // Year filter pill
        _buildDropdownPill<int?>(
          context: context,
          icon: Icons.calendar_month_rounded,
          label: filterYear != null ? '$filterYear' : 'Year',
          isActive: filterYear != null,
          items: [
            const PopupMenuItem(value: null, child: Text('All Years')),
            ...List.generate(
              6,
              (i) {
                final y = 2026 - i;
                return PopupMenuItem(value: y, child: Text('$y'));
              },
            ),
          ],
          onSelected: onYearChanged,
        ),

        const SizedBox(width: 8),

        // Rating filter pill
        _buildDropdownPill<double?>(
          context: context,
          icon: Icons.star_rounded,
          label: minRating != null
              ? '${minRating!.toStringAsFixed(0)}+ ★'
              : 'Rating',
          isActive: minRating != null,
          items: [
            const PopupMenuItem(value: null, child: Text('All Ratings')),
            const PopupMenuItem(value: 6.0, child: Text('6.0+ ★')),
            const PopupMenuItem(value: 7.0, child: Text('7.0+ ★')),
            const PopupMenuItem(value: 7.5, child: Text('7.5+ ★')),
            const PopupMenuItem(value: 8.0, child: Text('8.0+ ★')),
            const PopupMenuItem(value: 9.0, child: Text('9.0+ ★')),
          ],
          onSelected: onRatingChanged,
        ),

        if (hasActiveFilters) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: onReset,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                border:
                    Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.clear_rounded, color: Colors.redAccent, size: 13),
                  SizedBox(width: 4),
                  Text(
                    'Reset',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdownPill<T>({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isActive,
    required List<PopupMenuEntry<T>> items,
    required ValueChanged<T> onSelected,
  }) {
    return PopupMenuButton<T>(
      onSelected: onSelected,
      color: const Color(0xFF1E1E26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => items,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isActive ? AppColors.primary : Colors.white54,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.primary : Colors.white70,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 14,
              color: isActive ? AppColors.primary : Colors.white38,
            ),
          ],
        ),
      ),
    );
  }
}

class _MovieDetailSheet extends ConsumerStatefulWidget {
  final ContentItemsTableData movie;

  const _MovieDetailSheet({required this.movie});

  @override
  ConsumerState<_MovieDetailSheet> createState() => _MovieDetailSheetState();
}

class _MovieDetailSheetState extends ConsumerState<_MovieDetailSheet> {
  TmdbMetadata? _tmdb;
  bool _isLoadingTmdb = false;
  Map<String, dynamic>? _vodDetails;
  bool _isLoadingVod = false;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _fetchTmdbEnrichment();
    _fetchVodDetails();
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    final db = ref.read(databaseProvider);
    final fav = await db.isFavorite(
        widget.movie.playlistId, 'movie', widget.movie.providerId);
    if (mounted) setState(() => _isFavorite = fav);
  }

  Future<void> _toggleFavorite() async {
    final db = ref.read(databaseProvider);
    await db.toggleFavorite(
      FavoritesTableCompanion(
        playlistId: drift.Value(widget.movie.playlistId),
        contentId: drift.Value(widget.movie.id),
        providerId: drift.Value(widget.movie.providerId),
        type: const drift.Value('movie'),
        title: drift.Value(widget.movie.title),
        posterUrl: drift.Value(widget.movie.posterUrl),
        backdropUrl: drift.Value(widget.movie.backdropUrl),
      ),
    );
    if (mounted) {
      setState(() => _isFavorite = !_isFavorite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFavorite
              ? 'Added "${widget.movie.title}" to My List'
              : 'Removed "${widget.movie.title}" from My List'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _fetchVodDetails() async {
    final playlistId = widget.movie.playlistId;
    final db = ref.read(databaseProvider);
    final playlist = await db.getPlaylist(playlistId);
    if (playlist == null ||
        playlist.type != 'xtream' ||
        playlist.serverUrl == null ||
        playlist.username == null) {
      return;
    }

    final storage = ref.read(secureStorageProvider);
    final pass = await storage.getPlaylistCredentials(playlistId);
    if (pass == null) return;

    final creds = XtreamCredentials.normalized(
      serverUrl: playlist.serverUrl!,
      username: playlist.username!,
      password: pass,
    );
    final client = XtreamClient(ref.read(apiClientProvider).dio);

    setState(() => _isLoadingVod = true);
    try {
      final data = await client.getVodInfo(creds, widget.movie.providerId);
      if (mounted && data.isNotEmpty) {
        setState(() => _vodDetails = data);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingVod = false);
  }

  Future<void> _fetchTmdbEnrichment() async {
    final tmdbService = ref.read(tmdbServiceProvider);
    final apiKey = await tmdbService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) return;

    setState(() => _isLoadingTmdb = true);
    try {
      final meta = await tmdbService.searchMovie(
        widget.movie.title,
        year: widget.movie.releaseYear,
        apiKey: apiKey,
      );
      if (mounted && meta != null) {
        setState(() => _tmdb = meta);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingTmdb = false);
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.read(playerControllerProvider.notifier);
    final movie = widget.movie;
    final vodInfo =
        _vodDetails?['info'] is Map ? _vodDetails!['info'] as Map : null;

    final displayTitle = _tmdb?.title.isNotEmpty == true
        ? _tmdb!.title
        : (vodInfo?['name']?.toString() ?? movie.title);

    final displayPoster = _tmdb?.posterUrl ??
        vodInfo?['movie_image']?.toString() ??
        vodInfo?['cover_big']?.toString() ??
        movie.posterUrl;

    final displayBackdrop = _tmdb?.backdropUrl ??
        (vodInfo?['backdrop_path'] is List &&
                (vodInfo!['backdrop_path'] as List).isNotEmpty
            ? (vodInfo['backdrop_path'] as List).first.toString()
            : vodInfo?['backdrop_path']?.toString()) ??
        movie.backdropUrl;

    final displayRating = _tmdb?.rating ??
        (vodInfo?['rating'] != null
            ? double.tryParse(vodInfo!['rating'].toString())
            : null) ??
        movie.rating;

    final displayYear = _tmdb?.releaseYear ??
        movie.releaseYear ??
        (vodInfo?['releasedate'] != null
            ? DateTime.tryParse(vodInfo!['releasedate'].toString())?.year
            : (vodInfo?['year'] != null
                ? int.tryParse(vodInfo!['year'].toString())
                : null));

    final displayOverview = _tmdb?.overview ??
        vodInfo?['plot']?.toString() ??
        vodInfo?['description']?.toString();

    final displayDuration = vodInfo?['episode_run_time'] != null &&
            vodInfo!['episode_run_time'].toString() != '0'
        ? '${vodInfo['episode_run_time']} min'
        : (vodInfo?['duration']?.toString() ??
            (vodInfo?['duration_secs'] != null
                ? '${((vodInfo!['duration_secs'] as num) ~/ 60)} min'
                : null));

    final displayAgeRating = _tmdb?.ageRating ??
        vodInfo?['age']?.toString() ??
        vodInfo?['mpaa_rating']?.toString();

    final displayGenres = _tmdb?.genres.isNotEmpty == true
        ? _tmdb!.genres
        : (vodInfo?['genre']
                ?.toString()
                .split(RegExp(r'[,/;]'))
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList() ??
            <String>[]);

    final displayDirectors = _tmdb?.directors.isNotEmpty == true
        ? _tmdb!.directors
        : (vodInfo?['director']
                ?.toString()
                .split(RegExp(r'[,;]'))
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList() ??
            (vodInfo?['directors']
                    ?.toString()
                    .split(RegExp(r'[,;]'))
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList() ??
                <String>[]));

    final displayCastNames = _tmdb?.cast.isNotEmpty == true
        ? _tmdb!.cast.map((c) => c.name).toList()
        : (vodInfo?['actors']
                ?.toString()
                .split(RegExp(r'[,;]'))
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList() ??
            (vodInfo?['cast']
                    ?.toString()
                    .split(RegExp(r'[,;]'))
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList() ??
                <String>[]));

    final rawTrailer =
        _tmdb?.trailerUrl ?? vodInfo?['youtube_trailer']?.toString();
    String? trailerUrl;
    if (rawTrailer != null && rawTrailer.trim().isNotEmpty) {
      final t = rawTrailer.trim();
      trailerUrl = (t.startsWith('http://') || t.startsWith('https://'))
          ? t
          : 'https://www.youtube.com/watch?v=$t';
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(28),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: displayPoster != null
                      ? CachedNetworkImage(
                          imageUrl: displayPoster,
                          width: 125,
                          height: 185,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 125,
                            height: 185,
                            color: Colors.white12,
                            child: const Icon(Icons.movie_rounded,
                                color: Colors.white38),
                          ),
                        )
                      : Container(
                          width: 125,
                          height: 185,
                          color: Colors.white12,
                          child: const Icon(Icons.movie_rounded,
                              color: Colors.white38),
                        ),
                ),
                const SizedBox(width: 22),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          if (displayYear != null)
                            Text(
                              displayYear.toString(),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontSize: 13,
                              ),
                            ),
                          if (displayDuration != null &&
                              displayDuration.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                displayDuration,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (displayRating != null && displayRating > 0)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded,
                                    color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  displayRating.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          if (displayAgeRating != null &&
                              displayAgeRating.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white38),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                displayAgeRating,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (_isLoadingTmdb || _isLoadingVod)
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                  strokeWidth: 1.5, color: Colors.white54),
                            ),
                        ],
                      ),
                      if (displayGenres.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: displayGenres.map((g) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                g,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      if (displayDirectors.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Director: ${displayDirectors.join(', ')}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                      if (displayOverview != null &&
                          displayOverview.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          displayOverview,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          if (movie.streamUrl != null &&
                              movie.streamUrl!.isNotEmpty)
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                final item = MediaItem(
                                  id: movie.providerId,
                                  title: movie.title,
                                  type: MediaType.movie,
                                  posterUrl: displayPoster,
                                  backdropUrl: displayBackdrop,
                                  streamUrl: movie.streamUrl,
                                  playlistId: movie.playlistId,
                                  providerId: movie.providerId,
                                  contentDbId: movie.id,
                                );
                                player.playItem(item, startFullscreen: true);
                              },
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Play Movie'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          if (trailerUrl != null)
                            OutlinedButton.icon(
                              onPressed: () {
                                ExternalPlayerService.openUrl(trailerUrl!);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Opening trailer for "${movie.title}" in browser'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.smart_display_rounded,
                                  color: Colors.amber, size: 18),
                              label: const Text('Watch Trailer',
                                  style: TextStyle(color: Colors.white)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                side: const BorderSide(color: Colors.amber),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          OutlinedButton.icon(
                            onPressed: _toggleFavorite,
                            icon: Icon(
                              _isFavorite
                                  ? Icons.bookmark_added_rounded
                                  : Icons.bookmark_add_outlined,
                              color: _isFavorite
                                  ? AppColors.primary
                                  : Colors.white70,
                              size: 18,
                            ),
                            label: Text(
                              _isFavorite ? 'In My List' : 'Add to My List',
                              style: TextStyle(
                                  color: _isFavorite
                                      ? AppColors.primary
                                      : Colors.white),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              side: BorderSide(
                                color: _isFavorite
                                    ? AppColors.primary
                                    : Colors.white.withValues(alpha: 0.2),
                              ),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          if (movie.streamUrl != null &&
                              movie.streamUrl!.isNotEmpty)
                            OutlinedButton.icon(
                              onPressed: () {
                                ref
                                    .read(downloadNotifierProvider.notifier)
                                    .startDownload(
                                      id: movie.providerId,
                                      title: movie.title,
                                      streamUrl: movie.streamUrl!,
                                      posterUrl: displayPoster,
                                      extension: movie.containerExtension,
                                    );
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Downloading "${movie.title}" for offline playback'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.download_rounded,
                                  color: Colors.white70, size: 18),
                              label: const Text('Download',
                                  style: TextStyle(color: Colors.white)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                side: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.2)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
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

            // Cast Rail (TMDB with avatars or Provider names)
            if (_tmdb?.cast.isNotEmpty == true) ...[
              const SizedBox(height: 24),
              const Text(
                'Cast',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _tmdb!.cast.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, idx) {
                    final actor = _tmdb!.cast[idx];
                    return SizedBox(
                      width: 75,
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white12,
                            backgroundImage: actor.profileUrl != null
                                ? CachedNetworkImageProvider(actor.profileUrl!)
                                : null,
                            child: actor.profileUrl == null
                                ? const Icon(Icons.person,
                                    color: Colors.white38, size: 24)
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
                                fontWeight: FontWeight.w600),
                          ),
                          if (actor.character != null)
                            Text(
                              actor.character!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 10),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ] else if (displayCastNames.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text(
                'Cast',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: displayCastNames.take(10).map((actorName) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline_rounded,
                            size: 14, color: Colors.white54),
                        const SizedBox(width: 6),
                        Text(
                          actorName,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 11.5),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],

            // Recommendations Rail
            if (_tmdb?.recommendations.isNotEmpty == true) ...[
              const SizedBox(height: 20),
              const Text(
                'More Like This',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _tmdb!.recommendations.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, idx) {
                    final rec = _tmdb!.recommendations[idx];
                    return SizedBox(
                      width: 95,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: rec.posterUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: rec.posterUrl!,
                                    width: 95,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Container(
                                      width: 95,
                                      height: 120,
                                      color: Colors.white12,
                                      child: const Icon(Icons.movie,
                                          color: Colors.white24),
                                    ),
                                  )
                                : Container(
                                    width: 95,
                                    height: 120,
                                    color: Colors.white12,
                                    child: const Icon(Icons.movie,
                                        color: Colors.white24),
                                  ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rec.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _FocusableMovieCard extends StatefulWidget {
  final ContentItemsTableData movie;
  final VoidCallback onTap;
  final Widget Function(ContentItemsTableData) placeholderBuilder;

  const _FocusableMovieCard({
    required this.movie,
    required this.onTap,
    required this.placeholderBuilder,
  });

  @override
  State<_FocusableMovieCard> createState() => _FocusableMovieCardState();
}

class _FocusableMovieCardState extends State<_FocusableMovieCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  bool get _isActive => _isHovered || _isFocused;

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;

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
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          transform: Matrix4.diagonal3Values(
            _isFocused ? 1.06 : (_isHovered ? 1.04 : 1.0),
            _isFocused ? 1.06 : (_isHovered ? 1.04 : 1.0),
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
                blurRadius: _isFocused ? 20 : (_isHovered ? 16 : 8),
                offset: Offset(0, _isActive ? 6 : 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Poster
              if (movie.posterUrl != null && movie.posterUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: movie.posterUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => widget.placeholderBuilder(movie),
                )
              else
                widget.placeholderBuilder(movie),

              // Gradient scrim
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 90,
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
                ),
              ),

              // Play icon overlay on focus/hover
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

              // My List Quick Bookmark Button
              Positioned(
                top: 6,
                left: 6,
                child: Consumer(
                  builder: (context, ref, _) {
                    final db = ref.watch(databaseProvider);
                    return StreamBuilder<bool>(
                      stream: db.watchIsFavorite(
                          movie.playlistId, 'movie', movie.providerId),
                      builder: (context, snap) {
                        final isFav = snap.data ?? false;
                        return InkWell(
                          onTap: () async {
                            await db.toggleFavorite(
                              FavoritesTableCompanion(
                                playlistId: drift.Value(movie.playlistId),
                                contentId: drift.Value(movie.id),
                                providerId: drift.Value(movie.providerId),
                                type: const drift.Value('movie'),
                                title: drift.Value(movie.title),
                                posterUrl: drift.Value(movie.posterUrl),
                                backdropUrl: drift.Value(movie.backdropUrl),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFav
                                  ? Icons.bookmark_added_rounded
                                  : Icons.bookmark_add_outlined,
                              color: isFav ? AppColors.primary : Colors.white70,
                              size: 16,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Rating Badge
              if (movie.rating != null && movie.rating! > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 12),
                        const SizedBox(width: 3),
                        Text(
                          movie.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Title and year
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (movie.releaseYear != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        movie.releaseYear.toString(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
