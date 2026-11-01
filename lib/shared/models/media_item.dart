import '../../core/persistence/app_database.dart';

enum MediaType {
  live,
  movie,
  series,
  episode,
}

class MediaItem {
  final String id;
  final String title;
  final MediaType type;
  final String? posterUrl;
  final String? backdropUrl;
  final double? rating;
  final int? releaseYear;
  final int? seasonsCount;
  final String? resolutionBadge; // e.g. "4K", "HD"
  final int? matchPercentage; // e.g. 98 -> "98% Match"
  final List<String> genres;
  final String? synopsis;
  final String? streamUrl;
  final String? channelNumber;
  final String? epgChannelId;
  final int positionSeconds;
  final int durationSeconds;
  final String? subtitle; // e.g. "S4 E7 • The Massacre at Hawkins Lab"

  // Persistence & Provider linkage fields
  final String? playlistId;
  final String? providerId;
  final int? contentDbId;
  final String? seriesProviderId;
  final int? seasonNumber;
  final int? episodeNumber;

  const MediaItem({
    required this.id,
    required this.title,
    required this.type,
    this.posterUrl,
    this.backdropUrl,
    this.rating,
    this.releaseYear,
    this.seasonsCount,
    this.resolutionBadge,
    this.matchPercentage,
    this.genres = const [],
    this.synopsis,
    this.streamUrl,
    this.channelNumber,
    this.epgChannelId,
    this.positionSeconds = 0,
    this.durationSeconds = 0,
    this.subtitle,
    this.playlistId,
    this.providerId,
    this.contentDbId,
    this.seriesProviderId,
    this.seasonNumber,
    this.episodeNumber,
  });

  double get watchProgress {
    if (durationSeconds <= 0) return 0.0;
    return (positionSeconds / durationSeconds).clamp(0.0, 1.0);
  }

  ContentItemsTableData toContentItem() {
    return ContentItemsTableData(
      id: contentDbId ?? 0,
      playlistId: playlistId ?? '',
      providerId: providerId ?? id,
      title: title,
      type: type == MediaType.series
          ? 'series'
          : (type == MediaType.live ? 'live' : 'movie'),
      posterUrl: posterUrl,
      backdropUrl: backdropUrl,
      streamUrl: streamUrl,
      rating: rating,
      releaseYear: releaseYear,
      tvArchive: 0,
      tvArchiveDuration: 0,
    );
  }

  MediaItem copyWith({
    String? id,
    String? title,
    MediaType? type,
    String? posterUrl,
    String? backdropUrl,
    double? rating,
    int? releaseYear,
    int? seasonsCount,
    String? resolutionBadge,
    int? matchPercentage,
    List<String>? genres,
    String? synopsis,
    String? streamUrl,
    String? channelNumber,
    String? epgChannelId,
    int? positionSeconds,
    int? durationSeconds,
    String? subtitle,
    String? playlistId,
    String? providerId,
    int? contentDbId,
    String? seriesProviderId,
    int? seasonNumber,
    int? episodeNumber,
  }) {
    return MediaItem(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      posterUrl: posterUrl ?? this.posterUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      rating: rating ?? this.rating,
      releaseYear: releaseYear ?? this.releaseYear,
      seasonsCount: seasonsCount ?? this.seasonsCount,
      resolutionBadge: resolutionBadge ?? this.resolutionBadge,
      matchPercentage: matchPercentage ?? this.matchPercentage,
      genres: genres ?? this.genres,
      synopsis: synopsis ?? this.synopsis,
      streamUrl: streamUrl ?? this.streamUrl,
      channelNumber: channelNumber ?? this.channelNumber,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      positionSeconds: positionSeconds ?? this.positionSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      subtitle: subtitle ?? this.subtitle,
      playlistId: playlistId ?? this.playlistId,
      providerId: providerId ?? this.providerId,
      contentDbId: contentDbId ?? this.contentDbId,
      seriesProviderId: seriesProviderId ?? this.seriesProviderId,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
    );
  }
}
