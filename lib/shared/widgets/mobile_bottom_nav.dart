import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

/// Modern mobile bottom navigation bar with safe-area support and stateful tab switching.
class FilimuMobileBottomNav extends StatelessWidget {
  final String currentRoute;
  final StatefulNavigationShell? navigationShell;

  const FilimuMobileBottomNav({
    super.key,
    required this.currentRoute,
    this.navigationShell,
  });

  void _onSelectTab(BuildContext context, int branchIndex, String route) {
    if (navigationShell != null) {
      navigationShell!.goBranch(
        branchIndex,
        initialLocation: branchIndex == navigationShell!.currentIndex,
      );
    } else if (currentRoute != route) {
      context.go(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = navigationShell?.currentIndex;

    final isHome = activeIndex != null
        ? activeIndex == 0
        : (currentRoute == '/home' || currentRoute == '/');
    final isLive = activeIndex != null
        ? activeIndex == 1
        : (currentRoute.startsWith('/live') || currentRoute.startsWith('/epg'));
    final isMovies = activeIndex != null
        ? activeIndex == 2
        : (currentRoute.startsWith('/movies') ||
            currentRoute.startsWith('/popular'));
    final isSeries = activeIndex != null
        ? activeIndex == 3
        : currentRoute.startsWith('/series');
    final isMyList = activeIndex != null
        ? activeIndex == 4
        : currentRoute.startsWith('/favorites');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101015),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.8,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  isActive: isHome,
                  onTap: () => _onSelectTab(context, 0, '/home'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.live_tv_outlined,
                  activeIcon: Icons.live_tv_rounded,
                  label: 'TV',
                  isActive: isLive,
                  onTap: () => _onSelectTab(context, 1, '/live'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.movie_outlined,
                  activeIcon: Icons.movie_rounded,
                  label: 'Movies',
                  isActive: isMovies,
                  onTap: () => _onSelectTab(context, 2, '/movies'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.tv_outlined,
                  activeIcon: Icons.tv_rounded,
                  label: 'Series',
                  isActive: isSeries,
                  onTap: () => _onSelectTab(context, 3, '/series'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.bookmark_border_rounded,
                  activeIcon: Icons.bookmark_rounded,
                  label: 'My List',
                  isActive: isMyList,
                  onTap: () => _onSelectTab(context, 4, '/favorites'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? Colors.white : AppColors.textMuted;

    return InkWell(
      onTap: onTap,
      splashColor: AppColors.primary.withValues(alpha: 0.14),
      highlightColor: Colors.transparent,
      child: SizedBox(
        width: double.infinity,
        height: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: isActive ? 22 : 0,
              height: 2.5,
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? Colors.white : color,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
