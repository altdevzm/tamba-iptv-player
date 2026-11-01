import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  PlaylistsTable,
  CategoriesTable,
  ContentItemsTable,
  FavoritesTable,
  RecentlyViewedTable,
  PlaybackPositionsTable,
  EpgChannelsTable,
  EpgProgramsTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA journal_mode = WAL');
      await customStatement('PRAGMA synchronous = NORMAL');
    },
  );

  // --- Playlist Queries ---
  Future<List<PlaylistsTableData>> getAllPlaylists() =>
      (select(playlistsTable)..orderBy([(t) => OrderingTerm(expression: t.position)])).get();

  Stream<List<PlaylistsTableData>> watchAllPlaylists() =>
      (select(playlistsTable)..orderBy([(t) => OrderingTerm(expression: t.position)])).watch();

  Future<PlaylistsTableData?> getPlaylist(String id) =>
      (select(playlistsTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertPlaylist(PlaylistsTableCompanion entry) =>
      into(playlistsTable).insertOnConflictUpdate(entry);

  Future<int> deletePlaylist(String id) =>
      (delete(playlistsTable)..where((t) => t.id.equals(id))).go();

  // --- Category Queries ---
  Future<List<CategoriesTableData>> getCategories(String playlistId, String type) =>
      (select(categoriesTable)
        ..where((t) => t.playlistId.equals(playlistId))
        ..where((t) => t.type.equals(type))
        ..where((t) => t.hidden.equals(false)))
          .get();

  Stream<List<CategoriesTableData>> watchCategories(String playlistId, String type) =>
      (select(categoriesTable)
        ..where((t) => t.playlistId.equals(playlistId))
        ..where((t) => t.type.equals(type))
        ..where((t) => t.hidden.equals(false)))
          .watch();

  Future<void> batchInsertCategories(List<CategoriesTableCompanion> entries) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(categoriesTable, entries);
    });
  }

  // --- Content Queries ---
  Future<List<ContentItemsTableData>> getContentItems(String playlistId, String type, {int? categoryId}) {
    var query = select(contentItemsTable)
      ..where((t) => t.playlistId.equals(playlistId))
      ..where((t) => t.type.equals(type));
    if (categoryId != null) {
      query = query..where((t) => t.categoryId.equals(categoryId));
    }
    return query.get();
  }

  Stream<List<ContentItemsTableData>> watchContentItems(String playlistId, String type, {int? categoryId}) {
    var query = select(contentItemsTable)
      ..where((t) => t.playlistId.equals(playlistId))
      ..where((t) => t.type.equals(type));
    if (categoryId != null) {
      query = query..where((t) => t.categoryId.equals(categoryId));
    }
    return query.watch();
  }

  Stream<List<ContentItemsTableData>> watchTopContentItems(String playlistId, String type, {int limit = 25}) {
    return (select(contentItemsTable)
          ..where((t) => t.playlistId.equals(playlistId))
          ..where((t) => t.type.equals(type))
          ..where((t) => t.posterUrl.isNotNull() & t.posterUrl.isNotValue(''))
          ..limit(limit))
        .watch();
  }

  Stream<List<ContentItemsTableData>> watchLatestReleases(String playlistId, {int? targetYear, int limit = 30}) {
    var query = select(contentItemsTable)
      ..where((t) => t.playlistId.equals(playlistId))
      ..where((t) => t.type.isIn(['movie', 'series']))
      ..where((t) => t.posterUrl.isNotNull() & t.posterUrl.isNotValue(''));

    if (targetYear != null) {
      query = query..where((t) => t.releaseYear.equals(targetYear));
    }

    return (query
          ..orderBy([
            (t) => OrderingTerm(expression: t.releaseYear, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  Future<void> batchInsertContentItems(List<ContentItemsTableCompanion> entries) async {
    await batch((b) {
      b.insertAllOnConflictUpdate(contentItemsTable, entries);
    });
  }

  // --- Favorites Queries ---
  Stream<List<FavoritesTableData>> watchFavorites(String playlistId, {String? type}) {
    var query = select(favoritesTable)..where((t) => t.playlistId.equals(playlistId));
    if (type != null) {
      query = query..where((t) => t.type.equals(type));
    }
    return (query..orderBy([(t) => OrderingTerm(expression: t.position)])).watch();
  }

  Future<void> toggleFavorite(FavoritesTableCompanion item) async {
    final existing = await (select(favoritesTable)
          ..where((t) => t.playlistId.equals(item.playlistId.value))
          ..where((t) => t.type.equals(item.type.value))
          ..where((t) => t.providerId.equals(item.providerId.value)))
        .getSingleOrNull();

    if (existing != null) {
      await (delete(favoritesTable)..where((t) => t.id.equals(existing.id))).go();
    } else {
      await into(favoritesTable).insert(item);
    }
  }

  Future<bool> isFavorite(String playlistId, String type, String providerId) async {
    final row = await (select(favoritesTable)
          ..where((t) => t.playlistId.equals(playlistId))
          ..where((t) => t.type.equals(type))
          ..where((t) => t.providerId.equals(providerId)))
        .getSingleOrNull();
    return row != null;
  }

  Stream<bool> watchIsFavorite(String playlistId, String type, String providerId) {
    return (select(favoritesTable)
          ..where((t) => t.playlistId.equals(playlistId))
          ..where((t) => t.type.equals(type))
          ..where((t) => t.providerId.equals(providerId)))
        .watch()
        .map((rows) => rows.isNotEmpty);
  }

  // --- Playback Positions / Continue Watching ---
  Stream<List<PlaybackPositionsTableData>> watchContinueWatching(String playlistId) =>
      (select(playbackPositionsTable)
            ..where((t) => t.playlistId.equals(playlistId))
            ..where((t) => t.positionSeconds.isBiggerThanValue(0))
            ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)])
            ..limit(20))
          .watch();

  Stream<List<RecentlyViewedTableData>> watchRecentlyViewed(String playlistId) =>
      (select(recentlyViewedTable)
            ..where((t) => t.playlistId.equals(playlistId))
            ..orderBy([(t) => OrderingTerm(expression: t.viewedAt, mode: OrderingMode.desc)])
            ..limit(20))
          .watch();

  Future<void> savePlaybackPosition(PlaybackPositionsTableCompanion position) =>
      into(playbackPositionsTable).insertOnConflictUpdate(position);

  // --- EPG Queries ---
  Future<List<EpgProgramsTableData>> getCurrentAndNextPrograms(String channelId, DateTime now) =>
      (select(epgProgramsTable)
            ..where((t) => t.channelId.equals(channelId))
            ..where((t) => t.stop.isBiggerThanValue(now))
            ..orderBy([(t) => OrderingTerm(expression: t.start)])
            ..limit(2))
          .get();
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'filimu_plus.sqlite'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    final cachebase = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cachebase;

    return NativeDatabase.createInBackground(file);
  });
}

