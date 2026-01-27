import 'dart:ui';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'chat_screen.dart';
import 'announcement_screen.dart';
import 'forum_screen.dart';
import 'account_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  static const List<Widget> _pages = [
    ChatScreen(),
    AnnouncementScreen(),
    ForumScreen(),
    AccountScreen(),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        
        if (isWide) {
          return Container(
            color: Theme.of(context).colorScheme.surfaceContainer,
            child: Row(
              children: [
                _buildNavRail(l10n),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                    ),
                    child: _pages[_selectedIndex],
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: true,
          body: _pages[_selectedIndex],
          bottomNavigationBar: _buildBottomNav(l10n),
        );
      },
    );
  }
  Widget _buildNavRail(AppLocalizations l10n) {
    return NavigationRail(
      backgroundColor: Colors.transparent,
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onItemTapped,
      labelType: NavigationRailLabelType.all,
      destinations: [
        NavigationRailDestination(
          icon: const Icon(Icons.chat_bubble_outline),
          selectedIcon: const Icon(Icons.chat_bubble),
          label: Text(l10n.navChat),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.campaign_outlined),
          selectedIcon: const Icon(Icons.campaign),
          label: Text(l10n.navAnnouncement),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.forum_outlined),
          selectedIcon: const Icon(Icons.forum),
          label: Text(l10n.navForum),
        ),
        NavigationRailDestination(
          icon: const Icon(Icons.account_circle_outlined),
          selectedIcon: const Icon(Icons.account_circle),
          label: Text(l10n.navAccount),
        ),
      ],
    );
  }

  Widget _buildBottomNav(AppLocalizations l10n) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onItemTapped,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.chat_bubble_outline),
                selectedIcon: const Icon(Icons.chat_bubble),
                label: l10n.navChat,
              ),
              NavigationDestination(
                icon: const Icon(Icons.campaign_outlined),
                selectedIcon: const Icon(Icons.campaign),
                label: l10n.navAnnouncement,
              ),
              NavigationDestination(
                icon: const Icon(Icons.forum_outlined),
                selectedIcon: const Icon(Icons.forum),
                label: l10n.navForum,
              ),
              NavigationDestination(
                icon: const Icon(Icons.account_circle_outlined),
                selectedIcon: const Icon(Icons.account_circle),
                label: l10n.navAccount,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
