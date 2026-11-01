import 'dart:isolate';

/// Represents a single channel parsed from an M3U playlist.
class ParsedChannel {
  final String title;
  final String? tvgId;
  final String? tvgName;
  final String? logoUrl;
  final String? groupTitle;
  final bool isRadio;
  final String? catchupType; // 'default', 'append', 'shift'
  final int catchupDays;
  final String? catchupSource;
  final double? tvgShift;
  final String streamUrl;
  final Map<String, String> streamHeaders; // from pipe-params (e.g. |User-Agent=...&Referer=...)
  final Map<String, String> kodiProps;     // from #KODIPROP lines

  const ParsedChannel({
    required this.title,
    this.tvgId,
    this.tvgName,
    this.logoUrl,
    this.groupTitle,
    this.isRadio = false,
    this.catchupType,
    this.catchupDays = 0,
    this.catchupSource,
    this.tvgShift,
    required this.streamUrl,
    this.streamHeaders = const {},
    this.kodiProps = const {},
  });
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Parses an M3U [content] string in a background isolate and returns the
/// list of parsed channels. Malformed entries are silently skipped.
Future<List<ParsedChannel>> parseM3u(String content) {
  return Isolate.run(() => _parseM3uSync(content));
}

// ---------------------------------------------------------------------------
// Top-level isolate entry point (must be a top-level function, not a closure)
// ---------------------------------------------------------------------------

/// Synchronous M3U parser — runs inside an isolate.
List<ParsedChannel> _parseM3uSync(String content) {
  final results = <ParsedChannel>[];

  // Normalise line endings and split.
  final lines = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');

  // Buffer for #KODIPROP lines that precede an #EXTINF line.
  final kodiProps = <String, String>{};

  String? pendingExtinf; // raw #EXTINF line waiting for its URL

  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i].trim();
    if (raw.isEmpty) continue;

    // ── Header ──────────────────────────────────────────────────────────────
    if (raw.startsWith('#EXTM3U')) continue;

    // ── KODIPROP ─────────────────────────────────────────────────────────────
    // Format: #KODIPROP:inputstream.adaptive.manifest_type=mpd
    if (raw.startsWith('#KODIPROP:')) {
      final kv = raw.substring('#KODIPROP:'.length);
      final eqIdx = kv.indexOf('=');
      if (eqIdx > 0) {
        final key = kv.substring(0, eqIdx).trim();
        final value = kv.substring(eqIdx + 1).trim();
        kodiProps[key] = value;
      }
      continue;
    }

    // ── #EXTINF ───────────────────────────────────────────────────────────────
    if (raw.startsWith('#EXTINF:')) {
      pendingExtinf = raw;
      continue;
    }

    // ── Other directives ─────────────────────────────────────────────────────
    if (raw.startsWith('#')) continue;

    // ── URL line ─────────────────────────────────────────────────────────────
    // A non-comment, non-empty line after an #EXTINF is the stream URL.
    if (pendingExtinf != null) {
      final channel = _buildChannel(
        extinf: pendingExtinf,
        rawUrl: raw,
        kodiProps: Map<String, String>.from(kodiProps),
      );
      if (channel != null) results.add(channel);
    }

    // Reset state for next entry regardless of whether we got a valid channel.
    pendingExtinf = null;
    kodiProps.clear();
  }

  return results;
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

/// Builds a [ParsedChannel] from a parsed `#EXTINF` line and URL.
/// Returns `null` if the entry is malformed.
ParsedChannel? _buildChannel({
  required String extinf,
  required String rawUrl,
  required Map<String, String> kodiProps,
}) {
  try {
    // ── Split URL at pipe boundary ───────────────────────────────────────────
    final streamUrl = _extractStreamUrl(rawUrl);
    if (streamUrl.isEmpty) return null;
    final streamHeaders = _extractPipeHeaders(rawUrl);

    // ── Parse #EXTINF attributes ─────────────────────────────────────────────
    // Format: #EXTINF:<duration> attr1="val1" attr2="val2",Title
    final commaIdx = extinf.lastIndexOf(',');
    final title = commaIdx >= 0 ? extinf.substring(commaIdx + 1).trim() : '';

    final attrSection = commaIdx >= 0
        ? extinf.substring('#EXTINF:'.length, commaIdx)
        : extinf.substring('#EXTINF:'.length);

    final attrs = _parseAttributes(attrSection);

    final isRadio = _parseBool(attrs['radio']);

    final catchupDaysRaw = int.tryParse(attrs['catchup-days'] ?? '') ?? 0;

    final tvgShiftRaw = double.tryParse(attrs['tvg-shift'] ?? '');

    return ParsedChannel(
      title: title.isNotEmpty ? title : (attrs['tvg-name'] ?? 'Unknown'),
      tvgId: _emptyToNull(attrs['tvg-id']),
      tvgName: _emptyToNull(attrs['tvg-name']),
      logoUrl: _emptyToNull(attrs['tvg-logo']),
      groupTitle: _emptyToNull(attrs['group-title']),
      isRadio: isRadio,
      catchupType: _emptyToNull(attrs['catchup']),
      catchupDays: catchupDaysRaw,
      catchupSource: _emptyToNull(attrs['catchup-source']),
      tvgShift: tvgShiftRaw,
      streamUrl: streamUrl,
      streamHeaders: streamHeaders,
      kodiProps: kodiProps,
    );
  } catch (_) {
    // Never crash on a malformed entry — just skip it.
    return null;
  }
}

/// Extracts the stream URL from a raw URL line, stripping any pipe parameters.
/// E.g. `http://example.com/stream|User-Agent=Foo` → `http://example.com/stream`
String _extractStreamUrl(String rawUrl) {
  final pipeIdx = rawUrl.indexOf('|');
  final url = pipeIdx >= 0 ? rawUrl.substring(0, pipeIdx).trim() : rawUrl.trim();
  // Basic sanity check — must look like a URL or a file path.
  if (url.isEmpty) return '';
  return url;
}

/// Parses pipe-separated HTTP header parameters into a Map.
/// E.g. `http://…|User-Agent=VLC&Referer=http://foo.com`
/// → `{'User-Agent': 'VLC', 'Referer': 'http://foo.com'}`
Map<String, String> _extractPipeHeaders(String rawUrl) {
  final pipeIdx = rawUrl.indexOf('|');
  if (pipeIdx < 0) return const {};

  final params = rawUrl.substring(pipeIdx + 1);
  final headers = <String, String>{};

  for (final part in params.split('&')) {
    final eqIdx = part.indexOf('=');
    if (eqIdx <= 0) continue;
    final key = Uri.decodeComponent(part.substring(0, eqIdx).trim());
    final value = Uri.decodeComponent(part.substring(eqIdx + 1).trim());
    if (key.isNotEmpty) headers[key] = value;
  }

  return headers;
}

/// Regex to match attribute key="value" or key='value' pairs in an EXTINF line.
final _attrPattern = RegExp(
  r'''([\w\-]+)\s*=\s*(?:"([^"]*)"|'([^']*)')''',
  caseSensitive: false,
);

/// Parses EXTINF attribute pairs into a case-folded map.
Map<String, String> _parseAttributes(String section) {
  final attrs = <String, String>{};
  for (final m in _attrPattern.allMatches(section)) {
    final key = m.group(1)!.toLowerCase();
    final value = m.group(2) ?? m.group(3) ?? '';
    attrs[key] = value;
  }
  return attrs;
}

/// Interprets truthy strings ("true", "1", "yes") as `true`.
bool _parseBool(String? value) {
  if (value == null) return false;
  final v = value.toLowerCase().trim();
  return v == 'true' || v == '1' || v == 'yes';
}

/// Returns `null` if [s] is null or blank.
String? _emptyToNull(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  return s.trim();
}
