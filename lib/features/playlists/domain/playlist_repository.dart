/// Abstract interface for playlist import and refresh operations.
abstract class PlaylistRepository {
  /// Downloads an M3U playlist from [url] and stores its channels under [playlistId].
  Future<void> importFromUrl(
    String playlistId,
    String url, {
    void Function(String status)? onProgress,
  });

  /// Reads an M3U playlist from a local [filePath] and stores its channels under [playlistId].
  Future<void> importFromFile(
    String playlistId,
    String filePath, {
    void Function(String status)? onProgress,
  });

  /// Re-fetches and re-parses the playlist identified by [playlistId].
  Future<void> refreshPlaylist(
    String playlistId, {
    void Function(String status)? onProgress,
  });
}
