import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/persistence/app_database.dart';
import '../../../core/network/api_client.dart';
import '../domain/playlist_repository.dart';
import 'm3u_parser.dart';

/// Concrete [PlaylistRepository] backed by Drift (SQLite) and Dio.
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
    final content = await _downloadM3u(url, onProgress: onProgress);
    await _parseAndStore(playlistId, content, onProgress: onProgress);
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
    final bytes = await file.readAsBytes();
    final content = utf8.decode(bytes, allowMalformed: true);
    await _parseAndStore(playlistId, content, onProgress: onProgress);
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

  /// Downloads the raw M3U text from [url] via Dio with IPTV-compatible headers,
  /// gzip compression, live MB progress updates, and extended timeouts.
  Future<String> _downloadM3u(
    String url, {
    void Function(String status)? onProgress,
  }) async {
    final normalized = normalizeUrl(url);
    if (normalized.isEmpty) {
      throw Exception('Please enter a valid M3U playlist URL.');
    }

    var lastProgressMs = 0;

    try {
      final response = await _apiClient.dio.get<dynamic>(
        normalized,
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(minutes: 3),
          sendTimeout: const Duration(seconds: 30),
          followRedirects: true,
          maxRedirects: 5,
          headers: const {
            'User-Agent': 'VLC/3.0.18 LibVLC/3.0.18',
            'Accept': '*/*',
            'Accept-Encoding': 'gzip, deflate',
          },
        ),
        onReceiveProgress: (received, total) {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastProgressMs < 250) return;
          lastProgressMs = now;
          final mb = (received / (1024 * 1024)).toStringAsFixed(1);
          if (total > 0) {
            final pct = ((received / total) * 100).clamp(0, 100).round();
            final totalMb = (total / (1024 * 1024)).toStringAsFixed(1);
            onProgress?.call('Downloading M3U... $pct% ($mb / $totalMb MB)');
          } else {
            onProgress?.call('Downloading M3U... $mb MB');
          }
        },
      );

      final statusCode = response.statusCode ?? 200;
      if (statusCode >= 400) {
        throw Exception(
          'Server returned HTTP $statusCode while downloading M3U.',
        );
      }

      final data = response.data;
      final text = data is String ? data : (data?.toString() ?? '');
      if (text.trim().isEmpty) {
        throw Exception('The server returned an empty M3U playlist.');
      }
      return text;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status != null) {
        throw Exception('Server returned HTTP $status while downloading M3U.');
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception(
          'Timed out downloading M3U playlist. Please check the URL and your connection.',
        );
      }
      throw Exception(
        'Could not download M3U playlist: ${e.message ?? e.type.name}',
      );
    }
  }

  /// Classifies an M3U entry as `'movie'` when its URL clearly points to a VOD
  /// movie file; everything else stays `'live'` so every item is directly playable.
  static String _classifyM3uItem(ParsedChannel ch) {
    final lowerUrl = ch.streamUrl.toLowerCase();
    final pathOnly = lowerUrl.split('?').first;
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

  /// Runs the M3U parser in a background isolate, then batch-inserts the
  /// results into the database and updates the playlist metadata.
  Future<void> _parseAndStore(
    String playlistId,
    String content, {
    void Function(String status)? onProgress,
  }) async {
    onProgress?.call('Parsing M3U channels...');
    // Parse on a background isolate (Isolate.run is called inside parseM3u).
    final channels = await parseM3u(content);

    if (channels.isEmpty) {
      throw Exception(
        'No valid channels found in M3U playlist. Make sure the URL/file is a valid #EXTM3U playlist.',
      );
    }

    onProgress?.call('Saving ${channels.length} channels...');

    // Wrap the full replace + bulk insert in a single SQLite transaction so
    // large playlists (100k-300k+ items) commit once instead of hundreds of
    // times, avoiding per-chunk fsyncs and repeated UI stream rebuilds.
    await _db.transaction(() async {
      // Clear previous items & categories for this playlist so refreshes and
      // duplicate providerIds never violate composite UNIQUE constraints.
      await (_db.delete(_db.contentItemsTable)
            ..where((t) => t.playlistId.equals(playlistId)))
          .go();
      await (_db.delete(_db.categoriesTable)
            ..where((t) => t.playlistId.equals(playlistId)))
          .go();

      // ── 1. Extract unique (type, group-title) pairs → CategoriesTable ─────
      final seenGroupsByType = <String, Set<String>>{};
      final orderedCategories = <(String, String)>[]; // (type, groupName)
      final itemTypes = List<String>.filled(channels.length, 'live');

      for (var i = 0; i < channels.length; i++) {
        final ch = channels[i];
        final type = _classifyM3uItem(ch);
        itemTypes[i] = type;
        final group = (ch.groupTitle?.trim().isNotEmpty == true)
            ? ch.groupTitle!.trim()
            : (type == 'movie' ? 'Movies' : 'Uncategorised');

        final set = seenGroupsByType.putIfAbsent(type, () => <String>{});
        if (set.add(group)) {
          orderedCategories.add((type, group));
        }
      }

      final categoryCompanions = orderedCategories
          .map(
            (entry) => CategoriesTableCompanion.insert(
              playlistId: playlistId,
              name: entry.$2,
              type: entry.$1,
              providerId: entry.$2,
            ),
          )
          .toList();

      for (var i = 0; i < categoryCompanions.length; i += 1000) {
        final end = (i + 1000 < categoryCompanions.length)
            ? i + 1000
            : categoryCompanions.length;
        await _db.batchInsertCategories(categoryCompanions.sublist(i, end));
      }

      // Reload categories so we can resolve (type, group-name) → DB row ID.
      final liveCategories = await _db.getCategories(playlistId, 'live');
      final movieCategories = await _db.getCategories(playlistId, 'movie');
      final categoryIdByKey = <String, int>{
        for (final cat in liveCategories) 'live::${cat.name}': cat.id,
        for (final cat in movieCategories) 'movie::${cat.name}': cat.id,
      };

      // ── 2. Insert channels → ContentItemsTable (deduplicated providerId) ──
      final seenProviderKeys = <String>{};
      final contentCompanions = <ContentItemsTableCompanion>[];

      for (var idx = 0; idx < channels.length; idx++) {
        final ch = channels[idx];
        final type = itemTypes[idx];
        final group = (ch.groupTitle?.trim().isNotEmpty == true)
            ? ch.groupTitle!.trim()
            : (type == 'movie' ? 'Movies' : 'Uncategorised');
        final categoryId = categoryIdByKey['$type::$group'];

        // Guarantee uniqueness on {playlistId, type, providerId} even when
        // multiple channels share the same tvg-id or title.
        final baseId = (ch.tvgId != null && ch.tvgId!.trim().isNotEmpty)
            ? ch.tvgId!.trim()
            : '${ch.title}_$idx';
        var providerId = baseId;
        if (!seenProviderKeys.add('$type::$providerId')) {
          providerId = '${baseId}_$idx';
          seenProviderKeys.add('$type::$providerId');
        }

        contentCompanions.add(
          ContentItemsTableCompanion.insert(
            playlistId: playlistId,
            categoryId: drift.Value(categoryId),
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
      }

      const chunkSize = 5000;
      for (var i = 0; i < contentCompanions.length; i += chunkSize) {
        final end = (i + chunkSize < contentCompanions.length)
            ? i + chunkSize
            : contentCompanions.length;
        await _db.batchInsertContentItemsFast(contentCompanions.sublist(i, end));
        if (contentCompanions.length > chunkSize) {
          onProgress?.call(
            'Saving channels ($end / ${contentCompanions.length})...',
          );
        }
      }

      // ── 3. Update playlist metadata ────────────────────────────────────────
      await _updatePlaylistMeta(playlistId, channels.length);
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
