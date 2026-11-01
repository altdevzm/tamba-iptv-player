import 'dart:isolate';
import 'package:xml/xml.dart';

/// Parsed result from an XMLTV document.
class ParsedEpgData {
  final List<EpgChannelEntry> channels;
  final List<EpgProgramEntry> programs;

  const ParsedEpgData({
    required this.channels,
    required this.programs,
  });
}

/// Represents a single `<channel>` element in an XMLTV feed.
class EpgChannelEntry {
  final String id;
  final String displayName;
  final String? iconUrl;

  const EpgChannelEntry({
    required this.id,
    required this.displayName,
    this.iconUrl,
  });
}

/// Represents a single `<programme>` element in an XMLTV feed.
class EpgProgramEntry {
  final String channelId;
  final DateTime start;
  final DateTime stop;
  final String title;
  final String? description;
  final String? category;
  final String? iconUrl;
  final String? rating;
  final String? episodeNum;

  const EpgProgramEntry({
    required this.channelId,
    required this.start,
    required this.stop,
    required this.title,
    this.description,
    this.category,
    this.iconUrl,
    this.rating,
    this.episodeNum,
  });
}

// ---------------------------------------------------------------------------
// DateTime parsing
// ---------------------------------------------------------------------------

/// Parses an XMLTV datetime string of the form `20240101120000 +0200` into a
/// UTC [DateTime].  Returns `null` if the string is malformed.
DateTime? _parseXmltvDateTime(String? raw) {
  if (raw == null || raw.isEmpty) return null;

  final trimmed = raw.trim();

  // Split on the first space to separate the date/time part from the offset.
  final spaceIdx = trimmed.indexOf(' ');
  final datePart = spaceIdx >= 0 ? trimmed.substring(0, spaceIdx) : trimmed;
  final offsetPart = spaceIdx >= 0 ? trimmed.substring(spaceIdx + 1).trim() : null;

  if (datePart.length < 14) return null;

  final year   = int.tryParse(datePart.substring(0, 4));
  final month  = int.tryParse(datePart.substring(4, 6));
  final day    = int.tryParse(datePart.substring(6, 8));
  final hour   = int.tryParse(datePart.substring(8, 10));
  final minute = int.tryParse(datePart.substring(10, 12));
  final second = int.tryParse(datePart.substring(12, 14));

  if (year == null || month == null || day == null ||
      hour == null || minute == null || second == null) {
    return null;
  }

  // Parse timezone offset, e.g. "+0200" or "-0530".
  Duration tzOffset = Duration.zero;
  if (offsetPart != null && offsetPart.length >= 5) {
    final sign   = offsetPart[0] == '-' ? -1 : 1;
    final offH   = int.tryParse(offsetPart.substring(1, 3)) ?? 0;
    final offM   = int.tryParse(offsetPart.substring(3, 5)) ?? 0;
    tzOffset = Duration(hours: sign * offH, minutes: sign * offM);
  }

  // Build as a UTC DateTime by subtracting the offset.
  final local = DateTime.utc(year, month, day, hour, minute, second);
  return local.subtract(tzOffset);
}

// ---------------------------------------------------------------------------
// Top-level isolate entry point (must be top-level for Isolate.run)
// ---------------------------------------------------------------------------

/// Synchronously parses XMLTV [xmlContent] and returns a [ParsedEpgData].
/// Runs inside an isolate — must be a top-level function.
ParsedEpgData _parseXmltvSync(String xmlContent) {
  final document = XmlDocument.parse(xmlContent);
  final tv = document.rootElement;

  final channels = <EpgChannelEntry>[];
  final programs = <EpgProgramEntry>[];

  // Parse <channel> elements.
  for (final element in tv.findElements('channel')) {
    try {
      final id = element.getAttribute('id');
      if (id == null || id.isEmpty) continue;

      final displayNameEl = element.findElements('display-name').firstOrNull;
      if (displayNameEl == null) continue;
      final displayName = displayNameEl.innerText.trim();
      if (displayName.isEmpty) continue;

      final iconUrl = element.findElements('icon').firstOrNull?.getAttribute('src');

      channels.add(EpgChannelEntry(
        id: id,
        displayName: displayName,
        iconUrl: iconUrl,
      ));
    } catch (_) {
      // Skip malformed <channel> entries.
    }
  }

  // Parse <programme> elements.
  for (final element in tv.findElements('programme')) {
    try {
      final channelId = element.getAttribute('channel');
      if (channelId == null || channelId.isEmpty) continue;

      final start = _parseXmltvDateTime(element.getAttribute('start'));
      final stop  = _parseXmltvDateTime(element.getAttribute('stop'));
      if (start == null || stop == null) continue;

      final titleEl = element.findElements('title').firstOrNull;
      if (titleEl == null) continue;
      final title = titleEl.innerText.trim();
      if (title.isEmpty) continue;

      final description = element.findElements('desc').firstOrNull?.innerText.trim();
      final category    = element.findElements('category').firstOrNull?.innerText.trim();
      final iconUrl     = element.findElements('icon').firstOrNull?.getAttribute('src');

      // <rating><value>X</value></rating>
      String? rating;
      final ratingEl = element.findElements('rating').firstOrNull;
      if (ratingEl != null) {
        rating = ratingEl.findElements('value').firstOrNull?.innerText.trim();
      }

      // <episode-num system="...">...</episode-num>
      final episodeNum = element.findElements('episode-num').firstOrNull?.innerText.trim();

      programs.add(EpgProgramEntry(
        channelId:  channelId,
        start:      start,
        stop:       stop,
        title:      title,
        description: description?.isNotEmpty == true ? description : null,
        category:   category?.isNotEmpty == true ? category : null,
        iconUrl:    iconUrl,
        rating:     rating?.isNotEmpty == true ? rating : null,
        episodeNum: episodeNum?.isNotEmpty == true ? episodeNum : null,
      ));
    } catch (_) {
      // Skip malformed <programme> entries.
    }
  }

  return ParsedEpgData(channels: channels, programs: programs);
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Parses an XMLTV document from [xmlContent] in a background isolate.
Future<ParsedEpgData> parseXmltv(String xmlContent) async {
  return Isolate.run(() => _parseXmltvSync(xmlContent));
}
