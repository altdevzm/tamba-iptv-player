import 'package:drift/drift.dart';

import '../../../core/persistence/app_database.dart';

/// Matches live IPTV content items to their corresponding EPG channels,
/// updating `ContentItemsTable.epgChannelId` with the confirmed EPG channel id.
class ChannelMatcher {
  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Attempts to match every live content item that carries a `tvg-id`
  /// (`epgChannelId`) to a known EPG channel in [db].
  ///
  /// Matching is tried in three increasingly lenient strategies:
  ///   1. Exact case-insensitive id comparison.
  ///   2. Normalised display-name comparison.
  ///   3. Strip quality suffixes (HD/FHD/4K/SD/UHD) and fuzzy-match.
  Future<void> matchAllChannels(AppDatabase db) async {
    // Load all EPG channels once.
    final epgChannels = await db.select(db.epgChannelsTable).get();

    // Build fast-lookup maps.
    final Map<String, String> idToId = {};           // normalised-id → epg-id
    final Map<String, String> nameToId = {};         // normalised-displayName → epg-id
    final Map<String, String> strippedNameToId = {}; // stripped-displayName → epg-id

    for (final ch in epgChannels) {
      final normId   = ch.id.toLowerCase().trim();
      final normName = _normalize(ch.displayName);
      final stripped = _stripSuffixes(normName);

      idToId[normId]              = ch.id;
      nameToId[normName]          = ch.id;
      strippedNameToId[stripped]  = ch.id;
    }

    // Load live content items that have a tvg-id set.
    final liveItems = await (db.select(db.contentItemsTable)
          ..where((t) => t.type.equals('live'))
          ..where((t) => t.epgChannelId.isNotNull()))
        .get();

    for (final item in liveItems) {
      final rawTvgId = item.epgChannelId;
      if (rawTvgId == null || rawTvgId.isEmpty) continue;

      String? matchedId;

      // Strategy 1: exact case-insensitive id match.
      matchedId = idToId[rawTvgId.toLowerCase().trim()];

      // Strategy 2: normalised display-name match.
      if (matchedId == null) {
        final normTvgId = _normalize(rawTvgId);
        matchedId = nameToId[normTvgId];
      }

      // Strategy 3: strip quality suffixes and fuzzy match.
      if (matchedId == null) {
        final strippedTvgId = _stripSuffixes(_normalize(rawTvgId));
        matchedId = strippedNameToId[strippedTvgId];
      }

      // Update only when a match was found and it differs from the current value.
      if (matchedId != null && matchedId != item.epgChannelId) {
        await (db.update(db.contentItemsTable)
              ..where((t) => t.id.equals(item.id)))
            .write(ContentItemsTableCompanion(
              epgChannelId: Value(matchedId),
            ));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Normalises a channel name for comparison:
  /// - Lowercase + trim
  /// - Remove trailing quality suffixes (hd, fhd, 4k, sd, uhd)
  /// - Remove non-alphanumeric characters (except spaces)
  /// - Collapse multiple spaces
  String _normalize(String name) {
    var n = name.toLowerCase().trim();
    n = _stripSuffixes(n);
    // Keep only alphanumeric and spaces.
    n = n.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    // Collapse whitespace.
    n = n.replaceAll(RegExp(r'\s+'), ' ').trim();
    return n;
  }

  /// Strips trailing quality suffixes: ` hd`, ` fhd`, ` 4k`, ` sd`, ` uhd`.
  String _stripSuffixes(String name) {
    return name
        .replaceAll(RegExp(r'\s+(uhd|fhd|hd|4k|sd)\s*$', caseSensitive: false), '')
        .trim();
  }
}
