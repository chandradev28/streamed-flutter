import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'playlist_screen.dart';
import 'search_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  static final List<_ShellTab> _tabs = <_ShellTab>[
    _ShellTab(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      builder: (_) => HomeScreen(),
    ),
    _ShellTab(
      label: 'Playlist',
      icon: Icons.movie_outlined,
      activeIcon: Icons.movie,
      builder: (_) => const PlaylistScreen(),
    ),
    _ShellTab(
      label: 'Search',
      icon: Icons.search_outlined,
      activeIcon: Icons.search,
      builder: (_) => const SearchScreen(),
    ),
    _ShellTab(
      label: 'Library',
      icon: Icons.favorite_border,
      activeIcon: Icons.favorite,
      builder: (_) => const LibraryScreen(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _tabs[_currentIndex].builder(context),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        selectedIndex: _currentIndex,
        indicatorColor: AppColors.primary,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: _tabs
            .map(
              (tab) => NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.activeIcon),
                label: tab.label,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _ShellTab {
  const _ShellTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.builder,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final WidgetBuilder builder;
}
