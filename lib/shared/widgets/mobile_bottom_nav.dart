import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

/// Compact bottom navigation shared by phone and narrow-window layouts.
class FilimuMobileBottomNav extends StatelessWidget {
  final String currentRoute;

  const FilimuMobileBottomNav({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 62,
              child: Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      icon: Icons.home_rounded,
                      label: 'Home',
                      route: '/home',
                      isActive: currentRoute == '/home' || currentRoute == '/',
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.live_tv_rounded,
                      label: 'Live TV',
                      route: '/live',
                      isActive: currentRoute.startsWith('/live'),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.movie_creation_outlined,
                      label: 'Movies',
                      route: '/movies',
                      isActive: currentRoute.startsWith('/movies'),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.tv_rounded,
                      label: 'Series',
                      route: '/series',
                      isActive: currentRoute.startsWith('/series'),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.bookmark_border_rounded,
                      activeIcon: Icons.bookmark_rounded,
                      label: 'My List',
                      route: '/favorites',
                      isActive: currentRoute.startsWith('/favorites'),
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

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final String route;
  final bool isActive;

  const _NavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.route,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.textSecondary;

    return InkWell(
      onTap: () {
        if (!isActive) {
          context.go(route);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: double.infinity,
        height: 62,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? (activeIcon ?? icon) : icon,
              color: color,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
