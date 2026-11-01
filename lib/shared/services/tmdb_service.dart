import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../../core/persistence/database_provider.dart';

class TmdbCastItem {
  final int? id;
  final String name;
  final String? character;
  final String? profilePath;

  const TmdbCastItem({
    this.id,
    required this.name,
    this.character,
    this.profilePath,
  });

  String? get profileUrl => profilePath != null
      ? 'https://image.tmdb.org/t/p/w185$profilePath'
      : null;
}

class TmdbRecommendation {
  final int id;
  final String title;
  final String? posterPath;
  final double? rating;
  final int? releaseYear;
  final String mediaType; // 'movie' or 'tv'

  const TmdbRecommendation({
    required this.id,
    required this.title,
    this.posterPath,
    this.rating,
    this.releaseYear,
    this.mediaType = 'movie',
  });

  String? get posterUrl => posterPath != null
      ? 'https://image.tmdb.org/t/p/w342$posterPath'
      : null;
}

class TmdbVideoItem {
  final String id;
  final String name;
  final String key;
  final String site;
  final String type;

  const TmdbVideoItem({
    required this.id,
    required this.name,
    required this.key,
    required this.site,
    required this.type,
  });

  String get youtubeUrl => 'https://www.youtube.com/watch?v=$key';
  String get thumbnailUrl => 'https://img.youtube.com/vi/$key/mqdefault.jpg';
}

class TmdbEpisodeDetail {
  final int episodeNumber;
  final String name;
  final String? overview;
  final String? stillPath;
  final double? rating;

  const TmdbEpisodeDetail({
    required this.episodeNumber,
    required this.name,
    this.overview,
    this.stillPath,
    this.rating,
  });

  String? get stillUrl => stillPath != null
      ? 'https://image.tmdb.org/t/p/w300$stillPath'
      : null;
}

class TmdbMetadata {
  final int id;
  final String title;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final double? rating;
  final int? releaseYear;
  final List<String> genres;
  final List<TmdbCastItem> cast;
  final List<String> directors;
  final String? trailerYoutubeKey;
  final String? ageRating;
  final List<TmdbRecommendation> recommendations;
  final int? seasonsCount;
  final List<TmdbVideoItem> videos;

  const TmdbMetadata({
    required this.id,
    required this.title,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.rating,
    this.releaseYear,
    this.genres = const [],
    this.cast = const [],
    this.directors = const [],
    this.trailerYoutubeKey,
    this.ageRating,
    this.recommendations = const [],
    this.seasonsCount,
    this.videos = const [],
  });

  String? get posterUrl => posterPath != null
      ? 'https://image.tmdb.org/t/p/w500$posterPath'
      : null;

  String? get backdropUrl => backdropPath != null
      ? 'https://image.tmdb.org/t/p/w1280$backdropPath'
      : null;

  String? get trailerUrl => trailerYoutubeKey != null
      ? 'https://www.youtube.com/watch?v=$trailerYoutubeKey'
      : null;
}

class TmdbService {
  final Dio _dio;
  final SecureStorageService _storage;
  static const _tmdbKeyStorageKey = 'filimu_tmdb_api_key';
  static const _tmdbLangStorageKey = 'filimu_tmdb_language';
  static const _tmdbCountryStorageKey = 'filimu_tmdb_country';

  // In-memory caches to prevent rate limiting & excessive requests
  final Map<String, TmdbMetadata> _movieDetailsCache = {};
  final Map<String, TmdbMetadata> _tvDetailsCache = {};
  final Map<String, List<TmdbEpisodeDetail>> _seasonDetailsCache = {};

  TmdbService(this._dio, this._storage);

  Future<String?> getApiKey() async {
    return _storage.getPlaylistCredentials(_tmdbKeyStorageKey);
  }

  Future<void> saveApiKey(String apiKey) async {
    await _storage.savePlaylistCredentials(_tmdbKeyStorageKey, apiKey);
  }

  Future<String> getLanguage() async {
    final lang = await _storage.getPlaylistCredentials(_tmdbLangStorageKey);
    return lang?.isNotEmpty == true ? lang! : 'en-US';
  }

  Future<void> saveLanguage(String lang) async {
    await _storage.savePlaylistCredentials(_tmdbLangStorageKey, lang);
  }

  Future<String> getCertificationCountry() async {
    final country = await _storage.getPlaylistCredentials(_tmdbCountryStorageKey);
    return country?.isNotEmpty == true ? country! : 'US';
  }

  Future<void> saveCertificationCountry(String country) async {
    await _storage.savePlaylistCredentials(_tmdbCountryStorageKey, country);
  }

  /// Search for movie metadata on TMDB and enrich with full details
  Future<TmdbMetadata?> searchMovie(String title, {int? year, String? apiKey}) async {
    final effectiveKey = (apiKey != null && apiKey.isNotEmpty)
        ? apiKey
        : (await getApiKey() ?? '453b34479261b0c9533f81e3678c139c');

    final lang = await getLanguage();
    final country = await getCertificationCountry();
    final cleanTitle = _normalizeTitle(title);
    final cacheKey = 'm_${cleanTitle}_${year ?? 0}_$lang';

    if (_movieDetailsCache.containsKey(cacheKey)) {
      return _movieDetailsCache[cacheKey];
    }

    try {
      final res = await _dio.get(
        'https://api.themoviedb.org/3/search/movie',
        queryParameters: {
          'api_key': effectiveKey,
          'query': cleanTitle,
          'language': lang,
          if (year != null) 'year': year,
        },
      );

      final results = res.data['results'] as List?;
      if (results != null && results.isNotEmpty) {
        final first = results.first as Map<String, dynamic>;
        final id = first['id'] as int;

        // Fetch deep details with credits, videos, recommendations, release_dates
        final detailed = await getMovieDetails(id, apiKey: effectiveKey, language: lang, country: country);
        if (detailed != null) {
          _movieDetailsCache[cacheKey] = detailed;
          return detailed;
        }

        final fallback = _mapMovieBasic(first);
        _movieDetailsCache[cacheKey] = fallback;
        return fallback;
      }
    } catch (_) {}
    return null;
  }

  /// Search for TV series metadata on TMDB and enrich with full details
  Future<TmdbMetadata?> searchSeries(String title, {String? apiKey}) async {
    final effectiveKey = (apiKey != null && apiKey.isNotEmpty)
        ? apiKey
        : (await getApiKey() ?? '453b34479261b0c9533f81e3678c139c');

    final lang = await getLanguage();
    final country = await getCertificationCountry();
    final cleanTitle = _normalizeTitle(title);
    final cacheKey = 'tv_${cleanTitle}_$lang';

    if (_tvDetailsCache.containsKey(cacheKey)) {
      return _tvDetailsCache[cacheKey];
    }

    try {
      final res = await _dio.get(
        'https://api.themoviedb.org/3/search/tv',
        queryParameters: {
          'api_key': effectiveKey,
          'query': cleanTitle,
          'language': lang,
        },
      );

      final results = res.data['results'] as List?;
      if (results != null && results.isNotEmpty) {
        final first = results.first as Map<String, dynamic>;
        final id = first['id'] as int;

        final detailed = await getTvDetails(id, apiKey: effectiveKey, language: lang, country: country);
        if (detailed != null) {
          _tvDetailsCache[cacheKey] = detailed;
          return detailed;
        }

        final fallback = _mapSeriesBasic(first);
        _tvDetailsCache[cacheKey] = fallback;
        return fallback;
      }
    } catch (_) {}
    return null;
  }

  /// Get detailed movie metadata with credits, videos, recommendations, release_dates
  Future<TmdbMetadata?> getMovieDetails(
    int tmdbId, {
    required String apiKey,
    String language = 'en-US',
    String country = 'US',
  }) async {
    final cacheKey = 'details_m_${tmdbId}_$language';
    if (_movieDetailsCache.containsKey(cacheKey)) {
      return _movieDetailsCache[cacheKey];
    }

    try {
      final res = await _dio.get(
        'https://api.themoviedb.org/3/movie/$tmdbId',
        queryParameters: {
          'api_key': apiKey,
          'language': language,
          'append_to_response': 'credits,videos,recommendations,release_dates',
        },
      );

      final data = res.data as Map<String, dynamic>;

      // Genres
      final genres = <String>[];
      if (data['genres'] is List) {
        for (final g in data['genres']) {
          if (g is Map && g['name'] != null) {
            genres.add(g['name'].toString());
          }
        }
      }

      // Cast
      final cast = <TmdbCastItem>[];
      if (data['credits'] is Map && data['credits']['cast'] is List) {
        final castList = data['credits']['cast'] as List;
        for (final member in castList.take(12)) {
          if (member is Map && member['name'] != null) {
            cast.add(TmdbCastItem(
              id: member['id'] as int?,
              name: member['name'] as String,
              character: member['character'] as String?,
              profilePath: member['profile_path'] as String?,
            ));
          }
        }
      }

      // Directors
      final directors = <String>[];
      if (data['credits'] is Map && data['credits']['crew'] is List) {
        for (final member in data['credits']['crew'] as List) {
          if (member is Map && member['job'] == 'Director' && member['name'] != null) {
            directors.add(member['name'].toString());
          }
        }
      }

      // Trailer key (YouTube)
      String? trailerKey;
      final videos = <TmdbVideoItem>[];
      if (data['videos'] is Map && data['videos']['results'] is List) {
        for (final v in data['videos']['results'] as List) {
          if (v is Map && v['site'] == 'YouTube' && v['key'] != null) {
            final key = v['key'].toString();
            final name = v['name']?.toString() ?? 'Trailer';
            final type = v['type']?.toString() ?? 'Trailer';
            videos.add(TmdbVideoItem(
              id: v['id']?.toString() ?? key,
              name: name,
              key: key,
              site: 'YouTube',
              type: type,
            ));
            if (trailerKey == null && (type == 'Trailer' || type == 'Teaser')) {
              trailerKey = key;
            }
          }
        }
      }

      // Certification / Age rating
      String? certification;
      if (data['release_dates'] is Map && data['release_dates']['results'] is List) {
        final results = data['release_dates']['results'] as List;
        // First try to find matching country, then fallback to 'US'
        Map<String, dynamic>? countryResult;
        for (final item in results) {
          if (item is Map && item['iso_3166_1'] == country) {
            countryResult = item.cast<String, dynamic>();
            break;
          }
        }
        if (countryResult == null) {
          for (final item in results) {
            if (item is Map && item['iso_3166_1'] == 'US') {
              countryResult = item.cast<String, dynamic>();
              break;
            }
          }
        }

        if (countryResult != null && countryResult['release_dates'] is List) {
          for (final rel in countryResult['release_dates'] as List) {
            if (rel is Map && rel['certification'] != null && rel['certification'].toString().isNotEmpty) {
              certification = rel['certification'].toString();
              break;
            }
          }
        }
      }

      // Recommendations
      final recommendations = <TmdbRecommendation>[];
      if (data['recommendations'] is Map && data['recommendations']['results'] is List) {
        for (final rec in (data['recommendations']['results'] as List).take(10)) {
          if (rec is Map && rec['id'] != null) {
            final recDate = rec['release_date'] as String?;
            final recYear = recDate != null && recDate.length >= 4 ? int.tryParse(recDate.substring(0, 4)) : null;
            recommendations.add(TmdbRecommendation(
              id: rec['id'] as int,
              title: rec['title'] as String? ?? '',
              posterPath: rec['poster_path'] as String?,
              rating: (rec['vote_average'] as num?)?.toDouble(),
              releaseYear: recYear,
              mediaType: 'movie',
            ));
          }
        }
      }

      final date = data['release_date'] as String?;
      final year = date != null && date.length >= 4 ? int.tryParse(date.substring(0, 4)) : null;

      final meta = TmdbMetadata(
        id: data['id'] as int,
        title: data['title'] as String? ?? '',
        overview: data['overview'] as String?,
        posterPath: data['poster_path'] as String?,
        backdropPath: data['backdrop_path'] as String?,
        rating: (data['vote_average'] as num?)?.toDouble(),
        releaseYear: year,
        genres: genres,
        cast: cast,
        directors: directors,
        trailerYoutubeKey: trailerKey,
        ageRating: certification,
        recommendations: recommendations,
        videos: videos,
      );

      _movieDetailsCache[cacheKey] = meta;
      return meta;
    } catch (_) {}
    return null;
  }

  /// Get detailed TV series metadata with aggregate_credits, videos, recommendations, content_ratings
  Future<TmdbMetadata?> getTvDetails(
    int tmdbId, {
    required String apiKey,
    String language = 'en-US',
    String country = 'US',
  }) async {
    final cacheKey = 'details_tv_${tmdbId}_$language';
    if (_tvDetailsCache.containsKey(cacheKey)) {
      return _tvDetailsCache[cacheKey];
    }

    try {
      final res = await _dio.get(
        'https://api.themoviedb.org/3/tv/$tmdbId',
        queryParameters: {
          'api_key': apiKey,
          'language': language,
          'append_to_response': 'credits,aggregate_credits,videos,recommendations,content_ratings',
        },
      );

      final data = res.data as Map<String, dynamic>;

      // Genres
      final genres = <String>[];
      if (data['genres'] is List) {
        for (final g in data['genres']) {
          if (g is Map && g['name'] != null) {
            genres.add(g['name'].toString());
          }
        }
      }

      // Cast (aggregate_credits first for series-wide cast)
      final cast = <TmdbCastItem>[];
      List? castList;
      if (data['aggregate_credits'] is Map && data['aggregate_credits']['cast'] is List) {
        castList = data['aggregate_credits']['cast'] as List;
      } else if (data['credits'] is Map && data['credits']['cast'] is List) {
        castList = data['credits']['cast'] as List;
      }

      if (castList != null) {
        for (final member in castList.take(12)) {
          if (member is Map && member['name'] != null) {
            String? character;
            if (member['roles'] is List && (member['roles'] as List).isNotEmpty) {
              final firstRole = (member['roles'] as List).first;
              if (firstRole is Map) character = firstRole['character'] as String?;
            } else {
              character = member['character'] as String?;
            }

            cast.add(TmdbCastItem(
              id: member['id'] as int?,
              name: member['name'] as String,
              character: character,
              profilePath: member['profile_path'] as String?,
            ));
          }
        }
      }

      // Creators / Directors
      final creators = <String>[];
      if (data['created_by'] is List) {
        for (final c in data['created_by'] as List) {
          if (c is Map && c['name'] != null) {
            creators.add(c['name'].toString());
          }
        }
      }

      // Trailer key (YouTube)
      String? trailerKey;
      final videos = <TmdbVideoItem>[];
      if (data['videos'] is Map && data['videos']['results'] is List) {
        for (final v in data['videos']['results'] as List) {
          if (v is Map && v['site'] == 'YouTube' && v['key'] != null) {
            final key = v['key'].toString();
            final name = v['name']?.toString() ?? 'Trailer';
            final type = v['type']?.toString() ?? 'Trailer';
            videos.add(TmdbVideoItem(
              id: v['id']?.toString() ?? key,
              name: name,
              key: key,
              site: 'YouTube',
              type: type,
            ));
            if (trailerKey == null && (type == 'Trailer' || type == 'Teaser')) {
              trailerKey = key;
            }
          }
        }
      }

      // Content ratings (TV)
      String? certification;
      if (data['content_ratings'] is Map && data['content_ratings']['results'] is List) {
        final results = data['content_ratings']['results'] as List;
        Map<String, dynamic>? countryResult;
        for (final item in results) {
          if (item is Map && item['iso_3166_1'] == country) {
            countryResult = item.cast<String, dynamic>();
            break;
          }
        }
        if (countryResult == null) {
          for (final item in results) {
            if (item is Map && item['iso_3166_1'] == 'US') {
              countryResult = item.cast<String, dynamic>();
              break;
            }
          }
        }
        if (countryResult != null && countryResult['rating'] != null) {
          certification = countryResult['rating'].toString();
        }
      }

      // Recommendations
      final recommendations = <TmdbRecommendation>[];
      if (data['recommendations'] is Map && data['recommendations']['results'] is List) {
        for (final rec in (data['recommendations']['results'] as List).take(10)) {
          if (rec is Map && rec['id'] != null) {
            final recDate = rec['first_air_date'] as String?;
            final recYear = recDate != null && recDate.length >= 4 ? int.tryParse(recDate.substring(0, 4)) : null;
            recommendations.add(TmdbRecommendation(
              id: rec['id'] as int,
              title: rec['name'] as String? ?? '',
              posterPath: rec['poster_path'] as String?,
              rating: (rec['vote_average'] as num?)?.toDouble(),
              releaseYear: recYear,
              mediaType: 'tv',
            ));
          }
        }
      }

      final date = data['first_air_date'] as String?;
      final year = date != null && date.length >= 4 ? int.tryParse(date.substring(0, 4)) : null;

      final meta = TmdbMetadata(
        id: data['id'] as int,
        title: data['name'] as String? ?? '',
        overview: data['overview'] as String?,
        posterPath: data['poster_path'] as String?,
        backdropPath: data['backdrop_path'] as String?,
        rating: (data['vote_average'] as num?)?.toDouble(),
        releaseYear: year,
        genres: genres,
        cast: cast,
        directors: creators,
        trailerYoutubeKey: trailerKey,
        ageRating: certification,
        recommendations: recommendations,
        seasonsCount: (data['number_of_seasons'] as num?)?.toInt(),
        videos: videos,
      );

      _tvDetailsCache[cacheKey] = meta;
      return meta;
    } catch (_) {}
    return null;
  }

  /// Get season episodes with thumbnails and overviews
  Future<List<TmdbEpisodeDetail>> getSeasonEpisodes(
    int tmdbId,
    int seasonNumber, {
    required String apiKey,
    String language = 'en-US',
  }) async {
    final cacheKey = 'season_${tmdbId}_${seasonNumber}_$language';
    if (_seasonDetailsCache.containsKey(cacheKey)) {
      return _seasonDetailsCache[cacheKey]!;
    }

    try {
      final res = await _dio.get(
        'https://api.themoviedb.org/3/tv/$tmdbId/season/$seasonNumber',
        queryParameters: {
          'api_key': apiKey,
          'language': language,
        },
      );

      final data = res.data as Map<String, dynamic>;
      final episodes = <TmdbEpisodeDetail>[];

      if (data['episodes'] is List) {
        for (final ep in data['episodes'] as List) {
          if (ep is Map && ep['episode_number'] != null) {
            episodes.add(TmdbEpisodeDetail(
              episodeNumber: ep['episode_number'] as int,
              name: ep['name'] as String? ?? 'Episode ${ep['episode_number']}',
              overview: ep['overview'] as String?,
              stillPath: ep['still_path'] as String?,
              rating: (ep['vote_average'] as num?)?.toDouble(),
            ));
          }
        }
      }

      _seasonDetailsCache[cacheKey] = episodes;
      return episodes;
    } catch (_) {}
    return const [];
  }

  String _normalizeTitle(String title) {
    var t = title;
    t = t.replaceAll(RegExp(r'\[.*?\]|\(.*?\)', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\b(4k|fhd|hd|sd|uhd|1080p|720p|hevc|h264|x264)\b', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\.(mkv|mp4|avi|ts)$', caseSensitive: false), '');
    return t.trim();
  }

  TmdbMetadata _mapMovieBasic(Map<String, dynamic> json) {
    final date = json['release_date'] as String?;
    final year = date != null && date.length >= 4 ? int.tryParse(date.substring(0, 4)) : null;

    return TmdbMetadata(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      overview: json['overview'] as String?,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      rating: (json['vote_average'] as num?)?.toDouble(),
      releaseYear: year,
    );
  }

  TmdbMetadata _mapSeriesBasic(Map<String, dynamic> json) {
    final date = json['first_air_date'] as String?;
    final year = date != null && date.length >= 4 ? int.tryParse(date.substring(0, 4)) : null;

    return TmdbMetadata(
      id: json['id'] as int,
      title: json['name'] as String? ?? '',
      overview: json['overview'] as String?,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      rating: (json['vote_average'] as num?)?.toDouble(),
      releaseYear: year,
    );
  }
}

final tmdbServiceProvider = Provider<TmdbService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final storage = ref.watch(secureStorageProvider);
  return TmdbService(apiClient.dio, storage);
});
