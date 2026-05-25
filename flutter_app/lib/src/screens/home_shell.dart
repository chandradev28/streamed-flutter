import 'package:flutter/material.dart';

import '../models/torbox_models.dart';
import '../services/app_settings_repository.dart';
import '../theme/app_colors.dart';
import '../theme/layout_options.dart';
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
  AppSettings _settings = const AppSettings();
  final AppSettingsRepository _settingsRepository = AppSettingsRepository();

  @override
  void initState() {
    super.initState();
    AppSettingsRepository.settingsNotifier.addListener(_syncSettings);
    _loadSettings();
  }

  @override
  void dispose() {
    AppSettingsRepository.settingsNotifier.removeListener(_syncSettings);
    super.dispose();
  }

  void _syncSettings() {
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = AppSettingsRepository.settingsNotifier.value;
    });
  }

  Future<void> _loadSettings() async {
    final AppSettings settings = await _settingsRepository.loadSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = LayoutOptions.accentFor(_settings);
    final List<_ShellTab> tabs = <_ShellTab>[
      _ShellTab(
        label: 'Home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        builder: (_) => HomeScreen(
          settingsRepository: _settingsRepository,
          onSettingsChanged: _loadSettings,
        ),
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
        builder: (_) => LibraryScreen(),
      ),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: LayoutOptions.backgroundFor(_settings),
      body: tabs[_currentIndex].builder(context),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              accent.withOpacity(0.08),
              const Color(0xFF1B1B21),
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: accent.withOpacity(0.14)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x3A000000),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: List<Widget>.generate(tabs.length, (int index) {
                final _ShellTab tab = tabs[index];
                final bool selected = index == _currentIndex;
                return Expanded(
                  child: _FloatingNavItem(
                    label: tab.label,
                    icon: selected ? tab.activeIcon : tab.icon,
                    selected: selected,
                    accent: accent,
                    onTap: () {
                      setState(() {
                        _currentIndex = index;
                      });
                      _loadSettings();
                    },
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingNavItem extends StatelessWidget {
  const _FloatingNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: selected ? 40 : 28,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Icon(
                icon,
                size: 16,
                color: selected ? AppColors.background : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: selected ? accent : AppColors.textSubtle,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
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
