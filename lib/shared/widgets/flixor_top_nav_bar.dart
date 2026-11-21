import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/persistence/app_database.dart';
import '../../core/persistence/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../features/content_details/domain/device_form_factor.dart';

class FlixorTopNavBar extends ConsumerWidget {
  final String currentRoute;
  final StatefulNavigationShell? navigationShell;

  const FlixorTopNavBar({
    super.key,
    required this.currentRoute,
    this.navigationShell,
  });

  void _navigateTab(BuildContext context, int branchIndex, String route) {
    if (navigationShell != null) {
      navigationShell!.goBranch(branchIndex);
    } else {
      context.go(route);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncing = ref.watch(isSyncingPlaylistProvider);
    final syncStatus = ref.watch(playlistSyncStatusProvider);
    final screenWidth = MediaQuery.sizeOf(context).width;

    if (screenWidth < 768 && !DeviceFormFactor.isTv(context)) {
      return _buildMobileHeader(context, ref, isSyncing: isSyncing);
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 58,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildNavPill(
                            label: 'Home',
                            icon: Icons.home_rounded,
                            isActive:
                                currentRoute == '/home' || currentRoute == '/',
                            onTap: () => _navigateTab(context, 0, '/home'),
                          ),
                          _buildNavPill(
                            label: 'Live TV',
                            icon: Icons.live_tv_rounded,
                            isActive: currentRoute.startsWith('/live'),
                            onTap: () => _navigateTab(context, 1, '/live'),
                          ),
                          _buildNavPill(
                            label: 'Movies',
                            icon: Icons.movie_rounded,
                            isActive: currentRoute.startsWith('/movies'),
                            onTap: () => _navigateTab(context, 2, '/movies'),
                          ),
                          _buildNavPill(
                            label: 'Series',
                            icon: Icons.tv_rounded,
                            isActive: currentRoute.startsWith('/series'),
                            onTap: () => _navigateTab(context, 3, '/series'),
                          ),
                          _buildNavPill(
                            label: 'My List',
                            icon: Icons.bookmark_rounded,
                            isActive: currentRoute.startsWith('/favorites'),
                            onTap: () => _navigateTab(context, 4, '/favorites'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (isSyncing) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  if (screenWidth > 960 && syncStatus != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      syncStatus,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(width: 10),
                ],
                IconButton(
                  tooltip: 'Search',
                  onPressed: () => context.go('/search'),
                  icon: Icon(
                    Icons.search_rounded,
                    color: currentRoute.startsWith('/search')
                        ? AppColors.primary
                        : Colors.white,
                  ),
                ),
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () => context.go('/settings'),
                  icon: Icon(
                    currentRoute.startsWith('/settings')
                        ? Icons.settings_rounded
                        : Icons.settings_outlined,
                    color: currentRoute.startsWith('/settings')
                        ? AppColors.primary
                        : Colors.white,
                  ),
                ),
                const SizedBox(width: 4),
                _ProfileAvatarButton(
                  isActive: currentRoute.startsWith('/playlists'),
                  onTap: () => _showProfileSheet(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeader(
    BuildContext context,
    WidgetRef ref, {
    required bool isSyncing,
  }) {
    final isSearch = currentRoute.startsWith('/search');
    final isSettings = currentRoute.startsWith('/settings');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 0.8,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 52,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Spacer(),
                if (isSyncing) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                IconButton(
                  tooltip: 'Search',
                  onPressed: () => context.go('/search'),
                  icon: Icon(
                    Icons.search_rounded,
                    color: isSearch ? AppColors.primary : Colors.white,
                    size: 23,
                  ),
                  constraints:
                      const BoxConstraints.tightFor(width: 40, height: 40),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () => context.go('/settings'),
                  icon: Icon(
                    isSettings
                        ? Icons.settings_rounded
                        : Icons.settings_outlined,
                    color: isSettings ? AppColors.primary : Colors.white,
                    size: 22,
                  ),
                  constraints:
                      const BoxConstraints.tightFor(width: 40, height: 40),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(width: 2),
                _ProfileAvatarButton(
                  isActive: currentRoute.startsWith('/playlists'),
                  onTap: () => _showProfileSheet(context, ref),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showProfileSheet(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final activePlaylistId = ref.read(activePlaylistIdProvider);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          top: false,
          child: StreamBuilder<List<PlaylistsTableData>>(
            stream: db.watchAllPlaylists(),
            builder: (context, snapshot) {
              final playlists = snapshot.data ?? [];
              final active =
                  playlists.where((p) => p.id == activePlaylistId).firstOrNull ??
                      playlists.firstOrNull;

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const Icon(
                            Icons.account_circle_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                active?.name ?? 'Tamba IPTV Profile',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                active != null
                                    ? '${active.type.toUpperCase()} • ${active.channelCount} items'
                                    : 'No active playlist connected',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.playlist_play_rounded,
                          color: Colors.white),
                      title: const Text('My Playlists & Providers',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textMuted),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        context.go('/playlists');
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.bookmark_rounded,
                          color: Colors.white),
                      title: const Text('My List & Favorites',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textMuted),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        _navigateTab(context, 4, '/favorites');
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.download_done_rounded,
                          color: Colors.white),
                      title: const Text('Downloads',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textMuted),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        context.go('/downloads');
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.settings_rounded,
                          color: Colors.white),
                      title: const Text('Settings',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                      trailing: const Icon(Icons.chevron_right_rounded,
                          color: AppColors.textMuted),
                      onTap: () {
                        Navigator.pop(sheetCtx);
                        context.go('/settings');
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildNavPill({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isActive ? Colors.white : Colors.white60,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white70,
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatarButton extends StatelessWidget {
  final bool isActive;
  final VoidCallback onTap;

  const _ProfileAvatarButton({
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Profile & Account',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Icon(
              isActive
                  ? Icons.account_circle_rounded
                  : Icons.account_circle_outlined,
              color: isActive ? AppColors.primary : Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
