import '../../../core/persistence/app_database.dart';
import 'tiss_models.dart';

/// Confidence-based Channel Grouping Engine that clusters multi-quality IPTV
/// playlist entries (e.g. `TV ONE 4K`, `TV ONE 1080P`, `TV ONE 720P`,
/// `TV ONE 480P`) into single [LogicalChannel]s while strictly preserving
/// distinct regional feeds, language feeds, and time-shifted channels (`+1`).
class ChannelGroupingEngine {
  static final _qualityTokenRegex = RegExp(
    r'(?:^|[\s\-_|/\[\(\.]+)(4k\+?|\buhd\+?|\b2160p|1440p|qhd|1080p|fhd\+?|full\s*hd|720p|hd\+?|576p|480p|sd\+?|360p|hevc|h\.?265|h\.?264|50fps|60fps|raw|hq|lq|backup|vip|ultra)(?=[\s\-_|/\]\)\.]+|$)',
    caseSensitive: false,
  );

  static final _regionPrefixRegex = RegExp(
    r'^(?:[\[\(]\s*)?(uk|us|usa|ca|can|fr|de|es|it|pt|ar|za|zm|ng|ke|gh|in|au|nz|nl|be|se|no|dk|pl|tr|ru|br|mx|af|africa|latino)(?:\s*[\]\)])?\s*[:|\-\s]+',
    caseSensitive: false,
  );

  static final _regionSuffixRegex = RegExp(
    r'[\s\-_|/\[\(]+(uk|us|usa|ca|fr|de|es|it|pt|ar|za|zm|east|west|pacific|mountain|central|latino|\+1|\+2)(?=[\s\-_|/\]\)]*$)',
    caseSensitive: false,
  );

  static final _bracketCleanRegex = RegExp(r'[\[\(\)\]]+');
  static final _multiSpaceRegex = RegExp(r'\s+');

  /// Extracts the inferred [StreamQualityTier] from a channel title.
  static StreamQualityTier detectQualityTier(String title) {
    final lower = title.toLowerCase();
    if (RegExp(r'\b(4k|uhd|2160p)\b').hasMatch(lower)) {
      return StreamQualityTier.uhd4k;
    }
    if (RegExp(r'\b(1440p|qhd)\b').hasMatch(lower)) {
      return StreamQualityTier.qhd1440;
    }
    if (RegExp(r'\b(1080p|fhd|full\s*hd)\b').hasMatch(lower)) {
      return StreamQualityTier.fhd1080;
    }
    if (RegExp(r'\b(720p|hd)\b').hasMatch(lower)) {
      return StreamQualityTier.hd720;
    }
    if (RegExp(r'\b576p\b').hasMatch(lower)) {
      return StreamQualityTier.sd576;
    }
    if (RegExp(r'\b(480p|sd)\b').hasMatch(lower)) {
      return StreamQualityTier.sd480;
    }
    if (RegExp(r'\b(360p|lq)\b').hasMatch(lower)) {
      return StreamQualityTier.low360;
    }
    return StreamQualityTier.unknown;
  }

  /// Extracts a normalized regional / feed tag (e.g. `UK`, `US`, `EAST`, `+1`)
  /// so different regional feeds are never merged together.
  static String? extractRegionTag(String title, {String? epgChannelId}) {
    final trimmed = title.trim();
    final prefixMatch = _regionPrefixRegex.firstMatch(trimmed);
    if (prefixMatch != null) {
      return _canonicalRegion(prefixMatch.group(1)!);
    }
    final suffixMatch = _regionSuffixRegex.firstMatch(trimmed);
    if (suffixMatch != null) {
      return _canonicalRegion(suffixMatch.group(1)!);
    }
    // Check EPG country suffix like "cnn.us" or "bbc1.uk"
    if (epgChannelId != null && epgChannelId.contains('.')) {
      final tld = epgChannelId.split('.').last.trim().toLowerCase();
      if (tld.length == 2 || tld == 'usa') {
        return _canonicalRegion(tld);
      }
    }
    return null;
  }

  static String _canonicalRegion(String raw) {
    final upper = raw.trim().toUpperCase();
    if (upper == 'USA') return 'US';
    if (upper == 'CAN') return 'CA';
    return upper;
  }

  /// Normalizes a channel title by stripping quality/codec tokens while
  /// keeping the clean human-readable base name.
  static String normalizeDisplayName(String title) {
    var cleaned = title.replaceAll(_qualityTokenRegex, ' ');
    cleaned = cleaned.replaceAll(_bracketCleanRegex, ' ');
    cleaned = cleaned.replaceAll(RegExp(r'^[\s\-_|/:]+|[\s\-_|/:]+$'), '');
    cleaned = cleaned.replaceAll(_multiSpaceRegex, ' ').trim();
    return cleaned.isEmpty ? title.trim() : cleaned;
  }

  /// Normalized comparison key (lowercase alphanumeric). Strips leading
  /// provider/country prefix tags (e.g. `ZA: `, `AF | `) so identical channels
  /// placed in different categories (e.g. `ZA: SuperSport 1 4K` vs
  /// `SuperSport 1 HD`) match across categories, while [computeMatchConfidence]
  /// still strictly enforces region/language separation (`UK` vs `US`, `+1`).
  static String normalizedKey(String displayName) {
    final stripped = displayName.replaceFirst(_regionPrefixRegex, ' ');
    final key = stripped
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9+]'), ' ')
        .replaceAll(_multiSpaceRegex, ' ')
        .trim();
    if (key.isNotEmpty) return key;
    return displayName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9+]'), ' ')
        .replaceAll(_multiSpaceRegex, ' ')
        .trim();
  }

  /// Computes a confidence score `[0.0, 1.0]` for whether two entries represent
  /// the same logical channel. Never merges incompatible regional feeds.
  static double computeMatchConfidence({
    required String baseKeyA,
    required String baseKeyB,
    String? regionA,
    String? regionB,
    String? epgA,
    String? epgB,
    String? logoA,
    String? logoB,
    int? categoryA,
    int? categoryB,
  }) {
    // Hard guard: never merge different regional/time-shift feeds
    if (regionA != null && regionB != null && regionA != regionB) {
      return 0.0;
    }
    if ((regionA != null) != (regionB != null)) {
      // One has an explicit regional feed (+1, UK, US, East) and the other does not
      if (regionA == '+1' ||
          regionB == '+1' ||
          regionA == '+2' ||
          regionB == '+2') {
        return 0.0;
      }
    }

    double score = 0.0;

    // 1. Explicit EPG / XMLTV identifier match (highest priority)
    final hasEpgA = epgA != null && epgA.trim().isNotEmpty;
    final hasEpgB = epgB != null && epgB.trim().isNotEmpty;
    if (hasEpgA && hasEpgB) {
      if (epgA.trim().toLowerCase() == epgB.trim().toLowerCase()) {
        score += 0.55;
      } else {
        // Explicit conflicting EPG IDs indicate distinct channels
        return 0.0;
      }
    }

    // 2. Normalized base channel name match
    if (baseKeyA.isNotEmpty && baseKeyA == baseKeyB) {
      score += 0.50;
    } else {
      return score >= 0.55 ? score : 0.0;
    }

    // 3. Logo similarity supporting evidence
    if (logoA != null &&
        logoA.isNotEmpty &&
        logoB != null &&
        logoB.isNotEmpty &&
        logoA == logoB) {
      score += 0.15;
    }

    // 4. Category supporting evidence
    if (categoryA != null && categoryB != null && categoryA == categoryB) {
      score += 0.10;
    }

    return score.clamp(0.0, 1.0);
  }

  /// Groups raw playlist [ContentItemsTableData] live channels into
  /// deduplicated [LogicalChannel]s with ranked [StreamAlternative]s.
  ///
  /// Supports [manualMerges] (`providerId -> targetLogicalId`) and
  /// [manualSplits] (set of `providerId`s forced to remain standalone).
  static List<LogicalChannel> groupChannels(
    List<ContentItemsTableData> rawChannels, {
    Map<String, String> manualMerges = const {},
    Set<String> manualSplits = const {},
  }) {
    if (rawChannels.isEmpty) return const [];

    final buckets = <_ChannelBucket>[];
    final bucketByKey = <String, List<_ChannelBucket>>{};

    for (final ch in rawChannels) {
      final url = ch.streamUrl?.trim() ?? '';
      if (url.isEmpty) continue;

      final tier = detectQualityTier(ch.title);
      final region = extractRegionTag(ch.title, epgChannelId: ch.epgChannelId);
      final displayName = normalizeDisplayName(ch.title);
      final baseKey = normalizedKey(displayName);
      final isSplit = manualSplits.contains(ch.providerId);
      final forcedGroup = manualMerges[ch.providerId];

      _ChannelBucket? matched;
      double bestScore = 0.0;

      if (!isSplit) {
        if (forcedGroup != null) {
          for (final b in buckets) {
            if (b.logicalId == forcedGroup) {
              matched = b;
              bestScore = 1.0;
              break;
            }
          }
        } else {
          final candidates = <String>{
            if (ch.epgChannelId != null && ch.epgChannelId!.trim().isNotEmpty)
              'epg:${ch.epgChannelId!.trim().toLowerCase()}',
            'name:$baseKey',
          };

          for (final lookup in candidates) {
            final list = bucketByKey[lookup];
            if (list == null) continue;
            for (final b in list) {
              final confidence = computeMatchConfidence(
                baseKeyA: b.baseKey,
                baseKeyB: baseKey,
                regionA: b.regionTag,
                regionB: region,
                epgA: b.epgChannelId,
                epgB: ch.epgChannelId,
                logoA: b.logoUrl,
                logoB: ch.posterUrl,
                categoryA: b.categoryId,
                categoryB: ch.categoryId,
              );
              if (confidence >= 0.45 && confidence > bestScore) {
                bestScore = confidence;
                matched = b;
              }
            }
          }
        }
      }

      if (matched == null) {
        final logicalId = forcedGroup ??
            (isSplit
                ? 'split_${ch.providerId}'
                : 'logical_${baseKey.replaceAll(' ', '_')}_${region ?? 'any'}_${buckets.length}');
        matched = _ChannelBucket(
          logicalId: logicalId,
          displayName: displayName,
          baseKey: baseKey,
          regionTag: region,
          epgChannelId: ch.epgChannelId,
          logoUrl: ch.posterUrl,
          categoryId: ch.categoryId,
          confidence: 1.0,
        );
        buckets.add(matched);
        if (!isSplit) {
          bucketByKey.putIfAbsent('name:$baseKey', () => []).add(matched);
          if (ch.epgChannelId != null && ch.epgChannelId!.trim().isNotEmpty) {
            bucketByKey
                .putIfAbsent(
                    'epg:${ch.epgChannelId!.trim().toLowerCase()}', () => [])
                .add(matched);
          }
        }
      } else {
        matched.confidence =
            matched.confidence < bestScore ? matched.confidence : bestScore;
        matched.logoUrl ??= ch.posterUrl;
        matched.epgChannelId ??= ch.epgChannelId;
      }

      matched.alternatives.add(
        StreamAlternative(
          streamId: '${ch.playlistId}:${ch.providerId}',
          logicalChannelId: matched.logicalId,
          contentDbId: ch.id,
          providerId: ch.providerId,
          originalTitle: ch.title,
          streamUrl: url,
          displayQuality: tier.shortLabel,
          tier: tier,
          isQualityVerified: false,
          estimatedBitrateKbps: tier.defaultEstimatedBitrateKbps,
          regionTag: region,
          epgChannelId: ch.epgChannelId,
          logoUrl: ch.posterUrl,
        ),
      );
    }

    return buckets.map((b) {
      // Rank alternatives highest quality first; deduplicate identical URLs
      final seenUrls = <String>{};
      final uniqueAlts = b.alternatives
          .where((a) => seenUrls.add(a.streamUrl))
          .toList()
        ..sort((a, bAlt) => bAlt.tier.rank.compareTo(a.tier.rank));

      final ordered = <StreamAlternative>[
        for (var i = 0; i < uniqueAlts.length; i++)
          uniqueAlts[i].copyWith(preferredOrder: i),
      ];

      return LogicalChannel(
        logicalId: b.logicalId,
        displayName: b.displayName,
        logoUrl: b.logoUrl,
        categoryId: b.categoryId,
        epgChannelId: b.epgChannelId,
        regionTag: b.regionTag,
        alternatives: ordered,
        matchConfidence: b.confidence,
      );
    }).toList();
  }
}

class _ChannelBucket {
  final String logicalId;
  final String displayName;
  final String baseKey;
  final String? regionTag;
  String? epgChannelId;
  String? logoUrl;
  final int? categoryId;
  double confidence;
  final List<StreamAlternative> alternatives = [];

  _ChannelBucket({
    required this.logicalId,
    required this.displayName,
    required this.baseKey,
    this.regionTag,
    this.epgChannelId,
    this.logoUrl,
    this.categoryId,
    required this.confidence,
  });
}
