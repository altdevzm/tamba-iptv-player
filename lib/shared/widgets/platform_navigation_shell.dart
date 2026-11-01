import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/content_details/domain/device_form_factor.dart';
import 'flixor_top_nav_bar.dart';
import 'mobile_bottom_nav.dart';
import 'platform_navigation_sidebar.dart';
import 'top_header_bar.dart';

class PlatformNavigationShell extends StatelessWidget {
  final String currentRoute;
  final Widget child;

  const PlatformNavigationShell({
    super.key,
    required this.currentRoute,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isTv = DeviceFormFactor.isTv(context);
    final isDesktop = DeviceFormFactor.isDesktop(context);
    final width = MediaQuery.sizeOf(context).width;

    if (isTv || isDesktop) {
      final compactSidebar = isTv || width < 1000;
      return Scaffold(
        backgroundColor: const Color(0xFF0E0708),
        body: Row(
          children: [
            PlatformNavigationSidebar(
              currentRoute: currentRoute,
              isTv: isTv,
              compact: compactSidebar,
            ),
            Expanded(
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
          ],
        ),
      );
    }

    final showBottomNavigation =
        width < DeviceFormFactor.mobileNavigationBreakpoint;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0708),
      bottomNavigationBar: showBottomNavigation
          ? FilimuMobileBottomNav(currentRoute: currentRoute)
          : null,
      body: Column(
        children: [
          FlixorTopNavBar(currentRoute: currentRoute),
          Expanded(child: child),
        ],
      ),
    );
  }
}
