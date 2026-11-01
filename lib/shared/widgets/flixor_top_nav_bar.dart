import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/persistence/database_provider.dart';
import '../../features/content_details/domain/device_form_factor.dart';
import '../../features/live_tv/presentation/live_tv_view.dart';
import '../../features/movies/presentation/movies_view.dart';
import '../../features/search/presentation/global_search_view.dart';
import '../../features/series/presentation/series_notifier.dart';

class FlixorTopNavBar extends ConsumerStatefulWidget {
  final String currentRoute;

  const FlixorTopNavBar({
    super.key,
    required this.currentRoute,
  });

  @override
  ConsumerState<FlixorTopNavBar> createState() => _FlixorTopNavBarState();
}

class _FlixorTopNavBarState extends ConsumerState<FlixorTopNavBar> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _syncSearchController(String value) {
    if (_searchController.text == value) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _searchController.text == value) return;
      _searchController.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSyncing = ref.watch(isSyncingPlaylistProvider);
    final syncStatus = ref.watch(playlistSyncStatusProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 768 && !DeviceFormFactor.isTv(context)) {
      return _buildMobileHeader(context);
    }
    final isVeryCompact = screenWidth < 600;

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0708).withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // ── App Brand Logo (Red Play Icon + FLIXOR) ──
          InkWell(
            onTap: () => context.go('/home'),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE50914).withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                if (!isVeryCompact) ...[
                  const SizedBox(width: 8),
                  const Text(
                    'FLIXOR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Directly Visible Navigation Capsule (Scrollable on narrow viewports) ──
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildNavPill(
                        label: 'Home',
                        route: '/home',
                        icon: Icons.home_rounded,
                        isActive: widget.currentRoute == '/home' ||
                            widget.currentRoute == '/',
                        context: context,
                      ),
                      _buildNavPill(
                        label: 'Live TV',
                        route: '/live',
                        icon: Icons.live_tv_rounded,
                        isActive: widget.currentRoute.startsWith('/live'),
                        context: context,
                      ),
                      _buildNavPill(
                        label: 'Movies',
                        route: '/movies',
                        icon: Icons.movie_rounded,
                        isActive: widget.currentRoute.startsWith('/movies'),
                        context: context,
                      ),
                      _buildNavPill(
                        label: 'TV Shows',
                        route: '/series',
                        icon: Icons.tv_rounded,
                        isActive: widget.currentRoute.startsWith('/series'),
                        context: context,
                      ),
                      _buildNavPill(
                        label: 'My List',
                        route: '/favorites',
                        icon: Icons.bookmark_rounded,
                        isActive: widget.currentRoute.startsWith('/favorites'),
                        context: context,
                      ),
                      _buildNavPill(
                        label: 'Settings',
                        route: '/settings',
                        icon: Icons.settings_rounded,
                        isActive: widget.currentRoute.startsWith('/settings'),
                        context: context,
                      ),
                      _buildNavPill(
                        label: 'Search',
                        route: '/search',
                        icon: Icons.search_rounded,
                        isActive: widget.currentRoute.startsWith('/search'),
                        context: context,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // ── Right Status / Format Badge ("UHD 770") ──
          if (isSyncing) ...[
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 6),
            if (screenWidth > 1000)
              Text(
                syncStatus ?? 'Syncing...',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileHeader(BuildContext context) {
    final isMoviesRoute = widget.currentRoute.startsWith('/movies') ||
        widget.currentRoute.startsWith('/popular');
    final isSeriesRoute = widget.currentRoute.startsWith('/series');
    final isLiveRoute = widget.currentRoute.startsWith('/live');
    final isGlobalSearchRoute = widget.currentRoute.startsWith('/search');
    final isSearchEnabled =
        isMoviesRoute || isSeriesRoute || isLiveRoute || isGlobalSearchRoute;
    final searchQuery = isMoviesRoute
        ? ref.watch(moviesFilterProvider.select((state) => state.searchQuery))
        : isSeriesRoute
            ? ref.watch(
                seriesFilterProvider.select((state) => state.searchQuery))
            : isLiveRoute
                ? ref.watch(
                    liveTvNotifierProvider.select((state) => state.searchQuery))
                : isGlobalSearchRoute
                    ? ref.watch(
                        globalSearchProvider.select((state) => state.query))
                    : null;

    if (searchQuery != null) {
      _syncSearchController(searchQuery);
    } else if (!isSearchEnabled && _searchController.text.isNotEmpty) {
      _syncSearchController('');
    }

    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 44,
                child: TextField(
                  controller: _searchController,
                  readOnly: !isSearchEnabled,
                  onTap: isSearchEnabled ? null : () => context.go('/search'),
                  onChanged: (value) {
                    if (isMoviesRoute) {
                      ref
                          .read(moviesFilterProvider.notifier)
                          .setSearchQuery(value);
                    } else if (isSeriesRoute) {
                      ref
                          .read(seriesFilterProvider.notifier)
                          .setSearchQuery(value);
                    } else if (isLiveRoute) {
                      ref.read(liveTvNotifierProvider.notifier).search(value);
                    } else if (isGlobalSearchRoute) {
                      ref.read(globalSearchProvider.notifier).setQuery(value);
                    }
                  },
                  onSubmitted: isGlobalSearchRoute
                      ? (value) => ref
                          .read(globalSearchProvider.notifier)
                          .addRecentSearch(value)
                      : null,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: isMoviesRoute
                        ? 'Search movies...'
                        : isSeriesRoute
                            ? 'Search TV series...'
                            : isLiveRoute
                                ? 'Search channels...'
                                : 'Search movies, shows and channels',
                    hintStyle: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.textSecondary, size: 20),
                    suffixIcon:
                        isSearchEnabled && _searchController.text.isNotEmpty
                            ? IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  if (isMoviesRoute) {
                                    ref
                                        .read(moviesFilterProvider.notifier)
                                        .setSearchQuery('');
                                  } else if (isSeriesRoute) {
                                    ref
                                        .read(seriesFilterProvider.notifier)
                                        .setSearchQuery('');
                                  } else if (isLiveRoute) {
                                    ref
                                        .read(liveTvNotifierProvider.notifier)
                                        .search('');
                                  } else {
                                    ref
                                        .read(globalSearchProvider.notifier)
                                        .setQuery('');
                                  }
                                },
                                icon: const Icon(Icons.close_rounded, size: 18),
                              )
                            : null,
                    filled: true,
                    fillColor: AppColors.surfaceElevated,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.glassBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: AppColors.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.settings_outlined),
            color: Colors.white,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildNavPill({
    required String label,
    required String route,
    required IconData icon,
    required bool isActive,
    required BuildContext context,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: () => context.go(route),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? Colors.white : Colors.white60,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isActive
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
