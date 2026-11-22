import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;

import '../../../core/theme/app_colors.dart';
import '../../../core/persistence/database_provider.dart';
import '../../../core/persistence/app_database.dart';
import '../../../core/utils/playlist_file_utils.dart';
import '../../../shared/widgets/glass_container.dart';
import '../../../shared/widgets/tv_text_field.dart';
import '../data/playlist_repository_impl.dart';
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
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary));
                  }

                  final playlists = snapshot.data ?? [];

                  if (playlists.isEmpty) {
                    return _buildEmptyState(context);
                  }

                  // Auto-select first playlist as active if none is currently active
                  if (activePlaylistId == null && playlists.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      ref.read(activePlaylistIdProvider.notifier).state =
                          playlists.first.id;
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

  Widget _buildPlaylistCard(
      BuildContext context, PlaylistsTableData playlist, bool isActive) {
    final db = ref.read(databaseProvider);

    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return InkWell(
      onTap: () {
        ref.read(activePlaylistIdProvider.notifier).state = playlist.id;
      },
      borderRadius: BorderRadius.circular(16),
      child: GlassContainer(
        padding: EdgeInsets.all(isMobile ? 14 : 20),
        borderRadius: 16,
        child: Row(
          children: [
            Container(
              width: isMobile ? 42 : 48,
              height: isMobile ? 42 : 48,
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
                    : (playlist.type == 'stalker'
                        ? Icons.router_rounded
                        : Icons.playlist_play_rounded),
                color: isActive ? AppColors.primary : Colors.white70,
                size: isMobile ? 22 : 26,
              ),
            ),
            SizedBox(width: isMobile ? 12 : 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          playlist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 14.5 : 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.primary, width: 0.8),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
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
                      ref.watch(playlistSyncStatusProvider) ??
                          'Downloading channels...',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white54, size: 20),
              tooltip: 'Refresh Playlist',
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  const SnackBar(
                      content: Text('Syncing playlist with provider...'),
                      duration: Duration(seconds: 2)),
                );
                try {
                  if (playlist.type == 'xtream') {
                    final secureStorage = ref.read(secureStorageProvider);
                    final pass =
                        await secureStorage.getPlaylistCredentials(playlist.id);
                    if (pass != null &&
                        playlist.serverUrl != null &&
                        playlist.username != null) {
                      await ref
                          .read(xtreamNotifierProvider.notifier)
                          .refreshPlaylist(
                            playlist.id,
                            XtreamCredentials.normalized(
                              serverUrl: playlist.serverUrl!,
                              username: playlist.username!,
                              password: pass,
                            ),
                          );
                      messenger.showSnackBar(
                        const SnackBar(
                            content: Text('Playlist synced successfully!'),
                            backgroundColor: Colors.green),
                      );
                    }
                  } else if (playlist.type == 'stalker') {
                    if (playlist.serverUrl != null &&
                        playlist.macAddress != null) {
                      await ref
                          .read(stalkerNotifierProvider.notifier)
                          .importPlaylist(
                            playlist.id,
                            StalkerCredentials(
                              serverUrl: playlist.serverUrl!,
                              macAddress: playlist.macAddress!,
                            ),
                          );
                      messenger.showSnackBar(
                        const SnackBar(
                            content:
                                Text('Stalker portal synced successfully!'),
                            backgroundColor: Colors.green),
                      );
                    }
                  } else {
                    await ref
                        .read(playlistNotifierProvider.notifier)
                        .refreshPlaylist(playlist.id);
                    messenger.showSnackBar(
                      const SnackBar(
                          content: Text('Playlist synced successfully!'),
                          backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                        content: Text('Sync failed: $e'),
                        backgroundColor: Colors.red),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.white54),
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
            Icon(Icons.playlist_add_rounded,
                size: 64, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            const Text(
              'No Playlists Configured',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your IPTV M3U playlist file, URL, or connect to your Xtream Codes or Stalker provider.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => _showAddPlaylistDialog(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Add Your First Playlist'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPlaylistDialog(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const AddPlaylistDialog(asBottomSheet: true),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => const AddPlaylistDialog(),
      );
    }
  }
}

enum _PlaylistSourceType { xtream, m3uUrl, m3uFile, stalker }

class AddPlaylistDialog extends ConsumerStatefulWidget {
  final bool asBottomSheet;

  const AddPlaylistDialog({super.key, this.asBottomSheet = false});

  @override
  ConsumerState<AddPlaylistDialog> createState() => _AddPlaylistDialogState();
}

class _AddPlaylistDialogState extends ConsumerState<AddPlaylistDialog> {
  _PlaylistSourceType _selectedType = _PlaylistSourceType.xtream;
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _stalkerServerController = TextEditingController();
  final _stalkerMacController = TextEditingController(text: '00:1A:79:');
  String? _selectedFilePath;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _stalkerServerController.dispose();
    _stalkerMacController.dispose();
    super.dispose();
  }

  void _selectType(_PlaylistSourceType type) {
    if (_isLoading || _selectedType == type) return;
    setState(() {
      _selectedType = type;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final content = _buildSheetContent(context);

    if (widget.asBottomSheet) {
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF141418),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  content,
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141418),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildSheetContent(BuildContext context) {
    final syncStatus = ref.watch(playlistSyncStatusProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Row
        Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.playlist_add_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add IPTV Source',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Choose your provider type to connect',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              icon: Icon(
                Icons.close_rounded,
                color: Colors.white.withValues(alpha: 0.6),
                size: 20,
              ),
              style: IconButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // 2x2 Source Type Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.35,
          children: [
            _buildSourceTile(
              type: _PlaylistSourceType.xtream,
              icon: Icons.cloud_sync_rounded,
              title: 'Xtream Codes',
              subtitle: 'Server & login',
            ),
            _buildSourceTile(
              type: _PlaylistSourceType.m3uUrl,
              icon: Icons.link_rounded,
              title: 'M3U URL',
              subtitle: 'Remote link',
            ),
            _buildSourceTile(
              type: _PlaylistSourceType.m3uFile,
              icon: Icons.folder_open_rounded,
              title: 'M3U File',
              subtitle: 'From device',
            ),
            _buildSourceTile(
              type: _PlaylistSourceType.stalker,
              icon: Icons.router_rounded,
              title: 'Stalker Portal',
              subtitle: 'Portal & MAC',
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Dynamic Form Fields
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey(_selectedType),
            child: _buildFormForSelectedType(),
          ),
        ),

        // Live Progress Card
        if (_isLoading) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        syncStatus ?? 'Connecting & importing channels...',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    minHeight: 4,
                    backgroundColor: Colors.white12,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Error Banner
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: Colors.redAccent.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFFFB4B4),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),

        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed:
                    _isLoading ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _savePlaylist,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.bolt_rounded, size: 18),
                label: Text(
                  _isLoading ? 'Importing...' : 'Connect & Import',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.45),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSourceTile({
    required _PlaylistSourceType type,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _selectedType == type;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectType(type),
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.14)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : Colors.white.withValues(alpha: 0.09),
              width: selected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.22)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  icon,
                  color: selected ? AppColors.primary : Colors.white70,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormForSelectedType() {
    switch (_selectedType) {
      case _PlaylistSourceType.xtream:
        return Column(
          children: [
            _buildTextField(
              _nameController,
              'Playlist Name (optional)',
              'My Xtream IPTV',
              icon: Icons.label_outline_rounded,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              _serverUrlController,
              'Server URL',
              'http://xtream.example.com:8080',
              icon: Icons.dns_rounded,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              _usernameController,
              'Username',
              'Enter username',
              icon: Icons.person_outline_rounded,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              _passwordController,
              'Password',
              'Enter password',
              icon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.white54,
                  size: 18,
                ),
              ),
            ),
          ],
        );

      case _PlaylistSourceType.m3uUrl:
        return Column(
          children: [
            _buildTextField(
              _nameController,
              'Playlist Name',
              'My IPTV Playlist',
              icon: Icons.label_outline_rounded,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              _urlController,
              'M3U / M3U8 URL',
              'https://example.com/playlist.m3u8',
              icon: Icons.link_rounded,
              keyboardType: TextInputType.url,
            ),
          ],
        );

      case _PlaylistSourceType.m3uFile:
        final hasFile = _selectedFilePath != null;
        final fileName =
            hasFile ? _selectedFilePath!.split('/').last : null;
        return Column(
          children: [
            _buildTextField(
              _nameController,
              'Playlist Name',
              'Local M3U Playlist',
              icon: Icons.label_outline_rounded,
            ),
            const SizedBox(height: 12),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isLoading ? null : _pickM3uFile,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    color: hasFile
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: hasFile
                          ? AppColors.primary.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        hasFile
                            ? Icons.check_circle_rounded
                            : Icons.upload_file_rounded,
                        color: hasFile ? AppColors.primary : Colors.white70,
                        size: 30,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasFile ? fileName! : 'Tap to select M3U / M3U8 file',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasFile
                            ? 'Tap again to choose a different file'
                            : 'Supports .m3u and .m3u8 playlists',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );

      case _PlaylistSourceType.stalker:
        return Column(
          children: [
            _buildTextField(
              _nameController,
              'Portal Name',
              'My Stalker Portal',
              icon: Icons.label_outline_rounded,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              _stalkerServerController,
              'Portal URL',
              'http://portal.example.com:8080/c/',
              icon: Icons.dns_rounded,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              _stalkerMacController,
              'MAC Address',
              '00:1A:79:XX:XX:XX',
              icon: Icons.memory_rounded,
            ),
          ],
        );
    }
  }

  Future<void> _pickM3uFile() async {
    // Android's Storage Access Framework often grays out .m3u/.m3u8 files
    // when FileType.custom is used.
    final result = await FilePicker.platform.pickFiles(
      type: Platform.isAndroid ? FileType.any : FileType.custom,
      allowedExtensions: Platform.isAndroid ? null : ['m3u', 'm3u8'],
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.single;
      final copiedPath = await PlaylistFileUtils.persistPickedFile(
        file.xFile,
        preferredName: file.name,
      );
      if (mounted) {
        setState(() {
          _selectedFilePath = copiedPath;
          _errorMessage = null;
        });
      }
    }
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    String hint, {
    IconData? icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TvTextField(
      controller: controller,
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null
          ? Icon(icon, color: Colors.white.withValues(alpha: 0.5), size: 19)
          : null,
      suffixIcon: suffixIcon,
      obscureText: obscureText,
      keyboardType: keyboardType,
      autocorrect: false,
      enabled: !_isLoading,
      borderRadius: 12,
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

    final previousActiveId = ref.read(activePlaylistIdProvider);
    var insertedRow = false;

    try {
      if (_selectedType == _PlaylistSourceType.m3uUrl) {
        // M3U URL
        final rawUrl = _urlController.text.trim();
        if (rawUrl.isEmpty) throw 'Please enter a playlist URL';
        final normalizedUrl = PlaylistRepositoryImpl.normalizeUrl(rawUrl);

        await db.insertPlaylist(
          PlaylistsTableCompanion(
            id: drift.Value(id),
            name: drift.Value(_nameController.text.trim().isEmpty
                ? 'M3U URL'
                : _nameController.text.trim()),
            type: const drift.Value('m3u_url'),
            url: drift.Value(normalizedUrl),
          ),
        );
        insertedRow = true;

        // Await import so progress & any HTTP/parse errors are surfaced cleanly
        await ref
            .read(playlistNotifierProvider.notifier)
            .importFromUrl(id, normalizedUrl);

        ref.read(activePlaylistIdProvider.notifier).state = id;
      } else if (_selectedType == _PlaylistSourceType.m3uFile) {
        // M3U File
        if (_selectedFilePath == null) throw 'Please choose an M3U file';
        final path = _selectedFilePath!;

        await db.insertPlaylist(
          PlaylistsTableCompanion(
            id: drift.Value(id),
            name: drift.Value(_nameController.text.trim().isEmpty
                ? 'M3U File'
                : _nameController.text.trim()),
            type: const drift.Value('m3u_file'),
            filePath: drift.Value(path),
          ),
        );
        insertedRow = true;

        // Await import so progress & parse errors are shown to the user
        await ref
            .read(playlistNotifierProvider.notifier)
            .importFromFile(id, path);

        ref.read(activePlaylistIdProvider.notifier).state = id;
      } else if (_selectedType == _PlaylistSourceType.xtream) {
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
            name: drift.Value(_nameController.text.trim().isEmpty
                ? 'Xtream ($user)'
                : _nameController.text.trim()),
            type: const drift.Value('xtream'),
            serverUrl: drift.Value(normalizedCreds.serverUrl),
            username: drift.Value(user),
          ),
        );
        insertedRow = true;

        // Await import so the user sees the progress spinner and any connection errors
        await ref.read(xtreamNotifierProvider.notifier).importPlaylist(
              id,
              normalizedCreds,
            );

        ref.read(activePlaylistIdProvider.notifier).state = id;
      } else {
        // Stalker Portal
        final server = _stalkerServerController.text.trim();
        final mac = StalkerClient.normalizeMac(_stalkerMacController.text);
        final name = _nameController.text.trim().isEmpty
            ? 'Stalker Portal'
            : _nameController.text.trim();

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
        insertedRow = true;

        // Await import so progress & connection/MAC errors are shown cleanly
        await ref.read(stalkerNotifierProvider.notifier).importPlaylist(
              id,
              StalkerCredentials(serverUrl: server, macAddress: mac),
            );

        ref.read(activePlaylistIdProvider.notifier).state = id;
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Clean up orphaned empty playlist row if import failed.
      if (insertedRow) {
        await db.deletePlaylist(id);
        ref.read(activePlaylistIdProvider.notifier).state = previousActiveId;
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }
}
