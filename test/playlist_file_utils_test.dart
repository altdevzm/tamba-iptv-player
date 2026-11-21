import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:filimu_plus/core/utils/playlist_file_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (MethodCall methodCall) async {
      final tempDir = await Directory.systemTemp.createTemp();
      return tempDir.path;
    },
  );

  test('persistPickedFile copies XFile contents into app storage', () async {
    final source = XFile.fromData(
      Uint8List.fromList(
        '#EXTM3U\n#EXTINF:-1,Test Channel\nhttp://example.com/stream.m3u8\n'
            .codeUnits,
      ),
      name: 'playlist.m3u',
      mimeType: 'application/octet-stream',
    );

    final savedPath = await PlaylistFileUtils.persistPickedFile(source);

    expect(File(savedPath).existsSync(), isTrue);
    expect(await File(savedPath).readAsString(), contains('Test Channel'));
    expect(await File(savedPath).readAsString(),
        contains('http://example.com/stream.m3u8'));
  });
}
