import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../../../core/persistence/app_database.dart';
import '../../../../core/persistence/database_provider.dart';
import '../../../../shared/models/media_item.dart';
import '../../../../shared/services/tmdb_service.dart';
import '../../../player/data/player_controller.dart';
import '../../../player/data/external_player_service.dart';
import '../../../downloads/data/download_service.dart';
import '../../../xtream/data/xtream_client.dart';

class MovieDetailsState {
  final ContentItemsTableData movie;
  final TmdbMetadata? tmdb;
  final bool isLoadingTmdb;
  final Map<String, dynamic>? vodDetails;
  final bool isLoadingVod;
  final bool isFavorite;
  final bool isSynopsisExpanded;

  const MovieDetailsState({
    required this.movie,
    this.tmdb,
    this.isLoadingTmdb = false,
    this.vodDetails,
    this.isLoadingVod = false,
    this.isFavorite = false,
    this.isSynopsisExpanded = false,
  });

  MovieDetailsState copyWith({
    ContentItemsTableData? movie,
    TmdbMetadata? tmdb,
    bool? isLoadingTmdb,
    Map<String, dynamic>? vodDetails,
    bool? isLoadingVod,
    bool? isFavorite,
    bool? isSynopsisExpanded,
  }) {
    return MovieDetailsState(
      movie: movie ?? this.movie,
      tmdb: tmdb ?? this.tmdb,
      isLoadingTmdb: isLoadingTmdb ?? this.isLoadingTmdb,
      vodDetails: vodDetails ?? this.vodDetails,
      isLoadingVod: isLoadingVod ?? this.isLoadingVod,
      isFavorite: isFavorite ?? this.isFavorite,
      isSynopsisExpanded: isSynopsisExpanded ?? this.isSynopsisExpanded,
    );
  }

  // ── Derived Presentation Getters ─────────────────────────────────────────

  Map<String, dynamic>? get vodInfo =>
      vodDetails?['info'] is Map ? vodDetails!['info'] as Map<String, dynamic> : null;

  String get displayTitle => tmdb?.title.isNotEmpty == true
      ? tmdb!.title
      : (vodInfo?['name']?.toString() ?? movie.title);

  String? get displayPoster =>
      tmdb?.posterUrl ??
      vodInfo?['movie_image']?.toString() ??
      vodInfo?['cover_big']?.toString() ??
      movie.posterUrl;

  String? get displayBackdrop =>
      tmdb?.backdropUrl ??
      (vodInfo?['backdrop_path'] is List && (vodInfo!['backdrop_path'] as List).isNotEmpty
          ? (vodInfo!['backdrop_path'] as List).first.toString()
          : vodInfo?['backdrop_path']?.toString()) ??
      movie.backdropUrl;

  double? get displayRating =>
      tmdb?.rating ??
      (vodInfo?['rating'] != null ? double.tryParse(vodInfo!['rating'].toString()) : null) ??
      movie.rating;

  int? get displayYear =>
      tmdb?.releaseYear ??
      movie.releaseYear ??
      (vodInfo?['releasedate'] != null
          ? DateTime.tryParse(vodInfo!['releasedate'].toString())?.year
          : (vodInfo?['year'] != null ? int.tryParse(vodInfo!['year'].toString()) : null));

  String? get displayOverview =>
      tmdb?.overview ??
      vodInfo?['plot']?.toString() ??
      vodInfo?['description']?.toString();

  String? get displayDuration => vodInfo?['episode_run_time'] != null &&
          vodInfo!['episode_run_time'].toString() != '0'
      ? '${vodInfo!['episode_run_time']} min'
      : (vodInfo?['duration']?.toString() ??
          (vodInfo?['duration_secs'] != null
              ? '${((vodInfo!['duration_secs'] as num) ~/ 60)} min'
              : null));

  String? get displayAgeRating =>
      tmdb?.ageRating ?? vodInfo?['age']?.toString() ?? vodInfo?['mpaa_rating']?.toString();

  List<String> get displayGenres => tmdb?.genres.isNotEmpty == true
      ? tmdb!.genres
      : (vodInfo?['genre']
              ?.toString()
              .split(RegExp(r'[,/;]'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList() ??
          <String>[]);

  List<String> get displayDirectors => tmdb?.directors.isNotEmpty == true
      ? tmdb!.directors
      : (vodInfo?['director']
              ?.toString()
              .split(RegExp(r'[,;]'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList() ??
          (vodInfo?['directors']
                  ?.toString()
                  .split(RegExp(r'[,;]'))
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList() ??
              <String>[]));

  List<String> get displayCastNames => tmdb?.cast.isNotEmpty == true
      ? tmdb!.cast.map((c) => c.name).toList()
      : (vodInfo?['actors']
              ?.toString()
              .split(RegExp(r'[,;]'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList() ??
          (vodInfo?['cast']
                  ?.toString()
                  .split(RegExp(r'[,;]'))
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList() ??
              <String>[]));

  List<TmdbCastItem> get cast => tmdb?.cast ?? const [];

  List<TmdbRecommendation> get recommendations => tmdb?.recommendations ?? const [];

  String? get trailerUrl {
    final rawTrailer = tmdb?.trailerUrl ?? vodInfo?['youtube_trailer']?.toString();
    if (rawTrailer != null && rawTrailer.trim().isNotEmpty) {
      final t = rawTrailer.trim();
      return (t.startsWith('http://') || t.startsWith('https://'))
          ? t
          : 'https://www.youtube.com/watch?v=$t';
    }
    return null;
  }
}

class MovieDetailsNotifier extends StateNotifier<MovieDetailsState> {
  final Ref _ref;

  MovieDetailsNotifier(this._ref, ContentItemsTableData movie)
      : super(MovieDetailsState(movie: movie)) {
    _init();
  }

  void _init() {
    _checkFavorite();
    _fetchTmdbEnrichment();
    _fetchVodDetails();
  }

  void toggleSynopsis() {
    state = state.copyWith(isSynopsisExpanded: !state.isSynopsisExpanded);
  }

  Future<void> _checkFavorite() async {
    final db = _ref.read(databaseProvider);
    final fav = await db.isFavorite(
      state.movie.playlistId,
      'movie',
      state.movie.providerId,
    );
    state = state.copyWith(isFavorite: fav);
  }

  Future<void> toggleFavorite(BuildContext context) async {
    final db = _ref.read(databaseProvider);
    await db.toggleFavorite(
      FavoritesTableCompanion(
        playlistId: drift.Value(state.movie.playlistId),
        contentId: drift.Value(state.movie.id),
        providerId: drift.Value(state.movie.providerId),
        type: const drift.Value('movie'),
        title: drift.Value(state.movie.title),
        posterUrl: drift.Value(state.movie.posterUrl),
        backdropUrl: drift.Value(state.movie.backdropUrl),
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
      final meta = await tmdbService.searchMovie(
        state.movie.title,
        year: state.movie.releaseYear,
        apiKey: apiKey,
      );
      if (meta != null) {
        state = state.copyWith(tmdb: meta);
      }
    } catch (_) {}
    state = state.copyWith(isLoadingTmdb: false);
  }

  Future<void> _fetchVodDetails() async {
    final playlistId = state.movie.playlistId;
    final db = _ref.read(databaseProvider);
    final playlist = await db.getPlaylist(playlistId);
    if (playlist == null ||
        playlist.type != 'xtream' ||
        playlist.serverUrl == null ||
        playlist.username == null) {
      return;
    }

    final storage = _ref.read(secureStorageProvider);
    final pass = await storage.getPlaylistCredentials(playlistId);
    if (pass == null) return;

    final creds = XtreamCredentials.normalized(
      serverUrl: playlist.serverUrl!,
      username: playlist.username!,
      password: pass,
    );
    final client = XtreamClient(_ref.read(apiClientProvider).dio);

    state = state.copyWith(isLoadingVod: true);
    try {
      final data = await client.getVodInfo(creds, state.movie.providerId);
      if (data.isNotEmpty) {
        state = state.copyWith(vodDetails: data);
      }
    } catch (_) {}
    state = state.copyWith(isLoadingVod: false);
  }

  Future<void> playMovie(BuildContext context) async {
    String? url = state.movie.streamUrl;

    // If streamUrl is missing, try to reconstruct from Xtream credentials
    if (url == null || url.isEmpty) {
      try {
        final db = _ref.read(databaseProvider);
        final playlist = await db.getPlaylist(state.movie.playlistId);
        if (playlist != null && playlist.type == 'xtream' &&
            playlist.serverUrl != null && playlist.username != null) {
          final storage = _ref.read(secureStorageProvider);
          final pass = await storage.getPlaylistCredentials(state.movie.playlistId);
          if (pass != null) {
            final creds = XtreamCredentials.normalized(
              serverUrl: playlist.serverUrl!,
              username: playlist.username!,
              password: pass,
            );
            final client = XtreamClient(_ref.read(apiClientProvider).dio);
            final ext = state.movie.containerExtension ?? 'mp4';
            url = client.buildVodStreamUrl(creds, state.movie.providerId, ext);
          }
        }
      } catch (_) {}
    }

    if (url == null || url.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Stream URL unavailable for this movie.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final player = _ref.read(playerControllerProvider.notifier);
    final item = MediaItem(
      id: state.movie.providerId,
      title: state.displayTitle,
      type: MediaType.movie,
      posterUrl: state.displayPoster,
      backdropUrl: state.displayBackdrop,
      streamUrl: url,
      playlistId: state.movie.playlistId,
      providerId: state.movie.providerId,
      contentDbId: state.movie.id,
    );

    if (context.mounted) Navigator.of(context).pop();
    player.playItem(item, startFullscreen: true);
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

  void downloadMovie(BuildContext context) {
    if (state.movie.streamUrl == null || state.movie.streamUrl!.isEmpty) return;

    _ref.read(downloadNotifierProvider.notifier).startDownload(
          id: state.movie.providerId,
          title: state.movie.title,
          streamUrl: state.movie.streamUrl!,
          posterUrl: state.displayPoster,
          extension: state.movie.containerExtension,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading "${state.displayTitle}" for offline playback'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

final movieDetailsProvider = StateNotifierProvider.autoDispose
    .family<MovieDetailsNotifier, MovieDetailsState, ContentItemsTableData>(
  (ref, movie) => MovieDetailsNotifier(ref, movie),
);
