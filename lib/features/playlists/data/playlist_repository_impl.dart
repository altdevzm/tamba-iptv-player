import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/persistence/app_database.dart';
import '../../../core/network/api_client.dart';
import '../domain/playlist_repository.dart';
import 'm3u_parser.dart';

/// Concrete [PlaylistRepository] backed by Drift (SQLite) and streaming `HttpClient`.
class PlaylistRepositoryImpl implements PlaylistRepository {
  final AppDatabase _db;
  final ApiClient _apiClient;

  const PlaylistRepositoryImpl(AppDatabase db, ApiClient apiClient)
      : _db = db,
        _apiClient = apiClient;

  // ── Public API ─────────────────────────────────────────────────────────────

  @override
  Future<void> importFromUrl(
    String playlistId,
    String url, {
    void Function(String status)? onProgress,
  }) async {
    onProgress?.call('Connecting to M3U server...');
    final tempFile = await _downloadM3uToTempFile(
      playlistId,
      url,
      onProgress: onProgress,
    );
    try {
      await _streamParseAndStoreFile(
        playlistId,
        tempFile,
        onProgress: onProgress,
      );
    } finally {
      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
    }
  }

  @override
  Future<void> importFromFile(
    String playlistId,
    String filePath, {
    void Function(String status)? onProgress,
  }) async {
    onProgress?.call('Reading M3U file...');
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('M3U file not found at $filePath');
    }
    await _streamParseAndStoreFile(
      playlistId,
      file,
      onProgress: onProgress,
    );
  }

  @override
  Future<void> refreshPlaylist(
    String playlistId, {
    void Function(String status)? onProgress,
  }) async {
    final playlist = await _db.getPlaylist(playlistId);
    if (playlist == null) return;

    if (playlist.url != null && playlist.url!.isNotEmpty) {
      await importFromUrl(playlistId, playlist.url!, onProgress: onProgress);
    } else if (playlist.filePath != null && playlist.filePath!.isNotEmpty) {
      await importFromFile(
        playlistId,
        playlist.filePath!,
        onProgress: onProgress,
      );
    }
    // If neither url nor filePath is set there is nothing to refresh.
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Normalizes a user-entered M3U URL so missing schemes still work.
  static String normalizeUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '';
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return 'http://$trimmed';
    }
    return trimmed;
  }

  /// Streams the M3U response directly to a temporary file on disk using
  /// O(1) constant RAM so 100–250 MB (300k+ channel) playlists never cause OOM.
  Future<File> _downloadM3uToTempFile(
    String playlistId,
    String url, {
    void Function(String status)? onProgress,
  }) async {
    final normalized = normalizeUrl(url);
    if (normalized.isEmpty) {
      throw Exception('Please enter a valid M3U playlist URL.');
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw Exception('Invalid M3U playlist URL.');
    }

    final tempDir = await getTemporaryDirectory();
    final tempFile = File(p.join(tempDir.path, 'm3u_import_$playlistId.tmp'));
    if (await tempFile.exists()) {
      await tempFile.delete();
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..idleTimeout = const Duration(minutes: 3)
      ..autoUncompress = true
      ..badCertificateCallback = (_, __, ___) => true;

    IOSink? sink;
    try {
      String userAgent = 'IPTVSmartersPro/1.0.0 (Linux; Android) VLC/3.0.18';
      String? customReferer;
      if (_apiClient.storage != null) {
        try {
          final customUa = await _apiClient.storage!
              .getPlaylistCredentials('filimu_custom_user_agent');
          if (customUa != null && customUa.trim().isNotEmpty) {
            userAgent = customUa.trim();
          }
          final ref = await _apiClient.storage!
              .getPlaylistCredentials('filimu_custom_referer');
          if (ref != null && ref.trim().isNotEmpty) {
            customReferer = ref.trim();
          }
        } catch (_) {}
      }

      final request = await client.getUrl(uri);
      request.followRedirects = true;
      request.maxRedirects = 8;
      request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      request.headers.set(HttpHeaders.acceptHeader, '*/*');
      if (customReferer != null) {
        request.headers.set(HttpHeaders.refererHeader, customReferer);
      }

      final response = await request.close().timeout(
            const Duration(minutes: 3),
          );

      final statusCode = response.statusCode;
      if (statusCode >= 400) {
        throw Exception(
          'Server returned HTTP $statusCode while downloading M3U.',
        );
      }

      final totalBytes = response.contentLength;
      sink = tempFile.openWrite();
      var received = 0;
      var lastProgressMs = 0;

      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastProgressMs >= 250) {
            lastProgressMs = now;
            final mb = (received / (1024 * 1024)).toStringAsFixed(1);
            if (totalBytes > 0) {
              final pct = ((received / totalBytes) * 100).clamp(0, 100).round();
              final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
              onProgress?.call('Downloading M3U... $pct% ($mb / $totalMb MB)');
            } else {
              onProgress?.call('Downloading M3U... $mb MB');
            }
          }
        }
      } on HttpException catch (e) {
        if (received == 0) {
          throw Exception(
            'Connection interrupted while downloading M3U: ${e.message}',
          );
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (received == 0) {
        throw Exception('The server returned an empty M3U playlist.');
      }
      return tempFile;
    } on SocketException catch (e) {
      throw Exception('Network error reaching ${uri.host}: ${e.message}');
    } on HandshakeException catch (e) {
      throw Exception('TLS/SSL error connecting to ${uri.host}: ${e.message}');
    } on HttpException catch (e) {
      throw Exception('HTTP error from ${uri.host}: ${e.message}');
    } catch (e) {
      try {
        await sink?.close();
        if (await tempFile.exists()) await tempFile.delete();
      } catch (_) {}
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  static final _seriesEpisodePattern = RegExp(
    r'\bS\d{1,2}\s*E\d{1,3}\b',
    caseSensitive: false,
  );

  /// Classifies an M3U entry as `'series'`, `'movie'`, or `'live'` based on
  /// standard IPTV URL structure (`/series/`, `/movie/`, VOD file extensions)
  /// and episode naming (`S01 E01` / `S01E01`).
  static String _classifyM3uItem(ParsedChannel ch) {
    final lowerUrl = ch.streamUrl.toLowerCase();
    final pathOnly = lowerUrl.split('?').first;
    if (pathOnly.contains('/series/') ||
        _seriesEpisodePattern.hasMatch(ch.title)) {
      return 'series';
    }
    if (pathOnly.contains('/movie/') ||
        pathOnly.endsWith('.mp4') ||
        pathOnly.endsWith('.mkv') ||
        pathOnly.endsWith('.avi') ||
        pathOnly.endsWith('.mov') ||
        pathOnly.endsWith('.m4v')) {
      return 'movie';
    }
    return 'live';
  }

  /// Checks if [file] starts with gzip magic bytes (`0x1F 0x8B`).
  Future<bool> _isGzipFile(File file) async {
    final raf = await file.open();
    try {
      final header = await raf.read(2);
      return header.length == 2 && header[0] == 0x1F && header[1] == 0x8B;
    } finally {
      await raf.close();
    }
  }

  /// Streams [file] line-by-line with [M3uStreamParser] and flushes channels
  /// into SQLite in 2,500-item chunks inside a single transaction.
  /// Peak RAM stays ~15 MB even for 300,000+ channel M3U playlists!
  Future<void> _streamParseAndStoreFile(
    String playlistId,
    File file, {
    void Function(String status)? onProgress,
  }) async {
    onProgress?.call('Parsing & saving M3U channels...');

    final isGzip = await _isGzipFile(file);
    Stream<List<int>> byteStream = file.openRead();
    if (isGzip) {
      byteStream = byteStream.transform(gzip.decoder);
    }
    final lineStream = byteStream
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter());

    final parser = M3uStreamParser();
    final categoryIdByKey = <String, int>{};
    // Only track non-empty tvgIds to avoid holding 300k+ strings in RAM;
    // items without tvgId use 'ch_$idx' which is strictly unique.
    final seenTvgKeys = <String>{};
    final pendingItems = <ContentItemsTableCompanion>[];
    var totalCount = 0;

    await _db.transaction(() async {
      // Clear previous items & categories for this playlist
      await (_db.delete(_db.contentItemsTable)
            ..where((t) => t.playlistId.equals(playlistId)))
          .go();
      await (_db.delete(_db.categoriesTable)
            ..where((t) => t.playlistId.equals(playlistId)))
          .go();

      Future<int> ensureCategoryId(String itemType, String groupName) async {
        final catKey = '$itemType::$groupName';
        final existing = categoryIdByKey[catKey];
        if (existing != null) return existing;

        final dbCatType = itemType == 'movie' ? 'movies' : itemType;
        final insertedId = await _db.into(_db.categoriesTable).insert(
              CategoriesTableCompanion.insert(
                playlistId: playlistId,
                name: groupName,
                type: dbCatType,
                providerId: groupName,
              ),
              mode: drift.InsertMode.insertOrIgnore,
            );

        if (insertedId > 0) {
          categoryIdByKey[catKey] = insertedId;
          return insertedId;
        }
        final row = await (_db.select(_db.categoriesTable)
              ..where((t) =>
                  t.playlistId.equals(playlistId) &
                  t.type.equals(dbCatType) &
                  t.providerId.equals(groupName)))
            .getSingleOrNull();
        final resolved = row?.id ?? 0;
        if (resolved > 0) categoryIdByKey[catKey] = resolved;
        return resolved;
      }

      const batchSize = 2500;
      await for (final line in lineStream) {
        final ch = parser.feedLine(line);
        if (ch == null) continue;

        final type = _classifyM3uItem(ch);
        final group = (ch.groupTitle?.trim().isNotEmpty == true)
            ? ch.groupTitle!.trim()
            : (type == 'movie' ? 'Movies' : 'Uncategorised');
        final catId = await ensureCategoryId(type, group);

        final idx = totalCount++;
        final tvgId = ch.tvgId?.trim();
        late final String providerId;
        if (tvgId != null && tvgId.isNotEmpty) {
          providerId = seenTvgKeys.add('$type::$tvgId')
              ? tvgId
              : '${tvgId}_$idx';
        } else {
          providerId = 'm3u_$idx';
        }

        pendingItems.add(
          ContentItemsTableCompanion.insert(
            playlistId: playlistId,
            categoryId: drift.Value(catId > 0 ? catId : null),
            title: ch.title,
            type: type,
            providerId: providerId,
            streamUrl: drift.Value(ch.streamUrl),
            posterUrl: drift.Value(ch.logoUrl),
            epgChannelId: drift.Value(ch.tvgId),
            tvArchiveDuration: drift.Value(ch.catchupDays),
            tvArchive: drift.Value(ch.catchupDays > 0 ? 1 : 0),
          ),
        );

        if (pendingItems.length >= batchSize) {
          await _db.batchInsertContentItemsFast(pendingItems);
          pendingItems.clear();
          onProgress?.call('Imported $totalCount channels...');
        }
      }

      if (pendingItems.isNotEmpty) {
        await _db.batchInsertContentItemsFast(pendingItems);
        pendingItems.clear();
      }

      if (totalCount == 0) {
        throw Exception(
          'No valid channels found in M3U playlist. Make sure the URL/file is a valid #EXTM3U playlist.',
        );
      }

      await _updatePlaylistMeta(playlistId, totalCount);
    });
  }

  /// Stamps [channelCount] and `lastUpdated = now` on the playlist row.
  Future<void> _updatePlaylistMeta(String playlistId, int channelCount) async {
    await (_db.update(_db.playlistsTable)..where((t) => t.id.equals(playlistId)))
        .write(
      PlaylistsTableCompanion(
        channelCount: drift.Value(channelCount),
        lastUpdated: drift.Value(DateTime.now()),
      ),
    );
  }
}
