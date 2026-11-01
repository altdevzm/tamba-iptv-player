import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../content_details/presentation/adaptive_details_coordinator.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/persistence/app_database.dart';
import 'package:drift/drift.dart' as drift;
import '../../../shared/models/media_item.dart';
import '../../player/data/player_controller.dart';
import '../../player/data/external_player_service.dart';
import 'series_notifier.dart';
import '../../../shared/services/tmdb_service.dart';
import '../../../core/persistence/database_provider.dart';
import '../../xtream/data/xtream_client.dart';
import '../../stalker/data/stalker_client.dart';
import '../../parental_lock/presentation/pin_prompt_dialog.dart';

class SeriesView extends ConsumerStatefulWidget {
  const SeriesView({super.key});

  @override
  ConsumerState<SeriesView> createState() => _SeriesViewState();
}

class _SeriesViewState extends ConsumerState<SeriesView> {
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
      ref.read(seriesFilterProvider.notifier).selectCategory(null);
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
        ref.read(seriesFilterProvider.notifier).selectCategory(cat.id);
      }
      return;
    }

    ref.read(seriesFilterProvider.notifier).selectCategory(cat.id);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(seriesCategoriesProvider);
    final seriesAsync = ref.watch(filteredSeriesProvider);
    final filter = ref.watch(seriesFilterProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;
    _syncSearchController(filter.searchQuery);

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
            // Header + Search
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TV Series',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 22 : 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Browse and stream on-demand television shows',
                        maxLines: isMobile ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isMobile)
                  SizedBox(
                    width: 260,
                    height: 42,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => ref
                          .read(seriesFilterProvider.notifier)
                          .setSearchQuery(val),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search TV series...',
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
                                      .read(seriesFilterProvider.notifier)
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
            _SeriesSortFilterBar(
              sortBy: filter.sortBy,
              filterYear: filter.filterYear,
              minRating: filter.minRating,
              onSortChanged: (s) =>
                  ref.read(seriesFilterProvider.notifier).setSortBy(s),
              onYearChanged: (y) =>
                  ref.read(seriesFilterProvider.notifier).setFilterYear(y),
              onRatingChanged: (r) =>
                  ref.read(seriesFilterProvider.notifier).setMinRating(r),
              onReset: () =>
                  ref.read(seriesFilterProvider.notifier).resetFilters(),
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
                          label: const Text('All Series'),
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

            // Series Grid
            Expanded(
              child: seriesAsync.when(
                data: (seriesList) {
                  if (seriesList.isEmpty) {
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
                    itemCount: seriesList.length,
                    itemBuilder: (context, index) {
                      final item = seriesList[index];
                      return _buildSeriesCard(context, item);
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(
                  child: Text(
                    'Failed to load series: $e',
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

  Widget _buildSeriesCard(BuildContext context, ContentItemsTableData series) {
    return _FocusableSeriesCard(
      series: series,
      onTap: () => _showSeriesDetail(context, series),
      placeholderBuilder: _buildPosterPlaceholder,
    );
  }

  Widget _buildPosterPlaceholder(ContentItemsTableData series) {
    return Container(
      color: AppColors.surfaceElevated,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tv_rounded,
                color: Colors.white.withValues(alpha: 0.25), size: 36),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                series.title,
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
          Icon(Icons.tv_off_rounded,
              size: 54, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 14),
          const Text(
            'No TV Series Found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add an Xtream Codes or M3U provider with series content.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _showSeriesDetail(BuildContext context, ContentItemsTableData series) {
    AdaptiveDetailsCoordinator.show(context, content: series);
  }
}

// ---------------------------------------------------------------------------
// Sort & Filter Bar for Series
// ---------------------------------------------------------------------------

class _SeriesSortFilterBar extends StatelessWidget {
  final SeriesSortOption sortBy;
  final int? filterYear;
  final double? minRating;
  final ValueChanged<SeriesSortOption> onSortChanged;
  final ValueChanged<int?> onYearChanged;
  final ValueChanged<double?> onRatingChanged;
  final VoidCallback onReset;
  final bool hasActiveFilters;

  const _SeriesSortFilterBar({
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
        _pill<SeriesSortOption>(
          context: context,
          icon: Icons.sort_rounded,
          label: sortBy.label,
          isActive: sortBy != SeriesSortOption.titleAZ,
          items: SeriesSortOption.values
              .map((s) => PopupMenuItem(value: s, child: Text(s.label)))
              .toList(),
          onSelected: onSortChanged,
        ),
        const SizedBox(width: 8),
        _pill<int?>(
          context: context,
          icon: Icons.calendar_month_rounded,
          label: filterYear != null ? '$filterYear' : 'Year',
          isActive: filterYear != null,
          items: [
            const PopupMenuItem(value: null, child: Text('All Years')),
            ...List.generate(6, (i) {
              final y = 2026 - i;
              return PopupMenuItem(value: y, child: Text('$y'));
            }),
          ],
          onSelected: onYearChanged,
        ),
        const SizedBox(width: 8),
        _pill<double?>(
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

  Widget _pill<T>({
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
            Icon(icon,
                size: 13, color: isActive ? AppColors.primary : Colors.white54),
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
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 14, color: isActive ? AppColors.primary : Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _SeriesDetailSheet extends ConsumerStatefulWidget {
  final ContentItemsTableData series;

  const _SeriesDetailSheet({required this.series});

  @override
  ConsumerState<_SeriesDetailSheet> createState() => _SeriesDetailSheetState();
}

class _SeriesDetailSheetState extends ConsumerState<_SeriesDetailSheet> {
  TmdbMetadata? _tmdb;
  bool _isLoadingTmdb = false;
  bool _isLoadingEpisodes = false;
  Map<String, List<Map<String, dynamic>>> _episodesBySeason = {};
  String? _selectedSeason;
  String? _fetchEpisodesError;
  Map<String, dynamic>? _seriesDetailsInfo;
  bool _isFavorite = false;
  XtreamCredentials? _xtreamCreds;
  XtreamClient? _xtreamClient;
  StalkerCredentials? _stalkerCreds;
  StalkerClient? _stalkerClient;

  @override
  void initState() {
    super.initState();
    _fetchTmdbEnrichment();
    _fetchEpisodes();
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    final db = ref.read(databaseProvider);
    final fav = await db.isFavorite(
        widget.series.playlistId, 'series', widget.series.providerId);
    if (mounted) setState(() => _isFavorite = fav);
  }

  Future<void> _toggleFavorite() async {
    final db = ref.read(databaseProvider);
    await db.toggleFavorite(
      FavoritesTableCompanion(
        playlistId: drift.Value(widget.series.playlistId),
        contentId: drift.Value(widget.series.id),
        providerId: drift.Value(widget.series.providerId),
        type: const drift.Value('series'),
        title: drift.Value(widget.series.title),
        posterUrl: drift.Value(widget.series.posterUrl),
        backdropUrl: drift.Value(widget.series.backdropUrl),
      ),
    );
    if (mounted) {
      setState(() => _isFavorite = !_isFavorite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFavorite
              ? 'Added "${widget.series.title}" to My List'
              : 'Removed "${widget.series.title}" from My List'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _fetchTmdbEnrichment() async {
    final tmdbService = ref.read(tmdbServiceProvider);
    final apiKey = await tmdbService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) return;

    setState(() => _isLoadingTmdb = true);
    try {
      final meta = await tmdbService.searchSeries(
        widget.series.title,
        apiKey: apiKey,
      );
      if (mounted && meta != null) {
        setState(() => _tmdb = meta);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingTmdb = false);
  }

  Future<void> _fetchEpisodes() async {
    final playlistId = widget.series.playlistId;
    final db = ref.read(databaseProvider);
    final playlist = await db.getPlaylist(playlistId);
    if (playlist == null) return;

    final dio = ref.read(apiClientProvider).dio;

    if (playlist.type == 'xtream') {
      final storage = ref.read(secureStorageProvider);
      final password = await storage.getPlaylistCredentials(playlistId);
      if (password == null ||
          playlist.serverUrl == null ||
          playlist.username == null) {
        if (mounted) {
          setState(() {
            _fetchEpisodesError =
                'Playlist credentials missing. Please re-enter credentials.';
            _isLoadingEpisodes = false;
          });
        }
        return;
      }

      final creds = XtreamCredentials.normalized(
        serverUrl: playlist.serverUrl!,
        username: playlist.username!,
        password: password,
      );

      final client = XtreamClient(dio);

      setState(() {
        _isLoadingEpisodes = true;
        _fetchEpisodesError = null;
      });
      try {
        final info =
            await client.getSeriesInfo(creds, widget.series.providerId);
        final rawEp = info['episodes'];
        final parsed = <String, List<Map<String, dynamic>>>{};

        if (rawEp is Map) {
          // Standard format: {"1": [ {...ep}, ... ], "2": [...] }
          rawEp.forEach((k, v) {
            if (v is List) {
              final eps = v
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
              if (eps.isNotEmpty) parsed[k.toString()] = eps;
            }
          });
        } else if (rawEp is List) {
          // Flat list format — group by season_num field
          for (final entry in rawEp) {
            if (entry is! Map) continue;
            final ep = Map<String, dynamic>.from(entry);
            final season =
                ep['season_num']?.toString() ?? ep['season']?.toString() ?? '1';
            parsed.putIfAbsent(season, () => []).add(ep);
          }
        }

        if (mounted) {
          setState(() {
            _episodesBySeason = parsed;
            _selectedSeason = parsed.keys.isNotEmpty ? parsed.keys.first : null;
            _seriesDetailsInfo = info['info'] is Map
                ? Map<String, dynamic>.from(info['info'])
                : null;
            _xtreamCreds = creds;
            _xtreamClient = client;
            if (parsed.isEmpty) {
              _fetchEpisodesError = 'No episodes returned by provider.';
            }
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _fetchEpisodesError = e.toString());
        }
      }
      if (mounted) setState(() => _isLoadingEpisodes = false);
    } else if (playlist.type == 'stalker' &&
        playlist.serverUrl != null &&
        playlist.macAddress != null) {
      final stalkerCreds = StalkerCredentials(
        serverUrl: playlist.serverUrl!,
        macAddress: playlist.macAddress!,
      );
      final client = StalkerClient(dio);

      setState(() => _isLoadingEpisodes = true);
      try {
        await client.handshake(stalkerCreds);
        final rawEpisodes = await client.getSeriesEpisodes(
            stalkerCreds, widget.series.providerId);
        if (mounted && rawEpisodes.isNotEmpty) {
          final parsed = <String, List<Map<String, dynamic>>>{};
          for (final ep in rawEpisodes) {
            final season =
                ep['season']?.toString() ?? ep['season_id']?.toString() ?? '1';
            parsed.putIfAbsent(season, () => []).add(ep);
          }
          setState(() {
            _episodesBySeason = parsed;
            _selectedSeason = parsed.keys.isNotEmpty ? parsed.keys.first : null;
            _stalkerCreds = stalkerCreds;
            _stalkerClient = client;
          });
        }
      } catch (_) {}
      if (mounted) setState(() => _isLoadingEpisodes = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.read(playerControllerProvider.notifier);
    final series = widget.series;
    final displayPoster = _tmdb?.posterUrl ??
        _seriesDetailsInfo?['cover']?.toString() ??
        series.posterUrl;
    final displayBackdrop = _tmdb?.backdropUrl ??
        (_seriesDetailsInfo?['backdrop_path'] is List &&
                (_seriesDetailsInfo!['backdrop_path'] as List).isNotEmpty
            ? (_seriesDetailsInfo!['backdrop_path'] as List).first.toString()
            : _seriesDetailsInfo?['backdrop_path']?.toString()) ??
        series.backdropUrl;
    final displayRating = _tmdb?.rating ??
        (_seriesDetailsInfo?['rating'] != null
            ? double.tryParse(_seriesDetailsInfo!['rating'].toString())
            : null) ??
        series.rating;
    final displayOverview = _tmdb?.overview ??
        _seriesDetailsInfo?['plot']?.toString() ??
        _seriesDetailsInfo?['description']?.toString();
    final displayGenres = _tmdb?.genres.isNotEmpty == true
        ? _tmdb!.genres
        : (_seriesDetailsInfo?['genre']
                ?.toString()
                .split(RegExp(r'[,/;]'))
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList() ??
            <String>[]);
    final displayCreators = _tmdb?.directors.isNotEmpty == true
        ? _tmdb!.directors
        : (_seriesDetailsInfo?['director']
                ?.toString()
                .split(RegExp(r'[,;]'))
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList() ??
            (_seriesDetailsInfo?['cast']
                    ?.toString()
                    .split(RegExp(r'[,;]'))
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList() ??
                <String>[]));

    final rawTrailer =
        _tmdb?.trailerUrl ?? _seriesDetailsInfo?['youtube_trailer']?.toString();
    String? trailerUrl;
    if (rawTrailer != null && rawTrailer.trim().isNotEmpty) {
      final t = rawTrailer.trim();
      trailerUrl = (t.startsWith('http://') || t.startsWith('https://'))
          ? t
          : 'https://www.youtube.com/watch?v=$t';
    }

    final currentEpisodes = _selectedSeason != null
        ? (_episodesBySeason[_selectedSeason] ?? [])
        : <Map<String, dynamic>>[];

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
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
                        width: 110,
                        height: 160,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 110,
                          height: 160,
                          color: Colors.white12,
                          child: const Icon(Icons.tv_rounded,
                              color: Colors.white38),
                        ),
                      )
                    : Container(
                        width: 110,
                        height: 160,
                        color: Colors.white12,
                        child:
                            const Icon(Icons.tv_rounded, color: Colors.white38),
                      ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tmdb?.title.isNotEmpty == true
                          ? _tmdb!.title
                          : series.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (series.releaseYear != null ||
                            _tmdb?.releaseYear != null)
                          Text(
                            (_tmdb?.releaseYear ?? series.releaseYear)
                                .toString(),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        if (displayRating != null && displayRating > 0) ...[
                          const SizedBox(width: 12),
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
                        if (_tmdb?.ageRating != null &&
                            _tmdb!.ageRating!.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white38),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _tmdb!.ageRating!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        if (_isLoadingTmdb || _isLoadingEpisodes) ...[
                          const SizedBox(width: 12),
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: Colors.white54),
                          ),
                        ],
                      ],
                    ),
                    if (displayGenres.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: displayGenres.map((g) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              g,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 10.5,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    if (displayCreators.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Creators: ${displayCreators.join(', ')}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                    if (displayOverview != null &&
                        displayOverview.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        displayOverview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        if (series.streamUrl != null &&
                            series.streamUrl!.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              final item = MediaItem(
                                id: series.providerId,
                                title: series.title,
                                type: MediaType.series,
                                posterUrl: displayPoster,
                                backdropUrl: displayBackdrop,
                                streamUrl: series.streamUrl,
                                playlistId: series.playlistId,
                                providerId: series.providerId,
                                contentDbId: series.id,
                              );
                              player.playItem(item, startFullscreen: true);
                            },
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Play Series'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 11),
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
                                      'Opening trailer for "${series.title}" in browser'),
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
                                  horizontal: 16, vertical: 11),
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
                                horizontal: 16, vertical: 11),
                            side: BorderSide(
                              color: _isFavorite
                                  ? AppColors.primary
                                  : Colors.white.withValues(alpha: 0.2),
                            ),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_tmdb?.cast.isNotEmpty == true) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _tmdb!.cast.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, idx) {
                  final actor = _tmdb!.cast[idx];
                  return Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white12,
                        backgroundImage: actor.profileUrl != null
                            ? CachedNetworkImageProvider(actor.profileUrl!)
                            : null,
                        child: actor.profileUrl == null
                            ? const Icon(Icons.person,
                                color: Colors.white38, size: 18)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            actor.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                          if (actor.character != null)
                            Text(
                              actor.character!,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 10),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 14),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),

          // Seasons Tabs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Seasons & Episodes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_isLoadingEpisodes)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (_episodesBySeason.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _episodesBySeason.keys.map((season) {
                  final isSelected = season == _selectedSeason;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('Season $season'),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedSeason = season);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 10),

          // Episodes List with Widescreen Thumbnails & Full Metadata
          Expanded(
            child: currentEpisodes.isNotEmpty
                ? ListView.separated(
                    itemCount: currentEpisodes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final ep = currentEpisodes[idx];
                      final epTitle =
                          ep['title']?.toString() ?? 'Episode ${idx + 1}';
                      final epNum =
                          ep['episode_num']?.toString() ?? '${idx + 1}';
                      final rawExt =
                          ep['container_extension']?.toString() ?? '';
                      final containerExt = rawExt.isNotEmpty ? rawExt : 'mp4';
                      final epId = ep['id']?.toString() ??
                          ep['stream_id']?.toString() ??
                          '';

                      final epInfo =
                          ep['info'] is Map ? ep['info'] as Map : null;
                      final rawImg = epInfo?['movie_image']?.toString() ??
                          ep['movie_image']?.toString() ??
                          epInfo?['cover']?.toString() ??
                          ep['cover']?.toString() ??
                          (epInfo?['still_path'] != null
                              ? 'https://image.tmdb.org/t/p/w300${epInfo!['still_path']}'
                              : null) ??
                          (ep['still_path'] != null
                              ? 'https://image.tmdb.org/t/p/w300${ep['still_path']}'
                              : null);

                      final epThumbnail = (rawImg != null &&
                              rawImg.trim().isNotEmpty &&
                              rawImg.startsWith('http'))
                          ? rawImg.trim()
                          : null;

                      final epPlot = epInfo?['plot']?.toString() ??
                          ep['plot']?.toString() ??
                          epInfo?['description']?.toString() ??
                          ep['description']?.toString();

                      final epDuration = epInfo?['duration']?.toString() ??
                          (epInfo?['duration_secs'] != null
                              ? '${((epInfo!['duration_secs'] as num) ~/ 60)} min'
                              : null);

                      final epRating = epInfo?['rating'] != null
                          ? double.tryParse(epInfo!['rating'].toString())
                          : null;

                      void playThisEpisode() async {
                        final nav = Navigator.of(context);
                        String? streamUrl;
                        if (_xtreamCreds != null &&
                            _xtreamClient != null &&
                            epId.isNotEmpty) {
                          streamUrl = _xtreamClient!.buildSeriesStreamUrl(
                              _xtreamCreds!, epId, containerExt);
                        } else if (_stalkerCreds != null &&
                            _stalkerClient != null) {
                          final cmd = ep['cmd']?.toString();
                          if (cmd != null && cmd.isNotEmpty) {
                            streamUrl = await _stalkerClient!.createLink(
                                _stalkerCreds!,
                                type: 'vod',
                                cmd: cmd);
                          }
                        }

                        if (streamUrl != null &&
                            streamUrl.isNotEmpty &&
                            mounted) {
                          nav.pop();
                          final item = MediaItem(
                            id: epId.isNotEmpty
                                ? epId
                                : (ep['cmd']?.toString() ?? 'ep_$idx'),
                            title:
                                '${series.title} - S$_selectedSeason E$epNum: $epTitle',
                            type: MediaType.series,
                            posterUrl: epThumbnail ?? displayPoster,
                            backdropUrl: displayBackdrop,
                            streamUrl: streamUrl,
                            playlistId: series.playlistId,
                            providerId: epId.isNotEmpty
                                ? epId
                                : (ep['cmd']?.toString() ?? 'ep_$idx'),
                            seriesProviderId: series.providerId,
                            seasonNumber: int.tryParse(_selectedSeason ?? ''),
                            episodeNumber: int.tryParse(epNum),
                          );
                          player.playItem(item, startFullscreen: true);
                        }
                      }

                      return InkWell(
                        onTap: playThisEpisode,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.07)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Thumbnail with EP Badge & Play Icon ──
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 125,
                                      height: 72,
                                      color: Colors.white10,
                                      child: epThumbnail != null
                                          ? CachedNetworkImage(
                                              imageUrl: epThumbnail,
                                              width: 125,
                                              height: 72,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) =>
                                                  _buildEpisodeFallback(
                                                      epNum, displayPoster),
                                              placeholder: (_, __) => Container(
                                                  color: Colors.white12),
                                            )
                                          : _buildEpisodeFallback(
                                              epNum, displayPoster),
                                    ),
                                    // Play icon overlay
                                    Positioned.fill(
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.black
                                                .withValues(alpha: 0.5),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Episode number badge
                                    Positioned(
                                      bottom: 4,
                                      left: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.75),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'EP $epNum',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),

                              // ── Episode Info (Title, Duration, Rating, Plot) ──
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            epTitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        if (epDuration != null &&
                                            epDuration.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            epDuration,
                                            style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.5),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                        if (epRating != null &&
                                            epRating > 0) ...[
                                          const SizedBox(width: 8),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.star_rounded,
                                                  color: Colors.amber,
                                                  size: 12),
                                              const SizedBox(width: 2),
                                              Text(
                                                epRating.toStringAsFixed(1),
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (epPlot != null &&
                                        epPlot.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        epPlot,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.65),
                                          fontSize: 12,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // ── Play Action Button ──
                              IconButton(
                                icon: const Icon(Icons.play_circle_fill_rounded,
                                    color: AppColors.primary, size: 30),
                                onPressed: playThisEpisode,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        _isLoadingEpisodes
                            ? 'Loading episodes from provider...'
                            : (_fetchEpisodesError ??
                                'No episodes found for this series.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _fetchEpisodesError != null
                              ? Colors.redAccent
                              : Colors.white.withValues(alpha: 0.4),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEpisodeFallback(String epNum, String? poster) {
    if (poster != null && poster.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: poster,
        width: 125,
        height: 72,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _buildEpisodeNumBadge(epNum),
      );
    }
    return _buildEpisodeNumBadge(epNum);
  }

  Widget _buildEpisodeNumBadge(String epNum) {
    return Container(
      width: 125,
      height: 72,
      color: Colors.white.withValues(alpha: 0.08),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tv_rounded, color: Colors.white38, size: 22),
            const SizedBox(height: 4),
            Text(
              'Episode $epNum',
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusableSeriesCard extends StatefulWidget {
  final ContentItemsTableData series;
  final VoidCallback onTap;
  final Widget Function(ContentItemsTableData) placeholderBuilder;

  const _FocusableSeriesCard({
    required this.series,
    required this.onTap,
    required this.placeholderBuilder,
  });

  @override
  State<_FocusableSeriesCard> createState() => _FocusableSeriesCardState();
}

class _FocusableSeriesCardState extends State<_FocusableSeriesCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  bool get _isActive => _isHovered || _isFocused;

  @override
  Widget build(BuildContext context) {
    final series = widget.series;

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
              if (series.posterUrl != null && series.posterUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: series.posterUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      widget.placeholderBuilder(series),
                )
              else
                widget.placeholderBuilder(series),

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
                          series.playlistId, 'series', series.providerId),
                      builder: (context, snap) {
                        final isFav = snap.data ?? false;
                        return InkWell(
                          onTap: () async {
                            await db.toggleFavorite(
                              FavoritesTableCompanion(
                                playlistId: drift.Value(series.playlistId),
                                contentId: drift.Value(series.id),
                                providerId: drift.Value(series.providerId),
                                type: const drift.Value('series'),
                                title: drift.Value(series.title),
                                posterUrl: drift.Value(series.posterUrl),
                                backdropUrl: drift.Value(series.backdropUrl),
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
              if (series.rating != null && series.rating! > 0)
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
                          series.rating!.toStringAsFixed(1),
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
                      series.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (series.releaseYear != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        series.releaseYear.toString(),
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
