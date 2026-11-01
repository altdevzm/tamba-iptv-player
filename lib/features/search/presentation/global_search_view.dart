import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/persistence/app_database.dart';
import '../../../core/persistence/database_provider.dart';
import '../../content_details/presentation/adaptive_details_coordinator.dart';

enum SearchScope {
  all,
  live,
  movies,
  series,
}

extension SearchScopeLabel on SearchScope {
  String get label {
    switch (this) {
      case SearchScope.all:
        return 'All Content';
      case SearchScope.live:
        return 'Live TV';
      case SearchScope.movies:
        return 'Movies';
      case SearchScope.series:
        return 'TV Shows';
    }
  }

  IconData get icon {
    switch (this) {
      case SearchScope.all:
        return Icons.auto_awesome_rounded;
      case SearchScope.live:
        return Icons.live_tv_rounded;
      case SearchScope.movies:
        return Icons.movie_rounded;
      case SearchScope.series:
        return Icons.tv_rounded;
    }
  }
}

class GlobalSearchState {
  final String query;
  final SearchScope scope;
  final List<String> recentSearches;

  const GlobalSearchState({
    this.query = '',
    this.scope = SearchScope.all,
    this.recentSearches = const [],
  });

  GlobalSearchState copyWith({
    String? query,
    SearchScope? scope,
    List<String>? recentSearches,
  }) {
    return GlobalSearchState(
      query: query ?? this.query,
      scope: scope ?? this.scope,
      recentSearches: recentSearches ?? this.recentSearches,
    );
  }
}

class GlobalSearchNotifier extends StateNotifier<GlobalSearchState> {
  GlobalSearchNotifier() : super(const GlobalSearchState());

  void setQuery(String q) {
    state = state.copyWith(query: q);
  }

  void setScope(SearchScope s) {
    state = state.copyWith(scope: s);
  }

  void addRecentSearch(String q) {
    final clean = q.trim();
    if (clean.isEmpty) return;
    final updated = [
      clean,
      ...state.recentSearches
          .where((s) => s.toLowerCase() != clean.toLowerCase())
    ].take(8).toList();
    state = state.copyWith(recentSearches: updated);
  }

  void clearRecentSearches() {
    state = state.copyWith(recentSearches: []);
  }
}

final globalSearchProvider =
    StateNotifierProvider<GlobalSearchNotifier, GlobalSearchState>((ref) {
  return GlobalSearchNotifier();
});

/// Intelligent Multi-Word Search Provider with Exact/Prefix Match Ranking
final globalSearchResultsProvider =
    StreamProvider.autoDispose<Map<String, List<ContentItemsTableData>>>((ref) {
  final search = ref.watch(globalSearchProvider);
  final db = ref.watch(databaseProvider);
  final activePlaylistId = ref.watch(activePlaylistIdProvider);

  final rawQuery = search.query.trim().toLowerCase();
  if (rawQuery.isEmpty) {
    return Stream.value({'live': [], 'movie': [], 'series': []});
  }

  // Split query into multi-word search tokens
  final tokens =
      rawQuery.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

  var query = db.select(db.contentItemsTable);
  if (activePlaylistId != null) {
    query = query..where((t) => t.playlistId.equals(activePlaylistId));
  }

  // Scope filter at SQL level
  switch (search.scope) {
    case SearchScope.live:
      query = query..where((t) => t.type.equals('live'));
      break;
    case SearchScope.movies:
      query = query..where((t) => t.type.equals('movie'));
      break;
    case SearchScope.series:
      query = query..where((t) => t.type.equals('series'));
      break;
    case SearchScope.all:
      break;
  }

  return query.watch().map((allItems) {
    final matching = <ContentItemsTableData>[];

    for (final item in allItems) {
      final title = item.title.toLowerCase();
      // Match if all search tokens are found in the title
      bool matches = true;
      for (final token in tokens) {
        if (!title.contains(token)) {
          matches = false;
          break;
        }
      }
      if (matches) {
        matching.add(item);
      }
    }

    // Rank exact matches above partial matches
    matching.sort((a, b) {
      final aTitle = a.title.toLowerCase();
      final bTitle = b.title.toLowerCase();

      int scoreA = 0;
      if (aTitle == rawQuery) {
        scoreA = 100;
      } else if (aTitle.startsWith(rawQuery)) {
        scoreA = 80;
      } else if (aTitle.contains(rawQuery)) {
        scoreA = 60;
      } else {
        scoreA = 40;
      }

      int scoreB = 0;
      if (bTitle == rawQuery) {
        scoreB = 100;
      } else if (bTitle.startsWith(rawQuery)) {
        scoreB = 80;
      } else if (bTitle.contains(rawQuery)) {
        scoreB = 60;
      } else {
        scoreB = 40;
      }

      if (scoreA != scoreB) return scoreB.compareTo(scoreA);

      // Secondary sort: rating descending, then release year descending
      final ratingCompare = (b.rating ?? 0).compareTo(a.rating ?? 0);
      if (ratingCompare != 0) return ratingCompare;
      return (b.releaseYear ?? 0).compareTo(a.releaseYear ?? 0);
    });

    final grouped = <String, List<ContentItemsTableData>>{
      'live': [],
      'movie': [],
      'series': [],
    };
    for (final item in matching) {
      grouped.putIfAbsent(item.type, () => []).add(item);
    }
    return grouped;
  });
});

class GlobalSearchView extends ConsumerStatefulWidget {
  const GlobalSearchView({super.key});

  @override
  ConsumerState<GlobalSearchView> createState() => _GlobalSearchViewState();
}

class _GlobalSearchViewState extends ConsumerState<GlobalSearchView> {
  late final TextEditingController _controller;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    final initQuery = ref.read(globalSearchProvider).query;
    _controller = TextEditingController(text: initQuery);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 280), () {
      ref.read(globalSearchProvider.notifier).setQuery(val);
      if (val.trim().length >= 3) {
        ref.read(globalSearchProvider.notifier).addRecentSearch(val);
      }
    });
    setState(() {});
  }

  void _submitSearch(String val) {
    _debounceTimer?.cancel();
    ref.read(globalSearchProvider.notifier).setQuery(val);
    ref.read(globalSearchProvider.notifier).addRecentSearch(val);
    setState(() {});
  }

  void _selectSuggestion(String text) {
    _controller.text = text;
    _submitSearch(text);
  }

  @override
  Widget build(BuildContext context) {
    final search = ref.watch(globalSearchProvider);
    final resultsAsync = ref.watch(globalSearchResultsProvider);
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
            // ── Header & Search Input Row ──
            if (!isMobile)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Universal Search',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Find channels, feature films, TV shows & episodes across all playlists',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                  _buildSearchInput(width: 380),
                ],
              )
            else ...[
              const Text(
                'Universal Search',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],

            const SizedBox(height: 16),

            // ── Content Type Scope Filter Tabs ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: SearchScope.values.map((scope) {
                  final isSelected = search.scope == scope;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(scope.icon,
                              size: 14,
                              color:
                                  isSelected ? Colors.white : Colors.white60),
                          const SizedBox(width: 6),
                          Text(scope.label),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (_) => ref
                          .read(globalSearchProvider.notifier)
                          .setScope(scope),
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 18),

            // ── Results or Recent Searches / Empty State ──
            Expanded(
              child: resultsAsync.when(
                data: (groups) {
                  final liveList = groups['live'] ?? [];
                  final movieList = groups['movie'] ?? [];
                  final seriesList = groups['series'] ?? [];
                  final totalCount =
                      liveList.length + movieList.length + seriesList.length;

                  // Empty query state -> show suggestions & recent searches
                  if (search.query.trim().isEmpty) {
                    return _buildEmptyQuerySuggestions(search);
                  }

                  // 0 matches found state
                  if (totalCount == 0) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.search_off_rounded,
                              size: 64,
                              color: Colors.white.withValues(alpha: 0.2)),
                          const SizedBox(height: 16),
                          Text(
                            'No results found for "${search.query}"',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Try different keywords, check spelling, or select "All Content".',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 13),
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: () {
                              _controller.clear();
                              _onSearchChanged('');
                            },
                            icon: const Icon(Icons.clear_all_rounded, size: 16),
                            label: const Text('Clear Search'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Render Grouped Search Results
                  return ListView(
                    children: [
                      // Live Channels Section
                      if (liveList.isNotEmpty &&
                          (search.scope == SearchScope.all ||
                              search.scope == SearchScope.live)) ...[
                        _buildSectionHeader(
                            'Live TV Channels (${liveList.length})'),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: liveList.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, idx) {
                              final ch = liveList[idx];
                              return _buildChannelSearchCard(ch);
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // Movies Section
                      if (movieList.isNotEmpty &&
                          (search.scope == SearchScope.all ||
                              search.scope == SearchScope.movies)) ...[
                        _buildSectionHeader('Movies (${movieList.length})'),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 230,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: movieList.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 14),
                            itemBuilder: (context, idx) {
                              final m = movieList[idx];
                              return _buildMediaSearchCard(m);
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // TV Series Section
                      if (seriesList.isNotEmpty &&
                          (search.scope == SearchScope.all ||
                              search.scope == SearchScope.series)) ...[
                        _buildSectionHeader('TV Series (${seriesList.length})'),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 230,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: seriesList.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 14),
                            itemBuilder: (context, idx) {
                              final s = seriesList[idx];
                              return _buildMediaSearchCard(s);
                            },
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ],
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => Center(
                  child: Text('Search error: $e',
                      style: const TextStyle(color: Colors.redAccent)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchInput({required double width}) {
    return SizedBox(
      width: width,
      height: 44,
      child: TextField(
        controller: _controller,
        autofocus: false,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged: _onSearchChanged,
        onSubmitted: _submitSearch,
        decoration: InputDecoration(
          hintText: 'Type title, channel, genre, or keyword...',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          prefixIcon:
              const Icon(Icons.search_rounded, color: Colors.white60, size: 20),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: Colors.white54, size: 18),
                  onPressed: () {
                    _controller.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildEmptyQuerySuggestions(GlobalSearchState search) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (search.recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Searches',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => ref
                      .read(globalSearchProvider.notifier)
                      .clearRecentSearches(),
                  child: const Text('Clear All',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: search.recentSearches.map((s) {
                return ActionChip(
                  avatar: const Icon(Icons.history_rounded,
                      size: 14, color: Colors.white54),
                  label: Text(s),
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
                  labelStyle:
                      const TextStyle(color: Colors.white70, fontSize: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side:
                        BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  onPressed: () => _selectSuggestion(s),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
          ],
          const Text(
            'Suggested Discoveries',
            style: TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'Action',
              'News',
              '4K UHD',
              '2026',
              'Comedy',
              'Sports',
              'Sci-Fi',
              'Drama',
            ].map((tag) {
              return ActionChip(
                avatar: const Icon(Icons.trending_up_rounded,
                    size: 14, color: AppColors.primary),
                label: Text(tag),
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                labelStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                onPressed: () => _selectSuggestion(tag),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelSearchCard(ContentItemsTableData ch) {
    return InkWell(
      onTap: () => AdaptiveDetailsCoordinator.show(context, content: ch),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF191922),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            if (ch.posterUrl != null && ch.posterUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: ch.posterUrl!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => _channelFallback(ch.title),
                ),
              )
            else
              _channelFallback(ch.title),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    ch.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Row(
                    children: [
                      Icon(Icons.circle, size: 6, color: Colors.redAccent),
                      SizedBox(width: 4),
                      Text(
                        'LIVE TV',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSearchCard(ContentItemsTableData item) {
    return InkWell(
      onTap: () => AdaptiveDetailsCoordinator.show(context, content: item),
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 136,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (item.posterUrl != null && item.posterUrl!.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: item.posterUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _mediaFallback(item.title),
                      )
                    else
                      _mediaFallback(item.title),

                    // Rating badge
                    if (item.rating != null && item.rating! > 0)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 11, color: Colors.amber),
                              const SizedBox(width: 2),
                              Text(
                                item.rating!.toStringAsFixed(1),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
            if (item.releaseYear != null)
              Text(
                '${item.releaseYear}',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  Widget _channelFallback(String title) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0].toUpperCase() : 'TV',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _mediaFallback(String title) {
    return Container(
      color: const Color(0xFF1E1E26),
      padding: const EdgeInsets.all(6),
      child: Center(
        child: Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ),
    );
  }
}
