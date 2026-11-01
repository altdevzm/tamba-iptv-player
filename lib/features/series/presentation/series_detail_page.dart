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
import '../../xtream/data/xtream_client.dart';
import '../../stalker/data/stalker_client.dart';

class SeriesDetailPage extends ConsumerStatefulWidget {
  final ContentItemsTableData series;
  const SeriesDetailPage({super.key, required this.series});

  @override
  ConsumerState<SeriesDetailPage> createState() => _SeriesDetailPageState();
}

class _SeriesDetailPageState extends ConsumerState<SeriesDetailPage> {
  TmdbMetadata? _tmdb;
  bool _isLoadingTmdb = false;
  bool _isLoadingEpisodes = false;
  Map<String, List<Map<String, dynamic>>> _episodesBySeason = {};
  String? _selectedSeason;
  String? _fetchEpisodesError;
  Map<String, dynamic>? _seriesDetailsInfo;
  bool _isFavorite = false;
  XtreamCredentials? _xtreamCreds;
  XtreamClient? _xtreamClient;
  StalkerCredentials? _stalkerCreds;
  StalkerClient? _stalkerClient;
  bool _synopsisExpanded = false;

  @override
  void initState() {
    super.initState();
    _fetchTmdbEnrichment();
    _fetchEpisodes();
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    final db = ref.read(databaseProvider);
    final fav = await db.isFavorite(
        widget.series.playlistId, 'series', widget.series.providerId);
    if (mounted) setState(() => _isFavorite = fav);
  }

  Future<void> _toggleFavorite() async {
    final db = ref.read(databaseProvider);
    await db.toggleFavorite(
      FavoritesTableCompanion(
        playlistId: drift.Value(widget.series.playlistId),
        contentId: drift.Value(widget.series.id),
        providerId: drift.Value(widget.series.providerId),
        type: const drift.Value('series'),
        title: drift.Value(widget.series.title),
        posterUrl: drift.Value(widget.series.posterUrl),
        backdropUrl: drift.Value(widget.series.backdropUrl),
      ),
    );
    if (mounted) {
      setState(() => _isFavorite = !_isFavorite);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFavorite
              ? 'Added "${widget.series.title}" to My List'
              : 'Removed "${widget.series.title}" from My List'),
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
      final meta = await tmdbService.searchSeries(
        widget.series.title,
        apiKey: apiKey,
      );
      if (mounted && meta != null) setState(() => _tmdb = meta);
    } catch (_) {}
    if (mounted) setState(() => _isLoadingTmdb = false);
  }

  Future<void> _fetchEpisodes() async {
    final playlistId = widget.series.playlistId;
    final db = ref.read(databaseProvider);
    final playlist = await db.getPlaylist(playlistId);
    if (playlist == null) return;

    final dio = ref.read(apiClientProvider).dio;

    if (playlist.type == 'xtream') {
      final storage = ref.read(secureStorageProvider);
      final password = await storage.getPlaylistCredentials(playlistId);
      if (password == null ||
          playlist.serverUrl == null ||
          playlist.username == null) {
        if (mounted) {
          setState(() {
            _fetchEpisodesError = 'Playlist credentials missing.';
            _isLoadingEpisodes = false;
          });
        }
        return;
      }
      final creds = XtreamCredentials.normalized(
        serverUrl: playlist.serverUrl!,
        username: playlist.username!,
        password: password,
      );
      final client = XtreamClient(dio);
      setState(() {
        _isLoadingEpisodes = true;
        _fetchEpisodesError = null;
      });
      try {
        final info = await client.getSeriesInfo(creds, widget.series.providerId);
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

        if (mounted) {
          setState(() {
            _episodesBySeason = parsed;
            _selectedSeason =
                parsed.keys.isNotEmpty ? parsed.keys.first : null;
            _seriesDetailsInfo = info['info'] is Map
                ? Map<String, dynamic>.from(info['info'])
                : null;
            _xtreamCreds = creds;
            _xtreamClient = client;
            if (parsed.isEmpty) {
              _fetchEpisodesError = 'No episodes returned by provider.';
            }
          });
        }
      } catch (e) {
        if (mounted) setState(() => _fetchEpisodesError = e.toString());
      }
      if (mounted) setState(() => _isLoadingEpisodes = false);
    } else if (playlist.type == 'stalker' &&
        playlist.serverUrl != null &&
        playlist.macAddress != null) {
      final stalkerCreds = StalkerCredentials(
        serverUrl: playlist.serverUrl!,
        macAddress: playlist.macAddress!,
      );
      final client = StalkerClient(dio);
      setState(() => _isLoadingEpisodes = true);
      try {
        await client.handshake(stalkerCreds);
        final rawEpisodes =
            await client.getSeriesEpisodes(stalkerCreds, widget.series.providerId);
        if (mounted && rawEpisodes.isNotEmpty) {
          final parsed = <String, List<Map<String, dynamic>>>{};
          for (final ep in rawEpisodes) {
            final season =
                ep['season']?.toString() ?? ep['season_id']?.toString() ?? '1';
            parsed.putIfAbsent(season, () => []).add(ep);
          }
          setState(() {
            _episodesBySeason = parsed;
            _selectedSeason =
                parsed.keys.isNotEmpty ? parsed.keys.first : null;
            _stalkerCreds = stalkerCreds;
            _stalkerClient = client;
          });
        }
      } catch (_) {}
      if (mounted) setState(() => _isLoadingEpisodes = false);
    }
  }

  void _playEpisode(Map<String, dynamic> ep, int idx) async {
    final series = widget.series;
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

    // Compute display values needed for playback
    final displayPoster = _tmdb?.posterUrl ??
        _seriesDetailsInfo?['cover']?.toString() ??
        series.posterUrl;
    final displayBackdrop = _tmdb?.backdropUrl ??
        (_seriesDetailsInfo?['backdrop_path'] is List &&
                (_seriesDetailsInfo!['backdrop_path'] as List).isNotEmpty
            ? (_seriesDetailsInfo!['backdrop_path'] as List).first.toString()
            : _seriesDetailsInfo?['backdrop_path']?.toString()) ??
        series.backdropUrl;

    String? streamUrl;
    if (_xtreamCreds != null && _xtreamClient != null && epId.isNotEmpty) {
      streamUrl =
          _xtreamClient!.buildSeriesStreamUrl(_xtreamCreds!, epId, containerExt);
    } else if (_stalkerCreds != null && _stalkerClient != null) {
      final cmd = ep['cmd']?.toString();
      if (cmd != null && cmd.isNotEmpty) {
        streamUrl = await _stalkerClient!
            .createLink(_stalkerCreds!, type: 'vod', cmd: cmd);
      }
    }

    if (streamUrl != null && streamUrl.isNotEmpty && mounted) {
      final player = ref.read(playerControllerProvider.notifier);
      player.playItem(
        MediaItem(
          id: epId.isNotEmpty ? epId : (ep['cmd']?.toString() ?? 'ep_$idx'),
          title:
              '${series.title} - S$_selectedSeason E$epNum: $epTitle',
          type: MediaType.series,
          posterUrl: epThumbnail ?? displayPoster,
          backdropUrl: displayBackdrop,
          streamUrl: streamUrl,
          playlistId: series.playlistId,
          providerId:
              epId.isNotEmpty ? epId : (ep['cmd']?.toString() ?? 'ep_$idx'),
          seriesProviderId: series.providerId,
          seasonNumber: int.tryParse(_selectedSeason ?? ''),
          episodeNumber: int.tryParse(epNum),
        ),
        startFullscreen: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final series = widget.series;

    final displayPoster = _tmdb?.posterUrl ??
        _seriesDetailsInfo?['cover']?.toString() ??
        series.posterUrl;
    final displayBackdrop = _tmdb?.backdropUrl ??
        (_seriesDetailsInfo?['backdrop_path'] is List &&
                (_seriesDetailsInfo!['backdrop_path'] as List).isNotEmpty
            ? (_seriesDetailsInfo!['backdrop_path'] as List).first.toString()
            : _seriesDetailsInfo?['backdrop_path']?.toString()) ??
        series.backdropUrl;
    final displayRating = _tmdb?.rating ??
        (_seriesDetailsInfo?['rating'] != null
            ? double.tryParse(_seriesDetailsInfo!['rating'].toString())
            : null) ??
        series.rating;
    final displayOverview = _tmdb?.overview ??
        _seriesDetailsInfo?['plot']?.toString() ??
        _seriesDetailsInfo?['description']?.toString();
    final displayGenres = _tmdb?.genres.isNotEmpty == true
        ? _tmdb!.genres
        : (_seriesDetailsInfo?['genre']
                ?.toString()
                .split(RegExp(r'[,/;]'))
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList() ??
            <String>[]);
    final displayCreators = _tmdb?.directors.isNotEmpty == true
        ? _tmdb!.directors
        : (_seriesDetailsInfo?['director']
                ?.toString()
                .split(RegExp(r'[,;]'))
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList() ??
            (_seriesDetailsInfo?['cast']
                    ?.toString()
                    .split(RegExp(r'[,;]'))
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList() ??
                <String>[]));

    final rawTrailer =
        _tmdb?.trailerUrl ?? _seriesDetailsInfo?['youtube_trailer']?.toString();
    String? trailerUrl;
    if (rawTrailer != null && rawTrailer.trim().isNotEmpty) {
      final t = rawTrailer.trim();
      trailerUrl = (t.startsWith('http://') || t.startsWith('https://'))
          ? t
          : 'https://www.youtube.com/watch?v=$t';
    }

    final currentEpisodes = _selectedSeason != null
        ? (_episodesBySeason[_selectedSeason] ?? [])
        : <Map<String, dynamic>>[];

    final seasonsCount = _episodesBySeason.keys.length;
    final displayTitle =
        _tmdb?.title.isNotEmpty == true ? _tmdb!.title : series.title;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          // ── Cinematic Backdrop SliverAppBar ──
          SliverAppBar(
            expandedHeight: 360,
            pinned: true,
            backgroundColor: const Color(0xFF0A0A0F),
            leading: const BackButton(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Backdrop image
                  if (displayBackdrop != null && displayBackdrop.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: displayBackdrop,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _buildBackdropFallback(),
                      placeholder: (_, __) => _buildBackdropFallback(),
                    )
                  else
                    _buildBackdropFallback(),
                  // Gradient overlay — bottom fade into background
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Color(0x660A0A0F),
                          Color(0xFF0A0A0F),
                        ],
                        stops: [0.3, 0.7, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body Content ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Poster + Title row ──
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Poster floats up into the backdrop
                      Transform.translate(
                        offset: const Offset(0, -40),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: displayPoster != null &&
                                  displayPoster.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: displayPoster,
                                  width: 110,
                                  height: 165,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      _buildPosterFallback(),
                                  placeholder: (_, __) =>
                                      _buildPosterFallback(),
                                )
                              : _buildPosterFallback(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Title + metadata column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              displayTitle,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Metadata row
                            Wrap(
                              spacing: 10,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (series.releaseYear != null ||
                                    _tmdb?.releaseYear != null)
                                  Text(
                                    (_tmdb?.releaseYear ?? series.releaseYear)
                                        .toString(),
                                    style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.6),
                                      fontSize: 13,
                                    ),
                                  ),
                                if (seasonsCount > 0)
                                  Text(
                                    '$seasonsCount Season${seasonsCount == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.6),
                                      fontSize: 13,
                                    ),
                                  ),
                                if (displayRating != null &&
                                    displayRating > 0) ...[
                                  const Icon(Icons.star_rounded,
                                      color: Colors.amber, size: 14),
                                  Text(
                                    displayRating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                                if (_tmdb?.ageRating != null &&
                                    _tmdb!.ageRating!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      border:
                                          Border.all(color: Colors.white38),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _tmdb!.ageRating!,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                if (_isLoadingTmdb || _isLoadingEpisodes)
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: Colors.white54),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Genre chips
                            if (displayGenres.isNotEmpty)
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: displayGenres.map((g) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      g,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.7),
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 6),
                            // Creators/directors
                            if (displayCreators.isNotEmpty)
                              Text(
                                'Creators: ${displayCreators.join(', ')}',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 11.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // ── Action Buttons ──
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      // Play Series — only if a direct streamUrl is available
                      if (series.streamUrl != null &&
                          series.streamUrl!.isNotEmpty)
                        ElevatedButton.icon(
                          onPressed: () {
                            final player =
                                ref.read(playerControllerProvider.notifier);
                            player.playItem(
                              MediaItem(
                                id: series.providerId,
                                title: series.title,
                                type: MediaType.series,
                                posterUrl: displayPoster,
                                backdropUrl: displayBackdrop,
                                streamUrl: series.streamUrl,
                                playlistId: series.playlistId,
                                providerId: series.providerId,
                                contentDbId: series.id,
                              ),
                              startFullscreen: true,
                            );
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Play Series'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 11),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      // Watch Trailer — only if available
                      if (trailerUrl != null)
                        OutlinedButton.icon(
                          onPressed: () {
                            ExternalPlayerService.openUrl(trailerUrl!);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Opening trailer for "${series.title}" in browser'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(Icons.smart_display_rounded,
                              color: Colors.amber, size: 18),
                          label: const Text('Watch Trailer',
                              style: TextStyle(color: Colors.white)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 11),
                            side: const BorderSide(color: Colors.amber),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      // My List toggle
                      OutlinedButton.icon(
                        onPressed: _toggleFavorite,
                        icon: Icon(
                          _isFavorite
                              ? Icons.bookmark_added_rounded
                              : Icons.bookmark_add_outlined,
                          color: _isFavorite
                              ? AppColors.primary
                              : Colors.white70,
                          size: 18,
                        ),
                        label: Text(
                          _isFavorite ? 'In My List' : 'My List',
                          style: TextStyle(
                              color: _isFavorite
                                  ? AppColors.primary
                                  : Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 11),
                          side: BorderSide(
                            color: _isFavorite
                                ? AppColors.primary
                                : Colors.white.withValues(alpha: 0.2),
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Synopsis ──
                  if (displayOverview != null && displayOverview.isNotEmpty) ...[
                    const Text(
                      'Synopsis',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _synopsisExpanded = !_synopsisExpanded),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayOverview,
                            maxLines: _synopsisExpanded ? null : 3,
                            overflow: _synopsisExpanded
                                ? TextOverflow.visible
                                : TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _synopsisExpanded ? 'Show less' : 'Read more',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Cast ──
                  if (_tmdb?.cast.isNotEmpty == true) ...[
                    const Text(
                      'Cast',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 80,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _tmdb!.cast.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 16),
                        itemBuilder: (ctx, idx) {
                          final actor = _tmdb!.cast[idx];
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Colors.white12,
                                backgroundImage: actor.profileUrl != null
                                    ? CachedNetworkImageProvider(
                                        actor.profileUrl!)
                                    : null,
                                child: actor.profileUrl == null
                                    ? const Icon(Icons.person,
                                        color: Colors.white38, size: 22)
                                    : null,
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  actor.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ] else if (_tmdb?.cast.isEmpty != false &&
                      _seriesDetailsInfo?['cast'] != null) ...[
                    // Fallback: show cast from series info as name chips
                    const Text(
                      'Cast',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: (_seriesDetailsInfo!['cast']
                                  ?.toString()
                                  .split(RegExp(r'[,;]'))
                                  .map((s) => s.trim())
                                  .where((s) => s.isNotEmpty)
                                  .toList() ??
                              <String>[])
                          .map<Widget>((name) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Text(
                            name,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 12),

                  // ── Seasons & Episodes header ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Seasons & Episodes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_isLoadingEpisodes)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.primary),
                        ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ── Season selector tabs ──
                  if (_episodesBySeason.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _episodesBySeason.keys.map((season) {
                          final isSelected = season == _selectedSeason;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text('Season $season'),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.08),
                              labelStyle: TextStyle(
                                color:
                                    isSelected ? Colors.white : Colors.white70,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 12,
                              ),
                              onSelected: (val) {
                                if (val) {
                                  setState(() => _selectedSeason = season);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // ── Episodes list ──
                  if (currentEpisodes.isNotEmpty)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: currentEpisodes.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final ep = currentEpisodes[idx];
                        final epTitle =
                            ep['title']?.toString() ?? 'Episode ${idx + 1}';
                        final epNum =
                            ep['episode_num']?.toString() ?? '${idx + 1}';
                        final epInfo =
                            ep['info'] is Map ? ep['info'] as Map : null;
                        final rawImg =
                            epInfo?['movie_image']?.toString() ??
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
                        final epPlot = epInfo?['plot']?.toString() ??
                            ep['plot']?.toString() ??
                            epInfo?['description']?.toString() ??
                            ep['description']?.toString();
                        final epDuration =
                            epInfo?['duration']?.toString() ??
                                (epInfo?['duration_secs'] != null
                                    ? '${((epInfo!['duration_secs'] as num) ~/ 60)} min'
                                    : null);
                        final epRating = epInfo?['rating'] != null
                            ? double.tryParse(
                                epInfo!['rating'].toString())
                            : null;

                        return InkWell(
                          onTap: () => _playEpisode(ep, idx),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      Colors.white.withValues(alpha: 0.07)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Thumbnail with play overlay + EP badge
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 125,
                                        height: 72,
                                        color: Colors.white10,
                                        child: epThumbnail != null
                                            ? CachedNetworkImage(
                                                imageUrl: epThumbnail,
                                                width: 125,
                                                height: 72,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) =>
                                                    _buildEpisodeFallback(
                                                        epNum, displayPoster),
                                                placeholder: (_, __) =>
                                                    Container(
                                                        color: Colors.white12),
                                              )
                                            : _buildEpisodeFallback(
                                                epNum, displayPoster),
                                      ),
                                      // Play icon overlay
                                      Positioned.fill(
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.5),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.play_arrow_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Episode number badge
                                      Positioned(
                                        bottom: 4,
                                        left: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black
                                                .withValues(alpha: 0.75),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'EP $epNum',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Episode info column
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              epTitle,
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          if (epDuration != null &&
                                              epDuration.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              epDuration,
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.5),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                          if (epRating != null &&
                                              epRating > 0) ...[
                                            const SizedBox(width: 8),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                    Icons.star_rounded,
                                                    color: Colors.amber,
                                                    size: 12),
                                                const SizedBox(width: 2),
                                                Text(
                                                  epRating.toStringAsFixed(1),
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (epPlot != null &&
                                          epPlot.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          epPlot,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.65),
                                            fontSize: 12,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Play icon button
                                IconButton(
                                  icon: const Icon(
                                      Icons.play_circle_fill_rounded,
                                      color: AppColors.primary,
                                      size: 30),
                                  onPressed: () => _playEpisode(ep, idx),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  else
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 20),
                        child: Text(
                          _isLoadingEpisodes
                              ? 'Loading episodes from provider...'
                              : (_fetchEpisodesError ??
                                  'No episodes found for this series.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _fetchEpisodesError != null
                                ? Colors.redAccent
                                : Colors.white.withValues(alpha: 0.4),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────── Helper builders ───────────────────────────

  Widget _buildBackdropFallback() {
    return Container(
      color: const Color(0xFF141419),
      child: Center(
        child: Icon(Icons.tv_rounded,
            size: 64, color: Colors.white.withValues(alpha: 0.08)),
      ),
    );
  }

  Widget _buildPosterFallback() {
    return Container(
      width: 110,
      height: 165,
      color: Colors.white12,
      child: const Icon(Icons.tv_rounded, color: Colors.white38),
    );
  }

  Widget _buildEpisodeFallback(String epNum, String? poster) {
    if (poster != null && poster.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: poster,
        width: 125,
        height: 72,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _buildEpisodeNumBadge(epNum),
      );
    }
    return _buildEpisodeNumBadge(epNum);
  }

  Widget _buildEpisodeNumBadge(String epNum) {
    return Container(
      width: 125,
      height: 72,
      color: Colors.white.withValues(alpha: 0.08),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tv_rounded, color: Colors.white38, size: 22),
            const SizedBox(height: 4),
            Text(
              'Episode $epNum',
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
