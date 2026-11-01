import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/theme/app_colors.dart';
import '../../../core/persistence/database_provider.dart';
import '../../../core/persistence/app_database.dart';
import '../../../shared/widgets/glass_container.dart';
import 'playlist_notifier.dart';
import '../../xtream/presentation/xtream_notifier.dart';
import '../../xtream/data/xtream_client.dart';
import '../../stalker/presentation/stalker_notifier.dart';
import '../../stalker/data/stalker_client.dart';

class PlaylistsView extends ConsumerStatefulWidget {
  const PlaylistsView({super.key});

  @override
  ConsumerState<PlaylistsView> createState() => _PlaylistsViewState();
}

class _PlaylistsViewState extends ConsumerState<PlaylistsView> {
  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final activePlaylistId = ref.watch(activePlaylistIdProvider);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 32,
          vertical: isMobile ? 16 : 28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Playlists & Providers',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 22 : 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage your M3U playlists, Xtream Codes, and Stalker portals',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: isMobile ? 12 : 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showAddPlaylistDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(isMobile ? 'Add' : 'Add Playlist'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 12 : 20,
                      vertical: isMobile ? 10 : 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Playlists List
            Expanded(
              child: StreamBuilder<List<PlaylistsTableData>>(
                stream: db.watchAllPlaylists(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }

                  final playlists = snapshot.data ?? [];

                  if (playlists.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  // Auto-select first playlist as active if none is currently active
                  if (activePlaylistId == null && playlists.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ref.read(activePlaylistIdProvider.notifier).state = playlists.first.id;
                    });
                  }

                  return ListView.separated(
                    itemCount: playlists.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final p = playlists[index];
                      final isActive = p.id == activePlaylistId;
                      return _buildPlaylistCard(context, p, isActive);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaylistCard(BuildContext context, PlaylistsTableData playlist, bool isActive) {
    final db = ref.read(databaseProvider);

    return InkWell(
      onTap: () {
        ref.read(activePlaylistIdProvider.notifier).state = playlist.id;
      },
      borderRadius: BorderRadius.circular(16),
      child: GlassContainer(
        padding: const EdgeInsets.all(20),
        borderRadius: 16,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.12),
                ),
              ),
              child: Icon(
                playlist.type == 'xtream'
                    ? Icons.cloud_done_rounded
                    : (playlist.type == 'stalker' ? Icons.router_rounded : Icons.playlist_play_rounded),
                color: isActive ? AppColors.primary : Colors.white70,
                size: 26,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        playlist.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primary, width: 0.8),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${playlist.type.toUpperCase()} • ${playlist.channelCount} items • ${playlist.serverUrl ?? playlist.url ?? playlist.filePath ?? "Local"}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                  if (isActive && ref.watch(isSyncingPlaylistProvider)) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: const LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor: Colors.white10,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ref.watch(playlistSyncStatusProvider) ?? 'Downloading channels...',
                      style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 20),
              tooltip: 'Refresh Playlist',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Syncing playlist with provider...'), duration: Duration(seconds: 2)),
                );
                try {
                  if (playlist.type == 'xtream') {
                    final secureStorage = ref.read(secureStorageProvider);
                    final pass = await secureStorage.getPlaylistCredentials(playlist.id);
                    if (pass != null && playlist.serverUrl != null && playlist.username != null) {
                      await ref.read(xtreamNotifierProvider.notifier).refreshPlaylist(
                            playlist.id,
                            XtreamCredentials.normalized(
                              serverUrl: playlist.serverUrl!,
                              username: playlist.username!,
                              password: pass,
                            ),
                          );
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Playlist synced successfully!'), backgroundColor: Colors.green),
                      );
                    }
                  } else if (playlist.type == 'stalker') {
                    if (playlist.serverUrl != null && playlist.macAddress != null) {
                      await ref.read(stalkerNotifierProvider.notifier).importPlaylist(
                            playlist.id,
                            StalkerCredentials(
                              serverUrl: playlist.serverUrl!,
                              macAddress: playlist.macAddress!,
                            ),
                          );
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Stalker portal synced successfully!'), backgroundColor: Colors.green),
                      );
                    }
                  } else {
                    await ref.read(playlistNotifierProvider.notifier).refreshPlaylist(playlist.id);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Playlist synced successfully!'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54),
              tooltip: 'Delete Playlist',
              onPressed: () async {
                await db.deletePlaylist(playlist.id);
                if (isActive) {
                  ref.read(activePlaylistIdProvider.notifier).state = null;
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: GlassContainer(
        width: 500,
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.playlist_add_rounded, size: 64, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text(
              'No Playlists Configured',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your IPTV M3U playlist file, URL, or connect to your Xtream Codes or Stalker provider.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _showAddPlaylistDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Add Your First Playlist'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPlaylistDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddPlaylistDialog(),
    );
  }
}

class AddPlaylistDialog extends ConsumerStatefulWidget {
  const AddPlaylistDialog({super.key});

  @override
  ConsumerState<AddPlaylistDialog> createState() => _AddPlaylistDialogState();
}

class _AddPlaylistDialogState extends ConsumerState<AddPlaylistDialog> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _stalkerServerController = TextEditingController();
  final _stalkerMacController = TextEditingController(text: '00:1A:79:');
  String? _selectedFilePath;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _urlController.dispose();
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _stalkerServerController.dispose();
    _stalkerMacController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassContainer(
        width: 540,
        padding: const EdgeInsets.all(28),
        borderRadius: 20,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add New IPTV Source',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.white54,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'M3U URL'),
                Tab(text: 'M3U File'),
                Tab(text: 'Xtream Codes'),
                Tab(text: 'Stalker Portal'),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 240,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: M3U URL
                  Column(
                    children: [
                      _buildTextField(_nameController, 'Playlist Name', 'My IPTV'),
                      const SizedBox(height: 12),
                      _buildTextField(_urlController, 'Playlist URL', 'https://example.com/playlist.m3u'),
                    ],
                  ),
                  // Tab 2: M3U File
                  Column(
                    children: [
                      _buildTextField(_nameController, 'Playlist Name', 'Local M3U'),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['m3u', 'm3u8'],
                          );
                          if (result != null && result.files.single.path != null) {
                            setState(() {
                              _selectedFilePath = result.files.single.path;
                            });
                          }
                        },
                        icon: const Icon(Icons.file_open_rounded, color: Colors.white),
                        label: Text(
                          _selectedFilePath != null
                              ? _selectedFilePath!.split('/').last
                              : 'Select M3U/M3U8 File',
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                      ),
                    ],
                  ),
                  // Tab 3: Xtream Codes
                  Column(
                    children: [
                      _buildTextField(_serverUrlController, 'Server URL', 'http://xtream.example.com:8080'),
                      const SizedBox(height: 10),
                      _buildTextField(_usernameController, 'Username', 'user123'),
                      const SizedBox(height: 10),
                      _buildTextField(_passwordController, 'Password', '••••••••', obscureText: true),
                    ],
                  ),
                  // Tab 4: Stalker Portal
                  Column(
                    children: [
                      _buildTextField(_nameController, 'Portal Name', 'My Stalker Portal'),
                      const SizedBox(height: 10),
                      _buildTextField(_stalkerServerController, 'Portal URL', 'http://stalker.example.com/c/'),
                      const SizedBox(height: 10),
                      _buildTextField(_stalkerMacController, 'MAC Address', '00:1A:79:XX:XX:XX'),
                    ],
                  ),
                ],
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  minHeight: 5,
                  backgroundColor: Colors.white12,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ref.watch(playlistSyncStatusProvider) ?? 'Connecting to IPTV provider & importing channels...',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _savePlaylist,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Save & Import'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white, fontSize: 13.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Future<void> _savePlaylist() async {
    final db = ref.read(databaseProvider);
    final secureStorage = ref.read(secureStorageProvider);
    final id = const Uuid().v4();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_tabController.index == 0) {
        // M3U URL
        final url = _urlController.text.trim();
        if (url.isEmpty) throw 'Please enter a playlist URL';

        await db.insertPlaylist(
          PlaylistsTableCompanion(
            id: drift.Value(id),
            name: drift.Value(_nameController.text.trim().isEmpty ? 'M3U URL' : _nameController.text.trim()),
            type: const drift.Value('m3u_url'),
            url: drift.Value(url),
          ),
        );

        ref.read(activePlaylistIdProvider.notifier).state = id;

        // Trigger import in background
        ref.read(playlistNotifierProvider.notifier).importFromUrl(id, url);
      } else if (_tabController.index == 1) {
        // M3U File
        if (_selectedFilePath == null) throw 'Please choose an M3U file';
        final path = _selectedFilePath!;

        await db.insertPlaylist(
          PlaylistsTableCompanion(
            id: drift.Value(id),
            name: drift.Value(_nameController.text.trim().isEmpty ? 'M3U File' : _nameController.text.trim()),
            type: const drift.Value('m3u_file'),
            filePath: drift.Value(path),
          ),
        );

        ref.read(activePlaylistIdProvider.notifier).state = id;

        // Trigger import in background
        ref.read(playlistNotifierProvider.notifier).importFromFile(id, path);
      } else if (_tabController.index == 2) {
        // Xtream Codes
        final server = _serverUrlController.text.trim();
        final user = _usernameController.text.trim();
        final pass = _passwordController.text.trim();

        if (server.isEmpty || user.isEmpty || pass.isEmpty) {
          throw 'Please fill all Xtream Codes fields';
        }

        final normalizedCreds = XtreamCredentials.normalized(
          serverUrl: server,
          username: user,
          password: pass,
        );

        await secureStorage.savePlaylistCredentials(id, pass);

        await db.insertPlaylist(
          PlaylistsTableCompanion(
            id: drift.Value(id),
            name: drift.Value(_nameController.text.trim().isEmpty ? 'Xtream ($user)' : _nameController.text.trim()),
            type: const drift.Value('xtream'),
            serverUrl: drift.Value(normalizedCreds.serverUrl),
            username: drift.Value(user),
          ),
        );

        ref.read(activePlaylistIdProvider.notifier).state = id;

        // Await import so the user sees the progress spinner and any connection errors
        await ref.read(xtreamNotifierProvider.notifier).importPlaylist(
              id,
              normalizedCreds,
            );
      } else {
        // Stalker Portal
        final server = _stalkerServerController.text.trim();
        final mac = _stalkerMacController.text.trim();
        final name = _nameController.text.trim().isEmpty ? 'Stalker Portal' : _nameController.text.trim();

        if (server.isEmpty || mac.isEmpty) {
          throw 'Please provide Portal URL and MAC Address';
        }

        await db.insertPlaylist(
          PlaylistsTableCompanion(
            id: drift.Value(id),
            name: drift.Value(name),
            type: const drift.Value('stalker'),
            serverUrl: drift.Value(server),
            macAddress: drift.Value(mac),
          ),
        );

        ref.read(activePlaylistIdProvider.notifier).state = id;

        // Trigger import in background
        ref.read(stalkerNotifierProvider.notifier).importPlaylist(
              id,
              StalkerCredentials(serverUrl: server, macAddress: mac),
            );
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }
}
