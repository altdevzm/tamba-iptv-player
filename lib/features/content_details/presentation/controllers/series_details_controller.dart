import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../../core/persistence/app_database.dart';
import '../../../../core/persistence/database_provider.dart';
import '../../../../shared/models/media_item.dart';
import '../../../../shared/services/tmdb_service.dart';
import '../../../player/data/player_controller.dart';
import '../../../player/data/external_player_service.dart';
import '../../../xtream/data/xtream_client.dart';
import '../../../stalker/data/stalker_client.dart';

class SeriesDetailsState {
  final ContentItemsTableData series;
  final TmdbMetadata? tmdb;
  final bool isLoadingTmdb;
  final bool isLoadingEpisodes;
  final Map<String, List<Map<String, dynamic>>> episodesBySeason;
  final String? selectedSeason;
  final String? fetchEpisodesError;
  final Map<String, dynamic>? seriesDetailsInfo;
  final bool isFavorite;
  final bool isSynopsisExpanded;
  final XtreamCredentials? xtreamCreds;
  final XtreamClient? xtreamClient;
  final StalkerCredentials? stalkerCreds;
  final StalkerClient? stalkerClient;

  const SeriesDetailsState({
    required this.series,
    this.tmdb,
    this.isLoadingTmdb = false,
    this.isLoadingEpisodes = false,
    this.episodesBySeason = const {},
    this.selectedSeason,
    this.fetchEpisodesError,
    this.seriesDetailsInfo,
    this.isFavorite = false,
    this.isSynopsisExpanded = false,
    this.xtreamCreds,
    this.xtreamClient,
    this.stalkerCreds,
    this.stalkerClient,
  });

  SeriesDetailsState copyWith({
    ContentItemsTableData? series,
    TmdbMetadata? tmdb,
    bool? isLoadingTmdb,
    bool? isLoadingEpisodes,
    Map<String, List<Map<String, dynamic>>>? episodesBySeason,
    String? selectedSeason,
    String? fetchEpisodesError,
    Map<String, dynamic>? seriesDetailsInfo,
    bool? isFavorite,
    bool? isSynopsisExpanded,
    XtreamCredentials? xtreamCreds,
    XtreamClient? xtreamClient,
    StalkerCredentials? stalkerCreds,
    StalkerClient? stalkerClient,
  }) {
    return SeriesDetailsState(
      series: series ?? this.series,
      tmdb: tmdb ?? this.tmdb,
      isLoadingTmdb: isLoadingTmdb ?? this.isLoadingTmdb,
      isLoadingEpisodes: isLoadingEpisodes ?? this.isLoadingEpisodes,
      episodesBySeason: episodesBySeason ?? this.episodesBySeason,
      selectedSeason: selectedSeason ?? this.selectedSeason,
      fetchEpisodesError: fetchEpisodesError ?? this.fetchEpisodesError,
      seriesDetailsInfo: seriesDetailsInfo ?? this.seriesDetailsInfo,
      isFavorite: isFavorite ?? this.isFavorite,
      isSynopsisExpanded: isSynopsisExpanded ?? this.isSynopsisExpanded,
      xtreamCreds: xtreamCreds ?? this.xtreamCreds,
      xtreamClient: xtreamClient ?? this.xtreamClient,
      stalkerCreds: stalkerCreds ?? this.stalkerCreds,
      stalkerClient: stalkerClient ?? this.stalkerClient,
    );
  }

  // ── Derived Presentation Getters ─────────────────────────────────────────

  String get displayTitle =>
      tmdb?.title.isNotEmpty == true ? tmdb!.title : series.title;

  String? get displayPoster =>
      tmdb?.posterUrl ??
      seriesDetailsInfo?['cover']?.toString() ??
      series.posterUrl;

  String? get displayBackdrop =>
      tmdb?.backdropUrl ??
      (seriesDetailsInfo?['backdrop_path'] is List &&
              (seriesDetailsInfo!['backdrop_path'] as List).isNotEmpty
          ? (seriesDetailsInfo!['backdrop_path'] as List).first.toString()
          : seriesDetailsInfo?['backdrop_path']?.toString()) ??
      series.backdropUrl;

  double? get displayRating =>
      tmdb?.rating ??
      (seriesDetailsInfo?['rating'] != null
          ? double.tryParse(seriesDetailsInfo!['rating'].toString())
          : null) ??
      series.rating;

  int? get displayYear =>
      tmdb?.releaseYear ??
      series.releaseYear ??
      (seriesDetailsInfo?['releaseDate'] != null
          ? DateTime.tryParse(seriesDetailsInfo!['releaseDate'].toString())
              ?.year
          : null);

  String? get displayOverview =>
      tmdb?.overview ??
      seriesDetailsInfo?['plot']?.toString() ??
      seriesDetailsInfo?['description']?.toString();

  int get seasonsCount => episodesBySeason.keys.isNotEmpty
      ? episodesBySeason.keys.length
      : (tmdb?.seasonsCount ?? 1);

  String? get displayAgeRating =>
      tmdb?.ageRating ??
      seriesDetailsInfo?['age']?.toString() ??
      seriesDetailsInfo?['rating_mpaa']?.toString();

  List<String> get displayGenres => tmdb?.genres.isNotEmpty == true
      ? tmdb!.genres
      : (seriesDetailsInfo?['genre']
              ?.toString()
              .split(RegExp(r'[,/;]'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList() ??
          <String>[]);

  List<String> get displayCreators => tmdb?.directors.isNotEmpty == true
      ? tmdb!.directors
      : (seriesDetailsInfo?['director']
              ?.toString()
              .split(RegExp(r'[,;]'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList() ??
          (seriesDetailsInfo?['cast']
                  ?.toString()
                  .split(RegExp(r'[,;]'))
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList() ??
              <String>[]));

  List<TmdbCastItem> get cast => tmdb?.cast ?? const [];

  String? get trailerUrl {
    final rawTrailer =
        tmdb?.trailerUrl ?? seriesDetailsInfo?['youtube_trailer']?.toString();
    if (rawTrailer != null && rawTrailer.trim().isNotEmpty) {
      final t = rawTrailer.trim();
      return (t.startsWith('http://') || t.startsWith('https://'))
          ? t
          : 'https://www.youtube.com/watch?v=$t';
    }
    return null;
  }

  List<Map<String, dynamic>> get currentEpisodes => selectedSeason != null
      ? (episodesBySeason[selectedSeason] ?? [])
      : <Map<String, dynamic>>[];
}

class SeriesDetailsNotifier extends StateNotifier<SeriesDetailsState> {
  final Ref _ref;

  SeriesDetailsNotifier(this._ref, ContentItemsTableData series)
      : super(SeriesDetailsState(series: series)) {
    _init();
  }

  void _init() {
    _checkFavorite();
    _fetchTmdbEnrichment();
    _fetchEpisodes();
  }

  void selectSeason(String season) {
    state = state.copyWith(selectedSeason: season);
  }

  void toggleSynopsis() {
    state = state.copyWith(isSynopsisExpanded: !state.isSynopsisExpanded);
  }

  Future<void> _checkFavorite() async {
    final db = _ref.read(databaseProvider);
    final fav = await db.isFavorite(
      state.series.playlistId,
      'series',
      state.series.providerId,
    );
    state = state.copyWith(isFavorite: fav);
  }

  Future<void> toggleFavorite(BuildContext context) async {
    final db = _ref.read(databaseProvider);
    await db.toggleFavorite(
      FavoritesTableCompanion(
        playlistId: drift.Value(state.series.playlistId),
        contentId: drift.Value(state.series.id),
        providerId: drift.Value(state.series.providerId),
        type: const drift.Value('series'),
        title: drift.Value(state.series.title),
        posterUrl: drift.Value(state.series.posterUrl),
        backdropUrl: drift.Value(state.series.backdropUrl),
      ),
    );

    final nextFav = !state.isFavorite;
    state = state.copyWith(isFavorite: nextFav);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextFav
                ? 'Added "${state.displayTitle}" to My List'
                : 'Removed "${state.displayTitle}" from My List',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _fetchTmdbEnrichment() async {
    final tmdbService = _ref.read(tmdbServiceProvider);
    final apiKey = await tmdbService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) return;

    state = state.copyWith(isLoadingTmdb: true);
    try {
      final meta = await tmdbService.searchSeries(
        state.series.title,
        apiKey: apiKey,
      );
      if (meta != null) {
        state = state.copyWith(tmdb: meta);
      }
    } catch (_) {}
    state = state.copyWith(isLoadingTmdb: false);
  }

  Future<void> _fetchEpisodes() async {
    var playlistId = state.series.playlistId;
    final db = _ref.read(databaseProvider);

    // Primary lookup
    var playlist =
        playlistId.isNotEmpty ? await db.getPlaylist(playlistId) : null;

    // Fallback 1: use active playlist
    if (playlist == null) {
      final activeId = _ref.read(activePlaylistIdProvider);
      if (activeId != null && activeId.isNotEmpty) {
        playlist = await db.getPlaylist(activeId);
        if (playlist != null) playlistId = activeId;
      }
    }

    // Fallback 2: use first available playlist
    if (playlist == null) {
      final allPlaylists = await db.getAllPlaylists();
      if (allPlaylists.isNotEmpty) {
        playlist = allPlaylists.first;
        playlistId = playlist.id;
      }
    }

    if (playlist == null) {
      state = state.copyWith(
        fetchEpisodesError: 'No active playlist found.',
        isLoadingEpisodes: false,
      );
      return;
    }

    final dio = _ref.read(apiClientProvider).dio;

    if (playlist.type == 'xtream') {
      final storage = _ref.read(secureStorageProvider);
      // Try both the original playlistId and the resolved playlistId
      String? password = await storage.getPlaylistCredentials(playlistId);
      if (password == null && playlistId != state.series.playlistId) {
        password =
            await storage.getPlaylistCredentials(state.series.playlistId);
      }

      if (password == null ||
          playlist.serverUrl == null ||
          playlist.username == null) {
        state = state.copyWith(
          fetchEpisodesError: 'Playlist credentials missing.',
          isLoadingEpisodes: false,
        );
        return;
      }

      final creds = XtreamCredentials.normalized(
        serverUrl: playlist.serverUrl!,
        username: playlist.username!,
        password: password,
      );
      final client = XtreamClient(dio);

      state = state.copyWith(isLoadingEpisodes: true, fetchEpisodesError: null);
      try {
        final info = await client.getSeriesInfo(creds, state.series.providerId);
        final rawEp = info['episodes'];
        final parsed = <String, List<Map<String, dynamic>>>{};

        if (rawEp is Map) {
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
          for (final entry in rawEp) {
            if (entry is! Map) continue;
            final ep = Map<String, dynamic>.from(entry);
            final season =
                ep['season_num']?.toString() ?? ep['season']?.toString() ?? '1';
            parsed.putIfAbsent(season, () => []).add(ep);
          }
        }

        state = state.copyWith(
          episodesBySeason: parsed,
          selectedSeason: parsed.keys.isNotEmpty ? parsed.keys.first : null,
          seriesDetailsInfo: info['info'] is Map
              ? Map<String, dynamic>.from(info['info'])
              : null,
          xtreamCreds: creds,
          xtreamClient: client,
          fetchEpisodesError:
              parsed.isEmpty ? 'No episodes returned by provider.' : null,
        );
      } catch (e) {
        state = state.copyWith(fetchEpisodesError: e.toString());
      }
      state = state.copyWith(isLoadingEpisodes: false);
    } else if (playlist.type == 'stalker' &&
        playlist.serverUrl != null &&
        playlist.macAddress != null) {
      final stalkerCreds = StalkerCredentials(
        serverUrl: playlist.serverUrl!,
        macAddress: playlist.macAddress!,
      );
      final client = StalkerClient(dio);

      state = state.copyWith(isLoadingEpisodes: true);
      try {
        await client.handshake(stalkerCreds);
        final rawEpisodes = await client.getSeriesEpisodes(
            stalkerCreds, state.series.providerId);
        if (rawEpisodes.isNotEmpty) {
          final parsed = <String, List<Map<String, dynamic>>>{};
          for (final ep in rawEpisodes) {
            final season =
                ep['season']?.toString() ?? ep['season_id']?.toString() ?? '1';
            parsed.putIfAbsent(season, () => []).add(ep);
          }
          state = state.copyWith(
            episodesBySeason: parsed,
            selectedSeason: parsed.keys.isNotEmpty ? parsed.keys.first : null,
            stalkerCreds: stalkerCreds,
            stalkerClient: client,
          );
        } else {
          state = state.copyWith(
            fetchEpisodesError: 'No episodes returned by provider.',
          );
        }
      } catch (e) {
        state = state.copyWith(fetchEpisodesError: e.toString());
      }
      state = state.copyWith(isLoadingEpisodes: false);
    } else if (playlist.type == 'm3u' || playlist.type == 'local') {
      // For M3U playlists, query local DB for episodes that share the same
      // title prefix as the series (ContentItemsTable has no seriesProviderId).
      state = state.copyWith(isLoadingEpisodes: true, fetchEpisodesError: null);
      try {
        // Fetch all series-type items in this playlist
        final allRows = await (db.select(db.contentItemsTable)
              ..where((t) =>
                  t.playlistId.equals(playlistId) & t.type.equals('series')))
            .get();

        // Filter rows that look like episodes of this series by matching the
        // series title prefix (case-insensitive) or exact providerId prefix
        final seriesTitle = state.series.title.toLowerCase().trim();
        final seriesId = state.series.providerId;
        final episodeRows = allRows.where((r) {
          final rTitle = r.title.toLowerCase().trim();
          return rTitle.startsWith(seriesTitle) ||
              r.providerId.startsWith(seriesId);
        }).toList();

        if (episodeRows.isNotEmpty) {
          final parsed = <String, List<Map<String, dynamic>>>{};
          for (int i = 0; i < episodeRows.length; i++) {
            final row = episodeRows[i];
            // Try to extract S##E## from title or use sequential numbering
            final seasonMatch =
                RegExp(r'[Ss](\d+)[Ee](\d+)').firstMatch(row.title);
            final season = seasonMatch?.group(1) ?? '1';
            final epNum = seasonMatch?.group(2) ?? '${i + 1}';
            final ep = <String, dynamic>{
              'id': row.providerId,
              'stream_id': row.providerId,
              'title': row.title,
              'episode_num': epNum,
              'season_num': season,
              'container_extension': row.containerExtension ?? 'mp4',
              'stream_url': row.streamUrl,
              'info': <String, dynamic>{
                'movie_image': row.posterUrl,
              },
            };
            parsed.putIfAbsent(season, () => []).add(ep);
          }
          state = state.copyWith(
            episodesBySeason: parsed,
            selectedSeason: parsed.keys.isNotEmpty ? parsed.keys.first : null,
            fetchEpisodesError: null,
          );
        } else {
          state = state.copyWith(
            fetchEpisodesError: 'No episodes found in local library.',
          );
        }
      } catch (e) {
        state = state.copyWith(fetchEpisodesError: e.toString());
      }
      state = state.copyWith(isLoadingEpisodes: false);
    }
  }

  Future<void> playEpisode(
    BuildContext context,
    Map<String, dynamic> ep,
    int idx,
  ) async {
    final epId = ep['id']?.toString() ?? ep['stream_id']?.toString() ?? '';
    final rawExt = ep['container_extension']?.toString() ?? '';
    final containerExt = rawExt.isNotEmpty ? rawExt : 'mp4';
    final epNum = ep['episode_num']?.toString() ?? '${idx + 1}';
    final epTitle = ep['title']?.toString() ?? 'Episode ${idx + 1}';
    final epInfo = ep['info'] is Map ? ep['info'] as Map : null;
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

    String? streamUrl;
    // M3U/local: episode map has a direct stream_url field
    final directUrl = ep['stream_url']?.toString();
    if (directUrl != null && directUrl.isNotEmpty) {
      streamUrl = directUrl;
    } else if (state.xtreamCreds != null &&
        state.xtreamClient != null &&
        epId.isNotEmpty) {
      streamUrl = state.xtreamClient!.buildSeriesStreamUrl(
        state.xtreamCreds!,
        epId,
        containerExt,
      );
    } else if (state.stalkerCreds != null && state.stalkerClient != null) {
      final cmd = ep['cmd']?.toString();
      if (cmd != null && cmd.isNotEmpty) {
        streamUrl = await state.stalkerClient!.createLink(
          state.stalkerCreds!,
          type: 'vod',
          cmd: cmd,
        );
      }
    }

    if (streamUrl != null && streamUrl.isNotEmpty && context.mounted) {
      final seasonNumber = int.tryParse(state.selectedSeason ?? '');
      final episodeNumber = int.tryParse(epNum);
      final player = _ref.read(playerControllerProvider.notifier);
      Navigator.of(context).pop(); // dismiss modal/sheet if open
      player.playItem(
        MediaItem(
          id: epId.isNotEmpty ? epId : (ep['cmd']?.toString() ?? 'ep_$idx'),
          title:
              '${state.series.title} - S${state.selectedSeason} E$epNum: $epTitle',
          type: MediaType.series,
          posterUrl: epThumbnail ?? state.displayPoster,
          backdropUrl: state.displayBackdrop,
          streamUrl: streamUrl,
          playlistId: state.series.playlistId,
          providerId:
              epId.isNotEmpty ? epId : (ep['cmd']?.toString() ?? 'ep_$idx'),
          seriesProviderId: state.series.providerId,
          seasonNumber: seasonNumber,
          episodeNumber: episodeNumber,
        ),
        startFullscreen: true,
      );
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not resolve stream URL for this episode.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void playFirstAvailableEpisode(BuildContext context) {
    if (state.isLoadingEpisodes) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loading episodes, please wait...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    final eps = state.currentEpisodes;
    if (eps.isNotEmpty) {
      playEpisode(context, eps.first, 0);
    } else if (state.series.streamUrl != null &&
        state.series.streamUrl!.isNotEmpty) {
      final player = _ref.read(playerControllerProvider.notifier);
      if (context.mounted) Navigator.of(context).pop();
      player.playItem(
        MediaItem(
          id: state.series.providerId,
          title: state.displayTitle,
          type: MediaType.series,
          posterUrl: state.displayPoster,
          backdropUrl: state.displayBackdrop,
          streamUrl: state.series.streamUrl,
          playlistId: state.series.playlistId,
          providerId: state.series.providerId,
          contentDbId: state.series.id,
        ),
        startFullscreen: true,
      );
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              state.fetchEpisodesError != null
                  ? 'Could not load episodes: ${state.fetchEpisodesError}'
                  : 'No episodes available for this series.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void watchTrailer(BuildContext context) {
    final url = state.trailerUrl;
    if (url != null) {
      ExternalPlayerService.openUrl(url);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening trailer for "${state.displayTitle}"'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

final seriesDetailsProvider = StateNotifierProvider.autoDispose
    .family<SeriesDetailsNotifier, SeriesDetailsState, ContentItemsTableData>(
  (ref, series) => SeriesDetailsNotifier(ref, series),
);
