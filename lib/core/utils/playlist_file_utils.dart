import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PlaylistFileUtils {
  static Future<String> persistPickedFile(XFile xFile,
      {String? preferredName}) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final destinationDir =
        Directory(p.join(docsDir.path, 'imported_playlists'));
    if (!await destinationDir.exists()) {
      await destinationDir.create(recursive: true);
    }

    final originalName = (preferredName ?? xFile.name).trim();
    final safeBaseName = originalName.isEmpty ? 'playlist' : originalName;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName =
        '${p.basenameWithoutExtension(safeBaseName)}_$timestamp${p.extension(safeBaseName)}';

    final destination = File(p.join(destinationDir.path, safeName));
    final bytes = await xFile.readAsBytes();
    await destination.writeAsBytes(bytes, flush: true);
    return destination.path;
  }
}
