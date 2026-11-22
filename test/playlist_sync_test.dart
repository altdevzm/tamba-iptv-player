import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';

import 'package:filimu_plus/core/diagnostics/app_logger.dart';
import 'package:filimu_plus/core/persistence/app_database.dart';
import 'package:filimu_plus/features/xtream/data/xtream_json_stream_parser.dart';

void main() {
  setUpAll(() {
    if (Platform.isLinux) {
      open.overrideFor(OperatingSystem.linux, () {
        for (final name in const ['libsqlite3.so.0', 'libsqlite3.so']) {
          try {
            return DynamicLibrary.open(name);
          } catch (_) {}
        }
        return DynamicLibrary.open('libsqlite3.so');
      });
    }
  });

  group('Playlist Sync & Refresh Regression Tests (SqliteException 2067 fix)', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Repeated category & content upserts with duplicate provider_id never throw 2067',
        () async {
      const playlistId = 'b766715b-2d0a-4d47-ab0d-59a608057a2f';
      await db.insertPlaylist(
        const PlaylistsTableCompanion(
          id: Value(playlistId),
          name: Value('Xtream (febby)'),
          type: Value('xtream'),
        ),
      );

      // Initial import with duplicate category_id 9905 (exact TV screenshot case)
      await db.batchInsertCategories([
        const CategoriesTableCompanion(
          playlistId: Value(playlistId),
          name: Value('DK: [720p] AND [H265]'),
          type: Value('live'),
          providerId: Value('9905'),
        ),
        const CategoriesTableCompanion(
          playlistId: Value(playlistId),
          name: Value('DK: [720p] AND [H265] Updated'),
          type: Value('live'),
          providerId: Value('9905'),
        ),
      ]);

      final catsFirst = await db.getCategories(playlistId, 'live');
      expect(catsFirst.length, 1);
      expect(catsFirst.first.name, 'DK: [720p] AND [H265] Updated');
      final originalCatId = catsFirst.first.id;

      // Second refresh of the SAME playlist must update in-place without 2067 or duplicate rows
      await db.batchInsertCategories([
        const CategoriesTableCompanion(
          playlistId: Value(playlistId),
          name: Value('DK: [720p] AND [H265] v3'),
          type: Value('live'),
          providerId: Value('9905'),
        ),
      ]);

      final catsSecond = await db.getCategories(playlistId, 'live');
      expect(catsSecond.length, 1);
      expect(catsSecond.first.id, originalCatId);
      expect(catsSecond.first.name, 'DK: [720p] AND [H265] v3');

      // Content items repeated refresh must also upsert cleanly without duplicates
      await db.batchInsertContentItems([
        ContentItemsTableCompanion(
          playlistId: const Value(playlistId),
          categoryId: Value(originalCatId),
          title: const Value('TV One HD'),
          type: const Value('live'),
          providerId: const Value('1001'),
          streamUrl: const Value('http://example.test/live/1001.ts'),
        ),
      ]);
      await db.batchInsertContentItems([
        ContentItemsTableCompanion(
          playlistId: const Value(playlistId),
          categoryId: Value(originalCatId),
          title: const Value('TV One FHD'),
          type: const Value('live'),
          providerId: const Value('1001'),
          streamUrl: const Value('http://example.test/live/1001.ts'),
        ),
      ]);

      final items = await db.getContentItems(playlistId, 'live');
      expect(items.length, 1);
      expect(items.first.title, 'TV One FHD');
    });

    test('AppLogger.sanitize redacts provider URLs and credentials', () {
      const raw =
          'Failed syncing http://secret.iptv.xyz:80/get.php?username=alice&password=supersecret&type=m3u';
      final clean = AppLogger.sanitize(raw);
      expect(clean, isNot(contains('alice')));
      expect(clean, isNot(contains('supersecret')));
      expect(clean, contains('http://secret.iptv.xyz/[redacted]'));
    });

    test('XtreamJsonStreamParser streams JSON arrays, object maps, escaped quotes, and 25k items',
        () async {
      // 1. Standard JSON array with escaped quotes and nested objects
      const arrayJson =
          '[{"stream_id":1,"name":"News \\"Live\\" {HD}","extra":{"a":1}},{"stream_id":2,"name":"Sports 4K"}]';
      final arrayItems = await XtreamJsonStreamParser.streamObjectsFromByteStream(
        Stream.fromIterable([utf8.encode(arrayJson.substring(0, 25)), utf8.encode(arrayJson.substring(25))]),
      ).toList();
      expect(arrayItems.length, 2);
      expect(arrayItems[0]['name'], 'News "Live" {HD}');
      expect(arrayItems[1]['stream_id'], 2);

      // 2. Xtream associative object map format {"0": {...}, "1": {...}}
      const mapJson =
          '{"0":{"stream_id":10,"name":"Movie A"},"1":{"stream_id":11,"name":"Movie B"}}';
      final mapItems = await XtreamJsonStreamParser.streamObjectsFromByteStream(
        Stream.value(utf8.encode(mapJson)),
      ).toList();
      expect(mapItems.length, 2);
      expect(mapItems[0]['name'], 'Movie A');
      expect(mapItems[1]['stream_id'], 11);

      // 3. Empty / HTML error page yields 0 cleanly without throwing
      final htmlItems = await XtreamJsonStreamParser.streamObjectsFromByteStream(
        Stream.value(utf8.encode('<html>502 Bad Gateway</html>')),
      ).toList();
      expect(htmlItems, isEmpty);

      // 4. Large 25,000-object stream completes fast in constant memory
      Stream<List<int>> largeStream() async* {
        yield utf8.encode('[');
        for (var i = 0; i < 25000; i++) {
          final prefix = i == 0 ? '' : ',';
          yield utf8.encode(
            '$prefix{"stream_id":$i,"name":"Channel $i","category_id":"10"}',
          );
        }
        yield utf8.encode(']');
      }

      var streamedCount = 0;
      await for (final _
          in XtreamJsonStreamParser.streamObjectsFromByteStream(largeStream())) {
        streamedCount++;
      }
      expect(streamedCount, 25000);
    });
  });
}
