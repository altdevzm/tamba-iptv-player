import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/persistence/app_database.dart';
import '../../../core/persistence/database_provider.dart';

// ---------------------------------------------------------------------------
// Sort Enum
// ---------------------------------------------------------------------------

enum SeriesSortOption {
  titleAZ,
  titleZA,
  ratingHigh,
  ratingLow,
  yearNewest,
  yearOldest,
}

extension SeriesSortOptionLabel on SeriesSortOption {
  String get label {
    switch (this) {
      case SeriesSortOption.titleAZ:
        return 'Title A–Z';
      case SeriesSortOption.titleZA:
        return 'Title Z–A';
      case SeriesSortOption.ratingHigh:
        return 'Top Rated';
      case SeriesSortOption.ratingLow:
        return 'Lowest Rated';
      case SeriesSortOption.yearNewest:
        return 'Newest';
      case SeriesSortOption.yearOldest:
        return 'Oldest';
    }
  }
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class SeriesFilterState {
  final int? selectedCategoryId;
  final String searchQuery;
  final SeriesSortOption sortBy;
  final int? filterYear;
  final double? minRating;

  const SeriesFilterState({
    this.selectedCategoryId,
    this.searchQuery = '',
    this.sortBy = SeriesSortOption.titleAZ,
    this.filterYear,
    this.minRating,
  });

  SeriesFilterState copyWith({
    int? selectedCategoryId,
    bool clearCategory = false,
    String? searchQuery,
    SeriesSortOption? sortBy,
    int? filterYear,
    bool clearYear = false,
    double? minRating,
    bool clearRating = false,
  }) {
    return SeriesFilterState(
      selectedCategoryId:
          clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      filterYear: clearYear ? null : (filterYear ?? this.filterYear),
      minRating: clearRating ? null : (minRating ?? this.minRating),
    );
  }

  bool get hasActiveFilters =>
      filterYear != null || minRating != null || sortBy != SeriesSortOption.titleAZ;
}

class SeriesNotifier extends StateNotifier<SeriesFilterState> {
  SeriesNotifier() : super(const SeriesFilterState());

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

  void setSortBy(SeriesSortOption sort) {
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
    state = const SeriesFilterState();
  }
}

final seriesFilterProvider =
    StateNotifierProvider<SeriesNotifier, SeriesFilterState>((ref) {
  return SeriesNotifier();
});

/// Watches all series categories for the active playlist
final seriesCategoriesProvider =
    StreamProvider.autoDispose<List<CategoriesTableData>>((ref) {
  final db = ref.watch(databaseProvider);
  final activePlaylistId = ref.watch(activePlaylistIdProvider);

  if (activePlaylistId == null) {
    return (db.select(db.categoriesTable)
          ..where((t) => t.type.equals('series')))
        .watch();
  }

  return (db.select(db.categoriesTable)
        ..where((t) => t.playlistId.equals(activePlaylistId))
        ..where((t) => t.type.equals('series')))
      .watch();
});

/// Watches series content items matching the active filter and search query
/// using SQLite-level filtering, sorting, and row limits to avoid OOM on
/// massive IPTV playlists.
final filteredSeriesProvider =
    StreamProvider.autoDispose<List<ContentItemsTableData>>((ref) {
  final db = ref.watch(databaseProvider);
  final activePlaylistId = ref.watch(activePlaylistIdProvider);
  final filter = ref.watch(seriesFilterProvider);

  var query = db.select(db.contentItemsTable)
    ..where((t) => t.type.equals('series'));

  if (activePlaylistId != null) {
    query = query..where((t) => t.playlistId.equals(activePlaylistId));
  }

  if (filter.selectedCategoryId != null) {
    query = query..where((t) => t.categoryId.equals(filter.selectedCategoryId!));
  }

  final searchTerm = filter.searchQuery.trim();
  if (searchTerm.isNotEmpty) {
    query = query..where((t) => t.title.like('%$searchTerm%'));
  }

  if (filter.filterYear != null) {
    query = query..where((t) => t.releaseYear.equals(filter.filterYear!));
  }

  if (filter.minRating != null) {
    query = query
      ..where((t) => t.rating.isBiggerOrEqualValue(filter.minRating!));
  }

  switch (filter.sortBy) {
    case SeriesSortOption.titleAZ:
      query = query
        ..orderBy([(t) => drift.OrderingTerm(expression: t.title)]);
    case SeriesSortOption.titleZA:
      query = query
        ..orderBy([
          (t) => drift.OrderingTerm(
              expression: t.title, mode: drift.OrderingMode.desc)
        ]);
    case SeriesSortOption.ratingHigh:
      query = query
        ..orderBy([
          (t) => drift.OrderingTerm(
              expression: t.rating, mode: drift.OrderingMode.desc)
        ]);
    case SeriesSortOption.ratingLow:
      query = query
        ..orderBy([(t) => drift.OrderingTerm(expression: t.rating)]);
    case SeriesSortOption.yearNewest:
      query = query
        ..orderBy([
          (t) => drift.OrderingTerm(
              expression: t.releaseYear, mode: drift.OrderingMode.desc)
        ]);
    case SeriesSortOption.yearOldest:
      query = query
        ..orderBy([(t) => drift.OrderingTerm(expression: t.releaseYear)]);
  }

  query = query..limit(filter.selectedCategoryId != null ? 1500 : 500);

  return query.watch();
});
