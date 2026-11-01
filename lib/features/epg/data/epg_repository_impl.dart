import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/persistence/app_database.dart';
import 'xmltv_parser.dart';

/// Repository responsible for downloading, parsing, and storing EPG data,
/// as well as querying current/upcoming programs.
class EpgRepositoryImpl {
  final AppDatabase _db;
  final Dio _dio;

  EpgRepositoryImpl({required AppDatabase db, required Dio dio})
      : _db = db,
        _dio = dio;

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  /// Downloads an XMLTV feed from [url], decompresses it if gzip-encoded,
  /// parses it, and upserts channels + programs into the database.
  Future<void> importEpgFromUrl(String url) async {
    // 1. Download raw bytes.
    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );

    List<int> bytes = response.data ?? [];

    // 2. Detect and decompress gzip (magic bytes 0x1f 0x8b).
    if (bytes.length >= 2 && bytes[0] == 0x1f && bytes[1] == 0x8b) {
      bytes = GZipDecoder().decodeBytes(bytes);
    }

    // 3. Decode to a UTF-8 string.
    final xmlContent = utf8.decode(bytes, allowMalformed: true);

    // 4. Parse in an isolate.
    final parsed = await parseXmltv(xmlContent);

    // 5. Upsert channels.
    if (parsed.channels.isNotEmpty) {
      final channelCompanions = parsed.channels.map((c) {
        return EpgChannelsTableCompanion(
          id: Value(c.id),
          displayName: Value(c.displayName),
          iconUrl: Value(c.iconUrl),
          sourceUrl: Value(url),
          updatedAt: Value(DateTime.now().toUtc()),
        );
      }).toList();

      await _db.batch((b) {
        b.insertAllOnConflictUpdate(_db.epgChannelsTable, channelCompanions);
      });
    }

    // 6. For each channel that has programs, clear old programs then re-insert.
    final channelIds = parsed.programs.map((p) => p.channelId).toSet();

    for (final channelId in channelIds) {
      // Delete stale programs for this channel.
      await (_db.delete(_db.epgProgramsTable)
            ..where((t) => t.channelId.equals(channelId)))
          .go();
    }

    // 7. Batch-insert new programs (in chunks to avoid SQLite variable limits).
    if (parsed.programs.isNotEmpty) {
      final programCompanions = parsed.programs.map((p) {
        return EpgProgramsTableCompanion(
          channelId: Value(p.channelId),
          start: Value(p.start),
          stop: Value(p.stop),
          title: Value(p.title),
          description: Value(p.description),
          category: Value(p.category),
          iconUrl: Value(p.iconUrl),
          rating: Value(p.rating),
          episodeNum: Value(p.episodeNum),
          sourceUrl: Value(url),
        );
      }).toList();

      const chunkSize = 500;
      for (var i = 0; i < programCompanions.length; i += chunkSize) {
        final chunk = programCompanions.skip(i).take(chunkSize).toList();
        await _db.batch((b) {
          b.insertAll(_db.epgProgramsTable, chunk);
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Convenience helper used by the repository & channel_matcher
  // ---------------------------------------------------------------------------

  /// Deletes all EPG programs for the given [channelId].
  Future<void> deleteEpgProgramsForChannel(String channelId) async {
    await (_db.delete(_db.epgProgramsTable)
          ..where((t) => t.channelId.equals(channelId)))
        .go();
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Returns a [Stream] of up to 5 upcoming (or currently-airing) programs for
  /// [channelId], ordered by start time.
  Stream<List<EpgProgramsTableData>> watchCurrentPrograms(String channelId) {
    final now = DateTime.now().toUtc();
    return (_db.select(_db.epgProgramsTable)
          ..where((t) => t.channelId.equals(channelId))
          ..where((t) => t.stop.isBiggerThanValue(now))
          ..orderBy([(t) => OrderingTerm(expression: t.start)])
          ..limit(5))
        .watch();
  }

  /// Returns the currently airing and upcoming programmes for [channelId].
  Stream<List<EpgProgramsTableData>> watchChannelSchedule(String channelId) {
    final now = DateTime.now().toUtc();
    return (_db.select(_db.epgProgramsTable)
          ..where((t) => t.channelId.equals(channelId))
          ..where((t) => t.stop.isBiggerThanValue(now))
          ..orderBy([(t) => OrderingTerm(expression: t.start)])
          ..limit(25))
        .watch();
  }

  /// Returns the program that is currently airing on [channelId], i.e.
  /// `start <= now <= stop`.  Returns `null` if none is found.
  Future<EpgProgramsTableData?> getCurrentProgram(String channelId) async {
    final now = DateTime.now().toUtc();
    return (_db.select(_db.epgProgramsTable)
          ..where((t) => t.channelId.equals(channelId))
          ..where((t) => t.start.isSmallerOrEqualValue(now))
          ..where((t) => t.stop.isBiggerOrEqualValue(now))
          ..limit(1))
        .getSingleOrNull();
  }
}
