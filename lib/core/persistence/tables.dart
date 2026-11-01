import 'package:drift/drift.dart';

class PlaylistsTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // 'm3u_file', 'm3u_url', 'm3u_text', 'xtream', 'stalker'
  TextColumn get url => text().nullable()();
  TextColumn get filePath => text().nullable()();
  TextColumn get serverUrl => text().nullable()();
  TextColumn get username => text().nullable()();
  TextColumn get macAddress => text().nullable()();
  TextColumn get userAgent => text().nullable()();
  BoolColumn get autoRefresh => boolean().withDefault(const Constant(false))();
  IntColumn get channelCount => integer().withDefault(const Constant(0))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastUpdated => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class CategoriesTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get playlistId => text().references(PlaylistsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get type => text()(); // 'live', 'movies', 'series'
  TextColumn get providerId => text()();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  BoolColumn get locked => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {playlistId, type, providerId},
  ];
}

class ContentItemsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get playlistId => text().references(PlaylistsTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get categoryId => integer().nullable().references(CategoriesTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  TextColumn get type => text()(); // 'live', 'movie', 'series'
  TextColumn get providerId => text()();
  TextColumn get streamUrl => text().nullable()();
  TextColumn get containerExtension => text().nullable()();
  TextColumn get posterUrl => text().nullable()();
  TextColumn get backdropUrl => text().nullable()();
  RealColumn get rating => real().nullable()();
  IntColumn get releaseYear => integer().nullable()();
  TextColumn get epgChannelId => text().nullable()();
  IntColumn get tvArchive => integer().withDefault(const Constant(0))();
  IntColumn get tvArchiveDuration => integer().withDefault(const Constant(0))();
  IntColumn get tmdbId => integer().nullable()();
  DateTimeColumn get addedAt => dateTime().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {playlistId, type, providerId},
  ];
}

class FavoritesTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get playlistId => text().references(PlaylistsTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get contentId => integer().nullable().references(ContentItemsTable, #id, onDelete: KeyAction.setNull)();
  TextColumn get providerId => text()();
  TextColumn get type => text()();
  TextColumn get title => text()();
  TextColumn get posterUrl => text().nullable()();
  TextColumn get backdropUrl => text().nullable()();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get addedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {playlistId, type, providerId},
  ];
}

class RecentlyViewedTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get playlistId => text().references(PlaylistsTable, #id, onDelete: KeyAction.cascade)();
  IntColumn get contentId => integer().references(ContentItemsTable, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get viewedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {playlistId, contentId},
  ];
}

class PlaybackPositionsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get playlistId => text().references(PlaylistsTable, #id, onDelete: KeyAction.cascade)();
  TextColumn get contentProviderId => text()();
  TextColumn get contentType => text()(); // 'vod', 'episode'
  TextColumn get seriesProviderId => text().nullable()();
  IntColumn get seasonNumber => integer().nullable()();
  IntColumn get episodeNumber => integer().nullable()();
  IntColumn get positionSeconds => integer().withDefault(const Constant(0))();
  IntColumn get durationSeconds => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {playlistId, contentType, contentProviderId},
  ];
}

class EpgChannelsTable extends Table {
  TextColumn get id => text()(); // EPG channel ID
  TextColumn get displayName => text()();
  TextColumn get iconUrl => text().nullable()();
  TextColumn get sourceUrl => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

class EpgProgramsTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get channelId => text().references(EpgChannelsTable, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get start => dateTime()();
  DateTimeColumn get stop => dateTime()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get iconUrl => text().nullable()();
  TextColumn get rating => text().nullable()();
  TextColumn get episodeNum => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
}

