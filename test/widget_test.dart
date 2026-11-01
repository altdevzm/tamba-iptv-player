import 'package:flutter_test/flutter_test.dart';
import 'package:filimu_plus/features/playlists/data/m3u_parser.dart';
import 'package:filimu_plus/features/epg/data/xmltv_parser.dart';
import 'package:filimu_plus/features/stalker/data/stalker_client.dart';

void main() {
  group('M3U Parser Tests', () {
    test('parses basic M3U with tvg attributes and pipe parameters', () async {
      const sampleM3u = '''#EXTM3U
#EXTINF:-1 tvg-id="cnn.us" tvg-name="CNN HD" tvg-logo="https://example.com/cnn.png" group-title="News",CNN (US) HD
http://stream.example.com/live/cnn.m3u8|User-Agent=CustomAgent&Referer=https://ref.com
#EXTINF:-1 tvg-id="bbc.uk" group-title="News",BBC News
http://stream.example.com/live/bbc.ts
''';

      final channels = await parseM3u(sampleM3u);

      expect(channels.length, 2);

      // Verify channel 1
      final cnn = channels[0];
      expect(cnn.title, 'CNN (US) HD');
      expect(cnn.tvgId, 'cnn.us');
      expect(cnn.tvgName, 'CNN HD');
      expect(cnn.logoUrl, 'https://example.com/cnn.png');
      expect(cnn.groupTitle, 'News');
      expect(cnn.streamUrl, 'http://stream.example.com/live/cnn.m3u8');
      expect(cnn.streamHeaders['User-Agent'], 'CustomAgent');
      expect(cnn.streamHeaders['Referer'], 'https://ref.com');

      // Verify channel 2
      final bbc = channels[1];
      expect(bbc.title, 'BBC News');
      expect(bbc.tvgId, 'bbc.uk');
      expect(bbc.groupTitle, 'News');
      expect(bbc.streamUrl, 'http://stream.example.com/live/bbc.ts');
    });

    test('gracefully ignores comments and blank lines', () async {
      const sampleM3u = '''#EXTM3U

# Some random comment
#EXTINF:-1 group-title="Sports",ESPN
http://sports.example.com/espn.m3u8

''';

      final channels = await parseM3u(sampleM3u);
      expect(channels.length, 1);
      expect(channels.first.title, 'ESPN');
      expect(channels.first.groupTitle, 'Sports');
    });
  });

  group('XMLTV Parser Tests', () {
    test('parses XMLTV channels and programmes correctly', () async {
      const sampleXmltv = '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="cnn.us">
    <display-name>CNN USA</display-name>
    <icon src="https://example.com/cnn.png" />
  </channel>
  <programme start="20261030200000 +0000" stop="20261030210000 +0000" channel="cnn.us">
    <title>Anderson Cooper 360</title>
    <desc>In-depth reporting and interviews.</desc>
    <category>News</category>
  </programme>
</tv>
''';

      final data = await parseXmltv(sampleXmltv);

      expect(data.channels.length, 1);
      expect(data.channels.first.id, 'cnn.us');
      expect(data.channels.first.displayName, 'CNN USA');
      expect(data.channels.first.iconUrl, 'https://example.com/cnn.png');

      expect(data.programs.length, 1);
      final prog = data.programs.first;
      expect(prog.channelId, 'cnn.us');
      expect(prog.title, 'Anderson Cooper 360');
      expect(prog.description, 'In-depth reporting and interviews.');
      expect(prog.category, 'News');
      expect(prog.start, DateTime.utc(2026, 10, 30, 20, 0, 0));
      expect(prog.stop, DateTime.utc(2026, 10, 30, 21, 0, 0));
    });
  });

  group('Stalker Client Tests', () {
    test('credentials copyWith updates token properly', () {
      const creds = StalkerCredentials(
        serverUrl: 'http://portal.example.com:8080/c/',
        macAddress: '00:1A:79:00:11:22',
      );
      expect(creds.token, isNull);

      final updated = creds.copyWith(token: 'test_token_abc');
      expect(updated.token, 'test_token_abc');
      expect(updated.serverUrl, 'http://portal.example.com:8080/c/');
      expect(updated.macAddress, '00:1A:79:00:11:22');
    });
  });
}
