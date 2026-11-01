import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

class SidebarNavigation extends StatelessWidget {
  final String currentRoute;

  const SidebarNavigation({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.95),
        border: Border(
          right: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- App Logo Header ---
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 32, bottom: 24),
            child: Row(
              children: [
                Text(
                  'FILIMU',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                        fontSize: 22,
                      ),
                ),
                const SizedBox(width: 4),
                Text(
                  'PLUS',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        fontSize: 22,
                      ),
                ),
              ],
            ),
          ),

          // --- Search Pill ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: InkWell(
              onTap: () => context.go('/search'),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: currentRoute == '/search'
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: currentRoute == '/search'
                        ? AppColors.primary
                        : Colors.white.withValues(alpha: 0.12),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: currentRoute == '/search'
                          ? AppColors.primary
                          : AppColors.textSecondary.withValues(alpha: 0.8),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Search all...',
                      style: TextStyle(
                        color: currentRoute == '/search'
                            ? Colors.white
                            : AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: currentRoute == '/search'
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // --- Navigation Sections ---
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _buildSectionHeader('Home'),
                _buildNavItem(
                  context,
                  icon: Icons.home_rounded,
                  label: 'Home',
                  route: '/home',
                  isActive: currentRoute == '/home' || currentRoute == '/',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.live_tv_rounded,
                  label: 'Live TV',
                  route: '/live',
                  isActive: currentRoute == '/live',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.calendar_view_week_rounded,
                  label: 'TV Guide (EPG)',
                  route: '/epg',
                  isActive: currentRoute == '/epg',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.tv_rounded,
                  label: 'TV Shows',
                  route: '/series',
                  isActive: currentRoute == '/series',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.movie_creation_outlined,
                  label: 'Movies',
                  route: '/movies',
                  isActive: currentRoute == '/movies',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.add_rounded,
                  label: 'My List',
                  route: '/favorites',
                  isActive: currentRoute == '/favorites',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.download_rounded,
                  label: 'Downloads',
                  route: '/downloads',
                  isActive: currentRoute == '/downloads',
                ),
                const SizedBox(height: 24),
                _buildSectionHeader('Library'),
                _buildNavItem(
                  context,
                  icon: Icons.playlist_play_rounded,
                  label: 'Playlists & Providers',
                  route: '/playlists',
                  isActive: currentRoute == '/playlists',
                ),
                _buildNavItem(
                  context,
                  icon: Icons.settings_rounded,
                  label: 'Settings & EPG',
                  route: '/settings',
                  isActive: currentRoute == '/settings',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String route,
    required bool isActive,
  }) {
    return _SidebarNavItem(
      icon: icon,
      label: label,
      route: route,
      isActive: isActive,
    );
  }
}

class _SidebarNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String route;
  final bool isActive;

  const _SidebarNavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isActive,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  bool _isFocused = false;
  bool _isHovered = false;

  void _navigate() {
    if (!widget.isActive) {
      context.go(widget.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.isActive || _isFocused || _isHovered;

    return FocusableActionDetector(
      onFocusChange: (f) => setState(() => _isFocused = f),
      onShowHoverHighlight: (h) => setState(() => _isHovered = h),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => _navigate(),
        ),
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _navigate,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isActive
                    ? Colors.white.withValues(alpha: 0.12)
                    : _isFocused
                        ? AppColors.primary.withValues(alpha: 0.25)
                        : _isHovered
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isFocused ? AppColors.primary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    size: 20,
                    color: highlighted ? Colors.white : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 14),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color:
                          highlighted ? Colors.white : AppColors.textSecondary,
                      fontSize: 13.5,
                      fontWeight:
                          highlighted ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
