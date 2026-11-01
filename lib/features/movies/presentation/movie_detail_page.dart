import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/theme/app_colors.dart';
import '../../../core/persistence/app_database.dart';
import '../../../core/persistence/database_provider.dart';
import '../../../shared/models/media_item.dart';
import '../../../shared/services/tmdb_service.dart';
import '../../player/data/player_controller.dart';
import '../../player/data/external_player_service.dart';
import '../../downloads/data/download_service.dart';
import '../../xtream/data/xtream_client.dart';

class MovieDetailPage extends ConsumerStatefulWidget {
  final ContentItemsTableData movie;

  const MovieDetailPage({super.key, required this.movie});

  @override
  ConsumerState<MovieDetailPage> createState() => _MovieDetailPageState();
}

class _MovieDetailPageState extends ConsumerState<MovieDetailPage> {
  TmdbMetadata? _tmdb;
  bool _isLoadingTmdb = false;
  Map<String, dynamic>? _vodDetails;
  bool _isLoadingVod = false;
  bool _isFavorite = false;
  bool _synopsisExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchTmdbEnrichment();
    _fetchVodDetails();
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    final db = ref.read(databaseProvider);
    final fav = await db.isFavorite(
      widget.movie.playlistId,
      'movie',
      widget.movie.providerId,
    );
    if (mounted) setState(() => _isFavorite = fav);
  }

  Future<void> _toggleFavorite(String displayTitle, String? displayPoster) async {
    final db = ref.read(databaseProvider);
    await db.toggleFavorite(
      FavoritesTableCompanion(
        playlistId: drift.Value(widget.movie.playlistId),
        contentId: drift.Value(widget.movie.id),
        providerId: drift.Value(widget.movie.providerId),
        type: const drift.Value('movie'),
        title: drift.Value(widget.movie.title),
        posterUrl: drift.Value(widget.movie.posterUrl),
        backdropUrl: drift.Value(widget.movie.backdropUrl),
      ),
    );
    if (mounted) {
      setState(() => _isFavorite = !_isFavorite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite
                ? 'Added "$displayTitle" to My List'
                : 'Removed "$displayTitle" from My List',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _fetchTmdbEnrichment() async {
    final tmdbService = ref.read(tmdbServiceProvider);
    final apiKey = await tmdbService.getApiKey();
    if (apiKey == null || apiKey.isEmpty) return;
    setState(() => _isLoadingTmdb = true);
    try {
      final meta = await tmdbService.searchMovie(
        widget.movie.title,
        year: widget.movie.releaseYear,
        apiKey: apiKey,
      );
      if (mounted && meta != null) setState(() => _tmdb = meta);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingTmdb = false);
  }

  Future<void> _fetchVodDetails() async {
    final playlistId = widget.movie.playlistId;
    final db = ref.read(databaseProvider);
    final playlist = await db.getPlaylist(playlistId);
    if (playlist == null ||
        playlist.type != 'xtream' ||
        playlist.serverUrl == null ||
        playlist.username == null) {
      return;
    }
    final storage = ref.read(secureStorageProvider);
    final pass = await storage.getPlaylistCredentials(playlistId);
    if (pass == null) return;
    final creds = XtreamCredentials.normalized(
      serverUrl: playlist.serverUrl!,
      username: playlist.username!,
      password: pass,
    );
    final client = XtreamClient(ref.read(apiClientProvider).dio);
    setState(() => _isLoadingVod = true);
    try {
      final data = await client.getVodInfo(creds, widget.movie.providerId);
      if (mounted && data.isNotEmpty) setState(() => _vodDetails = data);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingVod = false);
  }

  @override
  Widget build(BuildContext context) {
    final player = ref.read(playerControllerProvider.notifier);
    final movie = widget.movie;
    final vodInfo = _vodDetails?['info'] is Map ? _vodDetails!['info'] as Map : null;

    final displayTitle = _tmdb?.title.isNotEmpty == true
        ? _tmdb!.title
        : (vodInfo?['name']?.toString() ?? movie.title);

    final displayPoster = _tmdb?.posterUrl ??
        vodInfo?['movie_image']?.toString() ??
        vodInfo?['cover_big']?.toString() ??
        movie.posterUrl;

    final displayBackdrop = _tmdb?.backdropUrl ??
        (vodInfo?['backdrop_path'] is List &&
                (vodInfo!['backdrop_path'] as List).isNotEmpty
            ? (vodInfo['backdrop_path'] as List).first.toString()
            : vodInfo?['backdrop_path']?.toString()) ??
        movie.backdropUrl;

    final displayRating = _tmdb?.rating ??
        (vodInfo?['rating'] != null
            ? double.tryParse(vodInfo!['rating'].toString())
            : null) ??
        movie.rating;

    final displayYear = _tmdb?.releaseYear ??
        movie.releaseYear ??
        (vodInfo?['releasedate'] != null
            ? DateTime.tryParse(vodInfo!['releasedate'].toString())?.year
            : (vodInfo?['year'] != null
                ? int.tryParse(vodInfo!['year'].toString())
                : null));

    final displayOverview = _tmdb?.overview ??
        vodInfo?['plot']?.toString() ??
        vodInfo?['description']?.toString();

    final displayDuration = vodInfo?['episode_run_time'] != null &&
            vodInfo!['episode_run_time'].toString() != '0'
        ? '${vodInfo['episode_run_time']} min'
        : (vodInfo?['duration']?.toString() ??
            (vodInfo?['duration_secs'] != null
                ? '${((vodInfo!['duration_secs'] as num) ~/ 60)} min'
                : null));

    final displayAgeRating = _tmdb?.ageRating ??
        vodInfo?['age']?.toString() ??
        vodInfo?['mpaa_rating']?.toString();

    final displayGenres = _tmdb?.genres.isNotEmpty == true
        ? _tmdb!.genres
        : (vodInfo?['genre']
                ?.toString()
                .split(RegExp(r'[,/;]'))
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList() ??
            <String>[]);

    final displayDirectors = _tmdb?.directors.isNotEmpty == true
        ? _tmdb!.directors
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

    final displayCastNames = _tmdb?.cast.isNotEmpty == true
        ? _tmdb!.cast.map((c) => c.name).toList()
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

    final rawTrailer = _tmdb?.trailerUrl ?? vodInfo?['youtube_trailer']?.toString();
    String? trailerUrl;
    if (rawTrailer != null && rawTrailer.trim().isNotEmpty) {
      final t = rawTrailer.trim();
      trailerUrl = (t.startsWith('http://') || t.startsWith('https://'))
          ? t
          : 'https://www.youtube.com/watch?v=$t';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          // ── Cinematic Hero SliverAppBar ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: 380,
            pinned: true,
            backgroundColor: const Color(0xFF0A0A0F),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Backdrop or poster image
                  displayBackdrop != null
                      ? CachedNetworkImage(
                          imageUrl: displayBackdrop,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorWidget: (_, __, ___) => _buildBackdropFallback(displayPoster),
                        )
                      : _buildBackdropFallback(displayPoster),
                  // Gradient overlay
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xFF0A0A0F)],
                        stops: [0.4, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Content Section ──────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poster + Title + Metadata Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Poster (offset upward to overlap the hero)
                      Transform.translate(
                        offset: const Offset(0, -40),
                        child: _buildPoster(displayPoster),
                      ),
                      const SizedBox(width: 16),
                      // Title & metadata
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Metadata row
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 10,
                              runSpacing: 6,
                              children: [
                                if (displayYear != null)
                                  Text(
                                    displayYear.toString(),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 13,
                                    ),
                                  ),
                                if (displayDuration != null && displayDuration.isNotEmpty)
                                  _metaBadge(displayDuration),
                                if (displayRating != null && displayRating > 0)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          color: Colors.amber, size: 15),
                                      const SizedBox(width: 3),
                                      Text(
                                        displayRating.toStringAsFixed(1),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (displayAgeRating != null && displayAgeRating.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.white38),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      displayAgeRating,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                if (_isLoadingTmdb || _isLoadingVod)
                                  const SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: Colors.white54,
                                    ),
                                  ),
                              ],
                            ),
                            // Genre chips
                            if (displayGenres.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: displayGenres.map((g) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 9, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      g,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 11,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Compensate for poster's negative offset
                  const SizedBox(height: 4),

                  // ── Action Buttons ──────────────────────────────────────────
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      // Play Movie
                      if (movie.streamUrl != null && movie.streamUrl!.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () {
                            final item = MediaItem(
                              id: movie.providerId,
                              title: movie.title,
                              type: MediaType.movie,
                              posterUrl: displayPoster,
                              backdropUrl: displayBackdrop,
                              streamUrl: movie.streamUrl,
                              playlistId: movie.playlistId,
                              providerId: movie.providerId,
                              contentDbId: movie.id,
                            );
                            player.playItem(item, startFullscreen: true);
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play Movie'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 13),
                          ),
                        ),
                      // Watch Trailer
                      if (trailerUrl != null)
                        OutlinedButton.icon(
                          onPressed: () {
                            ExternalPlayerService.openUrl(trailerUrl!);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Opening trailer for "$displayTitle" in browser'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.movie_creation_rounded,
                              color: Colors.amber, size: 18),
                          label: const Text('Watch Trailer',
                              style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder(),
                            side: const BorderSide(color: Colors.amber),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 13),
                          ),
                        ),
                      // My List toggle
                      OutlinedButton.icon(
                        onPressed: () => _toggleFavorite(displayTitle, displayPoster),
                        icon: Icon(
                          _isFavorite
                              ? Icons.check_rounded
                              : Icons.add_rounded,
                          color: _isFavorite ? AppColors.primary : Colors.white70,
                          size: 18,
                        ),
                        label: Text(
                          _isFavorite ? 'In My List' : '+ My List',
                          style: TextStyle(
                              color:
                                  _isFavorite ? AppColors.primary : Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                          side: BorderSide(
                            color: _isFavorite
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.25),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 13),
                        ),
                      ),
                      // Download
                      if (movie.streamUrl != null && movie.streamUrl!.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () {
                            ref
                                .read(downloadNotifierProvider.notifier)
                                .startDownload(
                                  id: movie.providerId,
                                  title: movie.title,
                                  streamUrl: movie.streamUrl!,
                                  posterUrl: displayPoster,
                                  extension: movie.containerExtension,
                                );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Downloading "$displayTitle" for offline playback'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          icon: const Icon(Icons.download_rounded,
                              color: Colors.white70, size: 18),
                          label: const Text('Download',
                              style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            shape: const StadiumBorder(),
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.25)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 13),
                          ),
                        ),
                    ],
                  ),

                  // ── Synopsis ────────────────────────────────────────────────
                  if (displayOverview != null && displayOverview.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Synopsis',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      displayOverview,
                      maxLines: _synopsisExpanded ? null : 3,
                      overflow: _synopsisExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () =>
                          setState(() => _synopsisExpanded = !_synopsisExpanded),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          _synopsisExpanded ? 'LESS' : 'MORE',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],

                  // ── Director ────────────────────────────────────────────────
                  if (displayDirectors.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Director: ',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: displayDirectors.join(', '),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Cast (TMDB avatars or name chips) ───────────────────────
                  if (_tmdb?.cast.isNotEmpty == true) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Cast',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 115,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _tmdb!.cast.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, idx) {
                          final actor = _tmdb!.cast[idx];
                          return SizedBox(
                            width: 70,
                            child: Column(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.white12,
                                  backgroundImage: actor.profileUrl != null
                                      ? CachedNetworkImageProvider(actor.profileUrl!)
                                      : null,
                                  child: actor.profileUrl == null
                                      ? const Icon(Icons.person,
                                          color: Colors.white38)
                                      : null,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  actor.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (actor.character != null)
                                  Text(
                                    actor.character!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 10),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ] else if (displayCastNames.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Cast',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: displayCastNames.take(10).map((actorName) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.person_outline_rounded,
                                  size: 14, color: Colors.white54),
                              const SizedBox(width: 6),
                              Text(
                                actorName,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11.5),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // ── More Like This ──────────────────────────────────────────
                  if (_tmdb?.recommendations.isNotEmpty == true) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'More Like This',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 165,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _tmdb!.recommendations.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, idx) {
                          final rec = _tmdb!.recommendations[idx];
                          return SizedBox(
                            width: 95,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: rec.posterUrl != null
                                      ? CachedNetworkImage(
                                          imageUrl: rec.posterUrl!,
                                          width: 95,
                                          height: 135,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              _recFallback(),
                                        )
                                      : _recFallback(),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  rec.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 11),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  // Bottom safe-area padding
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────────────

  Widget _buildBackdropFallback(String? posterUrl) {
    if (posterUrl != null) {
      return CachedNetworkImage(
        imageUrl: posterUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        errorWidget: (_, __, ___) =>
            const ColoredBox(color: Color(0xFF1A1A2E)),
      );
    }
    return const ColoredBox(color: Color(0xFF1A1A2E));
  }

  Widget _buildPoster(String? posterUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: posterUrl != null
          ? CachedNetworkImage(
              imageUrl: posterUrl,
              width: 110,
              height: 165,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _posterFallback(),
            )
          : _posterFallback(),
    );
  }

  Widget _posterFallback() {
    return Container(
      width: 110,
      height: 165,
      color: Colors.white12,
      child: const Icon(Icons.movie_rounded, color: Colors.white38),
    );
  }

  Widget _recFallback() {
    return Container(
      width: 95,
      height: 135,
      color: Colors.white12,
      child: const Icon(Icons.movie, color: Colors.white24),
    );
  }

  Widget _metaBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
