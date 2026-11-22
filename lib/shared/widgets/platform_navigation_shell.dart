import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../features/content_details/domain/device_form_factor.dart';
import 'flixor_top_nav_bar.dart';
import 'mobile_bottom_nav.dart';
import 'platform_navigation_sidebar.dart';
import 'top_header_bar.dart';

class PlatformNavigationShell extends StatelessWidget {
  final String currentRoute;
  final StatefulNavigationShell? navigationShell;
  final Widget child;

  const PlatformNavigationShell({
    super.key,
    required this.currentRoute,
    this.navigationShell,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DeviceFormFactor.forceTvMode,
      builder: (context, _, __) {
        final isTv = DeviceFormFactor.isTv(context);
        final isDesktop = DeviceFormFactor.isDesktop(context);
        final width = MediaQuery.sizeOf(context).width;

        if (isTv || isDesktop) {
          final compactSidebar = isTv || width < 1000;
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Row(
              children: [
                FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: PlatformNavigationSidebar(
                    currentRoute: currentRoute,
                    isTv: isTv,
                    compact: compactSidebar,
                  ),
                ),
                Expanded(
                  child: FocusTraversalGroup(
                    policy: ReadingOrderTraversalPolicy(),
                    child: Column(
                      children: [
                        if (isDesktop)
                          TopHeaderBar(
                            onProfileTap: () => context.go('/settings'),
                          ),
                        Expanded(child: child),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final showBottomNavigation =
            width < DeviceFormFactor.mobileNavigationBreakpoint;

        return Scaffold(
          backgroundColor: AppColors.background,
          bottomNavigationBar: showBottomNavigation
              ? FilimuMobileBottomNav(
                  currentRoute: currentRoute,
                  navigationShell: navigationShell,
                )
              : null,
          body: Column(
            children: [
              FocusTraversalGroup(
                policy: ReadingOrderTraversalPolicy(),
                child: FlixorTopNavBar(
                  currentRoute: currentRoute,
                  navigationShell: navigationShell,
                ),
              ),
              Expanded(
                child: FocusTraversalGroup(
                  policy: ReadingOrderTraversalPolicy(),
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
