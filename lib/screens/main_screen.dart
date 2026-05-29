import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../routes/app_routes.dart';
import '../models/app_state.dart';
import '../services/auth_state.dart';

class MainScreen extends StatefulWidget {
  final Widget child;
  const MainScreen({super.key, required this.child});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _getCurrentIndex(
    BuildContext context,
    List<_NavDestinationConfig> destinations,
  ) {
    final String location = GoRouterState.of(context).uri.toString();
    final index = destinations.indexWhere(
      (destination) => _matchesLocation(location, destination.route),
    );
    return index >= 0 ? index : 0;
  }

  bool _isInChatDetail(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    return location.startsWith('/chat/') && location != '/chat';
  }

  bool _matchesLocation(String location, String route) {
    if (route == AppRoutes.chat) {
      return location == AppRoutes.main || location == AppRoutes.chat || location.startsWith('${AppRoutes.chat}/');
    }
    return location == route || location.startsWith('$route/');
  }

  List<_NavDestinationConfig> _buildDestinations(AppLocalizations l10n) {
    return [
      _NavDestinationConfig(
        route: AppRoutes.chat,
        label: l10n.navChat,
        icon: Icons.chat_bubble_outline,
        selectedIcon: Icons.chat_bubble,
      ),
      _NavDestinationConfig(
        route: AppRoutes.announcement,
        label: l10n.navAnnouncement,
        icon: Icons.campaign_outlined,
        selectedIcon: Icons.campaign,
      ),
      _NavDestinationConfig(
        route: AppRoutes.forum,
        label: l10n.navForum,
        icon: Icons.forum_outlined,
        selectedIcon: Icons.forum,
      ),
      _NavDestinationConfig(
        route: AppRoutes.account,
        label: l10n.navAccount,
        icon: Icons.account_circle_outlined,
        selectedIcon: Icons.account_circle,
      ),
      if (AuthState.instance.currentUser?.hasAdminAccess == true)
        _NavDestinationConfig(
          route: AppRoutes.admin,
          label: l10n.navAdmin,
          icon: Icons.admin_panel_settings_outlined,
          selectedIcon: Icons.admin_panel_settings,
        ),
    ];
  }

  void _onItemTapped(
    BuildContext context,
    List<_NavDestinationConfig> destinations,
    int index,
  ) {
    if (index < 0 || index >= destinations.length) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    context.go(destinations[index].route);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthState.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final destinations = _buildDestinations(l10n);
        final selectedIndex = _getCurrentIndex(context, destinations);
        final appState = AppState.instance;
        final backgroundImagePath = appState.backgroundImagePath;
        final hasBackgroundImage =
            backgroundImagePath != null && backgroundImagePath.isNotEmpty;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 600;

            if (isWide) {
              return Container(
                color: hasBackgroundImage
                    ? Colors.transparent
                    : Theme.of(context).colorScheme.surfaceContainer,
                child: Row(
                  children: [
                    Container(
                      color: hasBackgroundImage
                          ? Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.7)
                          : Colors.transparent,
                      child: _buildNavRail(destinations, selectedIndex, context),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                        ),
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              );
            }
            final showBottomNav = !_isInChatDetail(context);
            return Scaffold(
              extendBody: true,
              body: widget.child,
              bottomNavigationBar: showBottomNav
                  ? _buildBottomNav(destinations, selectedIndex, context)
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildNavRail(
    List<_NavDestinationConfig> destinations,
    int selectedIndex,
    BuildContext context,
  ) {
    return NavigationRail(
      backgroundColor: Colors.transparent,
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) => _onItemTapped(context, destinations, index),
      labelType: NavigationRailLabelType.all,
      destinations: [
        for (final destination in destinations)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label),
          ),
      ],
    );
  }

  Widget _buildBottomNav(
    List<_NavDestinationConfig> destinations,
    int selectedIndex,
    BuildContext context,
  ) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            selectedIndex: selectedIndex,
            onDestinationSelected: (index) => _onItemTapped(context, destinations, index),
            destinations: [
              for (final destination in destinations)
                NavigationDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: destination.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavDestinationConfig {
  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _NavDestinationConfig({
    required this.route,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}
